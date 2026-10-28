import std/[tables, math]
import p2p

type
  Uid*     = tuple[h, l: uint64]
  sync_f*  = distinct float32
  sync_v2* = tuple[x, y: float32]
  sync_b*  = object
    state     : bool
    confidence: float32

  Influence = tuple[bytes: seq[byte], w: float64]

  Report = object
    revision: uint64
    time    : float64
    bytes   : seq[byte]

  Sync* = object
    kind*  : Kind
    owners*: Table[Uid, PeerId]
    # Keep revision watermarks after reports expire.
    reports: Table[tuple[source: PeerId, entity: Uid], Report]
    keys   : Table[uint64, Uid]
    serial : uint64
    time   : float64
    rate*  : float32
    ttl*   : float64

proc set*(x: var sync_b, value: bool) =
  x.state = value
  x.confidence = (if value: 1'f32 else: 0'f32)

func value*(x: sync_b): bool = x.state

func sv*(x, y: float32): sync_v2 = (x, y)
func `+`*(a, b: sync_v2): sync_v2 = sv(a.x + b.x, a.y + b.y)
proc `+=`*(a: var sync_v2, b: sync_v2) = a = a + b

proc initSync*(n: var Net, kind: KindId): Sync =
  Sync(kind: n.register(kind, dropOld = true), rate: 8, ttl: 2)

func finite(x: SomeFloat): bool =
  classify(x) notin {fcNan, fcInf, fcNegInf}

func weight*(s: Sync, source: PeerId, entity: Uid, trust: float32): float32 =
  if not finite(trust): return 0
  let owns = source != 0 and s.owners.getOrDefault(entity) == source
  let bonus = if owns: 0.5'f32 else: 0'f32
  max(0'f32, trust + bonus)

proc put(bytes: var seq[byte], value: uint64, count: int) =
  for i in 0..<count: bytes.add byte((value shr (i*8)) and 255)

proc get(bytes: seq[byte], at: var int, count: int): uint64 =
  if at + count > bytes.len: raise newException(ValueError, "short sync record")
  for i in 0..<count: result = result or (uint64(bytes[at + i]) shl (i*8))
  at += count

proc put(bytes: var seq[byte], value: float32) =
  bytes.put(cast[uint32](value), 4)

proc getFloat(bytes: seq[byte], at: var int): float32 =
  result = cast[float32](uint32(bytes.get(at, 4)))
  if not finite(result):
    raise newException(ValueError, "nonfinite sync value")

proc getBool(bytes: seq[byte], at: var int): bool =
  let value = bytes.get(at, 1)
  if value > 1: raise newException(ValueError, "invalid boolean")
  value == 1

proc encode[T](entity: T): seq[byte] =
  result.put(entity.id.h, 8)
  result.put(entity.id.l, 8)
  for _, field in fieldPairs(entity):
    when field is sync_v2:
      result.put(field.x)
      result.put(field.y)
    elif field is sync_f:
      result.put(float32(field))
    elif field is sync_b:
      result.put(uint64(ord(field.value)), 1)

proc decode[T](bytes: seq[byte], entity: var T) =
  var at = 0
  entity.id = (bytes.get(at, 8), bytes.get(at, 8))
  for _, field in fieldPairs(entity):
    when field is sync_v2:
      field = sv(bytes.getFloat(at), bytes.getFloat(at))
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

proc ingest[T](s: var Sync, entities: openArray[T]) =
  for receipt in s.kind.queue:
    let d = receipt.datum
    var incoming: T
    try: decode(d.bytes, incoming)
    except ValueError: continue

    let key = d.key
    if key notin s.keys or s.keys[key] != incoming.id: continue

    let index = (receipt.source, incoming.id)
    if index in s.reports and d.revision <= s.reports[index].revision:
      continue

    s.reports[index] = Report(revision: d.revision, time: s.time, bytes: d.bytes)
  s.kind.queue.setLen(0)

func toward(a, b, alpha: float32): float32 =
  float32(float64(a)*(1 - float64(alpha)) + float64(b)*float64(alpha))

proc blend[T](entity: var T, target: T, alpha: float32) =
  for _, a, b in fieldPairs(entity, target):
    when a is sync_v2:
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
    if s.time - report.time >= s.ttl: continue
    let peer = n.peers.getOrDefault(index.source)
    if peer.isNil or peer notin n.all: continue

    let w = float64(s.weight(index.source, entity, peer.trust))
    if w > 0: yield (report.bytes, w)

proc reconcile*[T](s: var Sync, n: Net, entities: var openArray[T],
                   dt: float64, selfTrust = 0'f32) =
  doAssert dt >= 0 and finite(dt)
  s.time += dt
  s.ingest(entities)

  for entity in entities.mitems:
    var target = entity
    var total = 0.0

    for bytes, w in s.influences(n, entity.id):
      var incoming: T
      decode(bytes, incoming)
      total += w
      target.blend(incoming, float32(w/total))

    if total > 0:
      let own = s.weight(n.selph.id, entity.id, selfTrust)
      let pull = float64(max(0'f32, s.rate))*total/(1 + float64(own))
      let alpha = float32(1 - exp(-pull*dt))
      entity.blend(target, alpha)
