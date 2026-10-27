import std/[tables, math]
import p2p

type
  Uid*     = tuple[h, l: uint64]
  sync_f*  = distinct float32
  sync_v2* = tuple[x, y: float32]
  sync_b*  = object
    state     : bool
    confidence: float32

  Report = object
    revision: uint64
    time    : float64
    bytes   : seq[byte]

  Sync* = object
    kind*  : Kind
    owners*: Table[Uid, PeerId]
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

func weight*(s: Sync, source: PeerId, entity: Uid, trust: float32): float32 =
  let bonus = if source != 0 and s.owners.getOrDefault(entity) == source: 0.5'f32 else: 0'f32
  if classify(trust) in {fcNan, fcInf, fcNegInf}: return 0
  max(0'f32, trust + bonus)

proc put(bytes: var seq[byte], value: uint64, count: int) =
  for i in 0..<count: bytes.add byte((value shr (i*8)) and 255)

proc get(bytes: seq[byte], at: var int, count: int): uint64 =
  if at + count > bytes.len: raise newException(ValueError, "short sync record")
  for i in 0..<count: result = result or (uint64(bytes[at + i]) shl (i*8))
  at += count

proc encode[T](entity: T): seq[byte] =
  result.put(entity.id.h, 8)
  result.put(entity.id.l, 8)
  for _, field in fieldPairs(entity):
    when field is sync_v2:
      result.put(cast[uint32](field.x), 4)
      result.put(cast[uint32](field.y), 4)
    elif field is sync_f:
      result.put(cast[uint32](float32(field)), 4)
    elif field is sync_b:
      result.put(uint64(ord(field.value)), 1)

proc decode[T](bytes: seq[byte], entity: var T) =
  var at = 0
  entity.id = (bytes.get(at, 8), bytes.get(at, 8))
  for _, field in fieldPairs(entity):
    when field is sync_v2:
      field = sv(cast[float32](uint32(bytes.get(at, 4))),
                 cast[float32](uint32(bytes.get(at, 4))))
      if classify(field.x) in {fcNan, fcInf, fcNegInf} or
         classify(field.y) in {fcNan, fcInf, fcNegInf}:
        raise newException(ValueError, "nonfinite position")
    elif field is sync_f:
      let value = cast[float32](uint32(bytes.get(at, 4)))
      if classify(value) in {fcNan, fcInf, fcNegInf}:
        raise newException(ValueError, "nonfinite scalar")
      field = sync_f(value)
    elif field is sync_b:
      let value = bytes.get(at, 1)
      if value > 1: raise newException(ValueError, "invalid boolean")
      field.set(value == 1)
  if at != bytes.len: raise newException(ValueError, "sync schema mismatch")

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
    var incoming: T
    try: decode(receipt.datum.bytes, incoming)
    except ValueError: continue
    let key = receipt.datum.key
    if key notin s.keys or s.keys[key] != incoming.id: continue
    let index = (receipt.source, incoming.id)
    if index in s.reports and receipt.datum.revision <= s.reports[index].revision:
      continue
    s.reports[index] = Report(revision: receipt.datum.revision,
                              time: s.time, bytes: receipt.datum.bytes)
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

proc reconcile*[T](s: var Sync, n: Net, entities: var openArray[T],
                   dt: float64, selfTrust = 0'f32) =
  doAssert dt >= 0 and classify(dt) notin {fcNan, fcInf, fcNegInf}
  s.time += dt
  s.ingest(entities)

  # Retain the revision watermark even after a report expires.
  for entity in entities.mitems:
    var target = entity
    var total = 0.0
    let resistance = 1 + float64(s.weight(n.selph.id, entity.id, selfTrust))
    for index, report in s.reports:
      if index.entity != entity.id or s.time - report.time >= s.ttl: continue
      let peer = n.peers.getOrDefault(index.source)
      if peer.isNil or peer notin n.all: continue
      let w = float64(s.weight(index.source, entity.id, peer.trust))
      if w <= 0: continue
      var incoming: T
      decode(report.bytes, incoming)
      # Weighted mean, then one exponential step: independent of packet count.
      total += w
      target.blend(incoming, float32(w/total))

    if total > 0:
      let pull = float64(max(0'f32, s.rate))*total/resistance
      let alpha = float32(1 - exp(-pull*dt))
      entity.blend(target, alpha)
