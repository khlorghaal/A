import std/[tables, math]
import p2p

#fixme  this has lots of odd semantics regarding betas, consoder inlining
type
  Uid*     = tuple[h, l: uint64]
  sync_f*  = distinct float32
  sync_v2* = tuple[x, y: float32]
  sync_k2* = object
    p*, v*: sync_v2 # position, velocity
  sync_b*  = object # boolean state with confidence and hysteresis
    state*    : bool # read directly; use set to update confidence too
    confidence: float32

  Influence = tuple[bytes: seq[byte], w: float64, age: Seconds]

  Report = object
    revision : uint64
    time, age: Seconds
    bytes    : seq[byte]

  Sync* = object
    kind*      : Kind
    owners*    : Table[Uid, PeerId]
    # Keep revision watermarks after reports expire.
    reports    : Table[tuple[source: PeerId, entity: Uid], Report]
    keys       : Table[uint64, Uid]
    serial     : uint64
    time       : Seconds
    rate*      : float32
    ttl*       : Seconds
    horizon*   : Seconds
    ownerBonus*: float32

proc set*(x: var sync_b, b: bool) =
  x.state = b
  x.confidence = (if b: 1'f32 else: 0'f32)

func `+`*(a, b: sync_v2): sync_v2 = (a.x + b.x, a.y + b.y)
proc `+=`*(a: var sync_v2, b: sync_v2) = a = a + b

proc drift*(m: var sync_k2, dt: float64) =
  m.p += (m.v.x * float32(dt), m.v.y * float32(dt))
#todo use lambdas for oneline equations

proc initSync*(n: var Net, kind: KindId): Sync =
  Sync(kind: n.register(kind, dropOld = true),
       rate: 8, ttl: Seconds(2), horizon: Seconds(0.25), ownerBonus: 0.3)

func finite(x: SomeFloat): bool =
  classify(x) notin {fcNan, fcInf, fcNegInf}

func weight*(s: Sync, source: PeerId, entity: Uid, trust: float32): float32 =
  if not finite(trust): return 0
  let owns = source != 0 and s.owners.getOrDefault(entity) == source
  let bonus = if owns: max(0'f32, s.ownerBonus) else: 0'f32
  max(0'f32, trust + bonus)

proc put(bytes: var seq[byte], i: uint64, count: int) =
  for j in 0..<count: bytes.add byte((i shr (j*8)) and 255)

proc get(bytes: seq[byte], at: var int, count: int): uint64 =
  if at + count > bytes.len: raise newException(ValueError, "short sync record")
  for i in 0..<count: result = result or (uint64(bytes[at + i]) shl (i*8))
  at += count

proc `+=`(bytes: var seq[byte], i: uint64)  = bytes.put(i, 8)
proc `+=`(bytes: var seq[byte], x: float32) = bytes.put(cast[uint32](x), 4)
proc `+=`(bytes: var seq[byte], b: bool)    = bytes.put(uint64(ord(b)), 1)

proc getFloat(bytes: seq[byte], at: var int): float32 =
  result = cast[float32](uint32(bytes.get(at, 4)))
  if not finite(result):
    raise newException(ValueError, "nonfinite sync value")

proc getBool(bytes: seq[byte], at: var int): bool =
  let i = bytes.get(at, 1)
  if i > 1: raise newException(ValueError, "invalid boolean")
  i == 1

proc encode[T](entity: T): seq[byte] =
  result += entity.id.h
  result += entity.id.l
  for _, field in fieldPairs(entity):
    when field is sync_k2:
      result += field.p.x
      result += field.p.y
      result += field.v.x
      result += field.v.y
    elif field is sync_v2:
      result += field.x
      result += field.y
    elif field is sync_f:
      result += float32(field)
    elif field is sync_b:
      result += field.state

proc decode[T](bytes: seq[byte], entity: var T) =
  var at = 0
  entity.id = (bytes.get(at, 8), bytes.get(at, 8))
  for _, field in fieldPairs(entity):
    when field is sync_k2:
      field.p = (bytes.getFloat(at), bytes.getFloat(at))
      field.v = (bytes.getFloat(at), bytes.getFloat(at))
    elif field is sync_v2:
      field = (bytes.getFloat(at), bytes.getFloat(at))
    elif field is sync_f:
      field = sync_f(bytes.getFloat(at))
    elif field is sync_b:
      field.set(bytes.getBool(at))
  if at != bytes.len:
    raise newException(ValueError, "sync schema mismatch")

proc publish*[T](s: var Sync, entities: openArray[T]) =
  s.kind.row.setLen(0)
  inc s.serial
  for entity in entities:
    # Key collisions are rejected; the complete 128-bit ID is in the record.
    let key = entity.id.h xor entity.id.l
    if key in s.keys and s.keys[key] != entity.id:
      raise newException(ValueError, "sync key collision")
    s.keys[key] = entity.id
    s.kind.row.add Datum(key: key, revision: s.serial, bytes: encode(entity))

#todo i dont like the name "ingest" lol
proc ingest[T](s: var Sync, entities: openArray[T]) =
  for receipt in s.kind.queue:
    let d = receipt.datum
    if not finite(float64(d.age)) or float64(d.age) < 0: continue

    var incoming: T
    try: decode(d.bytes, incoming)
    except ValueError: continue

    let key = d.key
    if key notin s.keys or s.keys[key] != incoming.id: continue

    let index = (receipt.source, incoming.id)
    if index in s.reports and d.revision <= s.reports[index].revision:
      continue

    s.reports[index] = Report(revision: d.revision, time: s.time,
                              age: d.age, bytes: d.bytes)
  s.kind.queue.setLen(0)

func toward(a, b, alpha: float32): float32 =
  # Interpolate toward the target; blend uses this for rubber-band correction.
  float32(float64(a)*(1 - float64(alpha)) + float64(b)*float64(alpha))

proc blend[T](entity: var T, target: T, alpha: float32) =
  for _, a, b in fieldPairs(entity, target):
    when a is sync_k2:
      a.p.x = toward(a.p.x, b.p.x, alpha)
      a.p.y = toward(a.p.y, b.p.y, alpha)
      a.v.x = toward(a.v.x, b.v.x, alpha)
      a.v.y = toward(a.v.y, b.v.y, alpha)
    elif a is sync_v2:
      a.x = toward(a.x, b.x, alpha)
      a.y = toward(a.y, b.y, alpha)
    elif a is sync_f:
      a = sync_f(toward(float32(a), float32(b), alpha))
    elif a is sync_b:
      a.confidence = toward(a.confidence, b.confidence, alpha)
      if a.confidence >= 0.6: a.state = true
      if a.confidence <= 0.4: a.state = false

iterator influences(s: Sync, n: Net, entity: Uid): Influence =
  for index, report in s.reports:
    if index.entity != entity: continue
    let age = report.age + s.time - report.time
    if age >= s.ttl: continue
    let peer = n.peers.getOrDefault(index.source)
    if peer.isNil or peer notin n.all: continue

    let bonus = if index.source != 0 and s.owners.getOrDefault(entity) == index.source:
                  max(0'f32, s.ownerBonus)
                else: 0'f32
    let trust = if n.positionTrust.isNil: s.weight(index.source, entity, peer.trust)
                else: n.positionTrust(peer, bonus)
    let w = float64(trust)
    if finite(w) and w > 0: yield (report.bytes, w, age)

proc reconcile*[T](s: var Sync, n: Net, entities: var openArray[T],
                   dt: float64, selfTrust = 0'f32) =
  doAssert dt >= 0 and finite(dt)
  doAssert finite(float64(s.horizon)) and s.horizon >= Seconds(0)
  doAssert finite(s.ownerBonus) and finite(s.rate) and
           finite(float64(s.ttl)) and s.ttl > Seconds(0)
  s.time += Seconds(dt)
  s.ingest(entities)

  # Build a weighted target from fresh peer reports, then ease local state to it.
  for entity in entities.mitems:
    var target = entity
    var total = 0.0

    for bytes, w, age in s.influences(n, entity.id):
      var incoming: T
      decode(bytes, incoming)

      var fresh = true
      for _, field in fieldPairs(incoming):
        when field is sync_k2:
          if age > s.horizon: fresh = false
          else:
            field.drift(float64(age))
            if not finite(field.p.x) or not finite(field.p.y): fresh = false
      if not fresh: continue

      total += w
      target.blend(incoming, float32(w/total))

    if total > 0:
      let own   = s.weight(n.selph.id, entity.id, selfTrust)
      let pull  = float64(max(0'f32, s.rate))*total /
                  (1 + float64(own) + total)
      let alpha = float32(1 - exp(-pull*dt))
      entity.blend(target, alpha)
