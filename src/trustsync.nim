## Witness-only exchange over the P2P datakind interface.
import std/[algorithm, json, math, tables]
import p2p, trust, trustdb, identity

type
  TrustSync* = object
    kind*: Kind
    db*: ref TrustDb
    serial: uint64
    seen: Table[tuple[source: PeerId, subject: string], uint64]

func keyOf(id: string): uint64 =
  ## FNV-1a is stable across processes and architectures; the full ID travels too.
  result = 14695981039346656037'u64
  for c in id: result = (result xor uint64(ord(c))) * 1099511628211'u64

proc initTrustSync*(n: var Net, kind: KindId, db: ref TrustDb): TrustSync =
  if db.isNil: raise newException(ValueError, "missing trust database")
  TrustSync(kind: n.register(kind, dropOld = true, initialFull = true), db: db)

proc publish*(s: var TrustSync) =
  ## Share only firsthand opinions, never aggregate or retransmit swarm data.
  var subjects: seq[string]
  for id in s.db.witnessed.keys: subjects.add id
  subjects.sort()
  var keys: Table[uint64, string]
  var rows: seq[Datum]
  inc s.serial
  for id in subjects:
    let key = keyOf(id)
    if key in keys and keys[key] != id:
      raise newException(ValueError, "trust key collision")
    keys[key] = id
    let msg = $(%*{"subject": id, "credibility": s.db.witnessed[id]})
    var bytes = newSeq[byte](msg.len)
    for i, c in msg: bytes[i] = byte(c)
    rows.add Datum(key: key, revision: s.serial, bytes: bytes)
  s.kind.row = rows

proc receive*(s: var TrustSync, n: Net) =
  ## The network transport must authenticate source IDs and their player IDs.
  for receipt in s.kind.queue:
    let p = n.peers.getOrDefault(receipt.source)
    if p.isNil or p.info.playerId.len == 0: continue
    let d = receipt.datum
    if d.bytes.len > 16_384: continue
    try:
      var raw = newString(d.bytes.len)
      for i, b in d.bytes: raw[i] = char(b)
      let obj = parseJson(raw)
      if obj.kind != JObject or not obj.hasKey("subject") or
         not obj.hasKey("credibility"): continue
      if obj["subject"].kind != JString or
         obj["credibility"].kind notin {JInt, JFloat}: continue
      let subject = obj["subject"].getStr()
      let number = obj["credibility"].getFloat()
      if classify(number) in {fcNan, fcInf, fcNegInf} or number < 0 or number > 1: continue
      if keyOf(subject) != d.key: continue
      let index = (receipt.source, playerId(subject))
      if index in s.seen and d.revision <= s.seen[index]: continue
      s.db[].setSwarm(p.info.playerId, subject, float32(number))
      s.seen[index] = d.revision
    except ValueError, KeyError, JsonParsingError:
      continue
  s.kind.queue.setLen(0)

proc attachPositionPolicy*(s: TrustSync, n: var Net, unknownReliability = 0'f32) =
  ## Until a ping is measured, the caller chooses the local reliability fallback.
  if classify(unknownReliability) in {fcNan, fcInf, fcNegInf} or
     unknownReliability < 0 or unknownReliability > 1:
    raise newException(ValueError, "invalid unknown reliability")
  let db = s.db
  n.positionTrust = proc(p: Peer): float32 =
    let r = if p.ping < 0: unknownReliability else: reliability(float32(p.ping))
    let cred = if p.info.playerId.len == 0: 0'f32 else: db[].credibility(p.info.playerId)
    positionTrust(cred, r)
  n.recordDesync = proc(p: Peer, severity: float32) =
    if p.info.playerId.len > 0: db[].desync(p.info.playerId, clamp(severity, 0'f32, 1'f32))

proc step*(s: var TrustSync, n: Net, dt: float32) =
  s.receive(n)
  s.db[].advance(dt)
  s.publish()
