# peers cant desync if a cliebt is barely sank to its own sink
# maintain evanescent stochastic dendrites
import std/[tables, sets, random, sequtils, math]

type
  PeerId* = uint64
  Edge* = tuple[informant, subject: PeerId]
  PeerInfo* = object
    id*: PeerId
    playerId*: string # exact identity supplied by authenticated transport
    endpoint*: string

  Traffic* = tuple[load, coefficient: float32]
  Peer* = ref object
    info*: PeerInfo
    trust*: float32
    ping*: int64 # ms
    up*, down*: Traffic
    informants*: HashSet[PeerId]

  Datum* = object
    key*, revision*: uint64
    bytes*: seq[byte]
    age*  : float64 # sample age at receipt, seconds; supplied by transport
  Receipt* = tuple[source: PeerId, datum: Datum]

  KindId* = uint16
  Kind* = ref object
    id*: KindId
    dropOld*, once*, initialFull*: bool
    row*: seq[Datum] # outgoing state
    queue*: seq[Receipt] # incoming effects

  EventKind* = enum joined, left, peerTable, data
  Event* = object
    event*: EventKind
    source*: PeerInfo
    peers*: seq[PeerInfo]
    kind*: KindId
    datum*: Datum

  Net* = object
    selph*: PeerInfo
    peers*: Table[PeerId, Peer] # known, connected or not
    near*, far*, all*: seq[Peer] # disjoint near/far; all is their union
    kinds*: Table[KindId, Kind]
    pingLimit*: int64
    positionTrust*: proc(p: Peer): float32
    recordDesync*: proc(p: Peer, severity: float32)
    rng: Rand

var # transport; bind before use, no reentry
  gather*: proc(): seq[Event] # authenticated; lifecycle ordered
  connect*: proc(info: PeerInfo) # idempotent handshake, retries
  disconnect*: proc(id: PeerId) # cancel pending work
  sendPeers*: proc(p: Peer, peers: seq[PeerInfo])
  sendDatum*: proc(p: Peer, k: Kind, d: Datum)
  accept*: proc(p: Peer, k: Kind, d: Datum): bool
  # codec/MTU/pacing, per-source dedup/dropOld external
  # once: coalesce pending; mark on send; no data retries

var # policy
  traffic*: proc(p: Peer) # updates ping, loads, coefficient
  pairChance*, retention*: proc(p: Peer): float32 # optional
  placeFar*: proc(p: Peer): bool # optional
  desyncCost*: proc(severity: float32): float32

proc initNet*(selph: PeerInfo, seed: int64): Net =
  doAssert selph.id != 0
  Net(selph: selph, rng: initRand(seed), pingLimit: 2000)

proc register*(n: var Net, id: KindId,
               dropOld = false, once = false, initialFull = false): Kind =
  doAssert id notin n.kinds
  result = Kind(id: id, dropOld: dropOld, once: once, initialFull: initialFull)
  n.kinds[id] = result

func sq[T](x: T): T = x*x
func unit(x: float32): float32 = clamp(x, 0'f32, 1'f32)

proc chance(n: var Net, c: float32): bool =
  c >= 1 or (c > 0 and n.rng.rand(1.0) < float64(c))

template eachPct(n: var Net, xs, c, body: untyped) =
  block: # each%; fraction c may use it; snapshot permits pruning
    let chosen = toSeq(xs).filterIt(n.chance(c))
    for it {.inject.} in chosen: body

template pressure(n: Net): float32 =
  n.all.foldl(a + 4*b.up.load + b.down.load, 0'f32)

proc unlink(n: var Net, p: Peer) =
  n.near.keepItIf(it != p)
  n.far.keepItIf(it != p)
  n.all.keepItIf(it != p)

proc place(n: var Net, p: Peer, far = false) =
  n.unlink(p)
  n.all.add p
  if far: n.far.add p
  else: n.near.add p
  # only place/unlink edit membership

proc learn(n: var Net, info: PeerInfo, via: PeerId = 0): Peer =
  if info.id == 0 or info.id == n.selph.id: return

  result = n.peers.getOrDefault(info.id)
  if result.isNil:
    result = Peer(info: info, ping: -1, up: (0'f32, 1'f32))
    n.peers[info.id] = result

    for p in n.all:
      if p.info.id notin [info.id, via]:
        sendPeers(p, @[info])

  if via != 0: result.informants.incl via
  # hints do not establish connections

proc seed*(n: var Net, infos: openArray[PeerInfo]) =
  for info in infos: discard n.learn(info) # gateway external

proc join(n: var Net, info: PeerInfo) =
  let p = n.learn(info)
  if p.isNil or p in n.all: return

  p.info = info
  let far = not placeFar.isNil and placeFar(p)
  n.place(p, far)

  var peers = @[n.selph] #whole table, unsampled
  for q in n.peers.values:
    if q != p: peers.add q.info
  sendPeers(p, peers)
  for k in n.kinds.values:
    if k.initialFull:
      for d in k.row: sendDatum(p, k, d)

proc receive(n: var Net) =
  for e in gather():
    let id = e.source.id
    if id == 0 or id == n.selph.id: continue

    let p = n.peers.getOrDefault(id)
    if e.event != joined and p notin n.all: continue

    case e.event
    of joined: n.join(e.source)
    of left: n.unlink(p) # retain descriptor
    of peerTable:
      for info in e.peers: discard n.learn(info, id)
    of data:
      let k = n.kinds.getOrDefault(e.kind)
      if not k.isNil and accept(p, k, e.datum):
        k.queue.add (id, e.datum)

proc reportDesync*(n: var Net, id: PeerId, severity: float32) =
  # todo: severity rule for packet-independent discrepancies such as ammo
  doAssert severity >= 0 and classify(severity) notin {fcNan, fcInf, fcNegInf}
  if id notin n.peers: return
  if not n.recordDesync.isNil:
    n.recordDesync(n.peers[id], severity)
  else:
    doAssert not desyncCost.isNil
    n.peers[id].trust -= max(0'f32, desyncCost(severity))
  # engine judges causality and attribution

iterator informantEdges*(n: Net): Edge =
  for p in n.peers.values:
    for source in p.informants:
      yield (source, p.info.id)

proc tick*(n: var Net, dt = 0.0) =
  # Age existing outgoing rows; pass zero when they were just published.
  doAssert dt >= 0 and classify(dt) notin {fcNan, fcInf, fcNegInf}
  for k in n.kinds.values:
    for d in k.row.mitems: d.age += dt

  n.receive()
  for p in n.all: traffic(p)

  #prune
  n.eachPct(n.all, 0.01):
    if it.ping > n.pingLimit:
      disconnect(it.info.id)
      n.unlink(it)

  if not retention.isNil:
    let rate = 0.02'f32 + 0.2'f32*n.pressure
    n.eachPct(n.near, rate):
      let roll = sq(n.rng.rand(1.0))
      let keep = float64(unit(retention(it)))
      if roll > keep: n.place(it, far = true)

  #pair
  if not pairChance.isNil:
    let idle = toSeq(n.peers.values).filterIt(it notin n.all)
    n.eachPct(idle, pairChance(it)):
      connect(it.info)

  #smack
  n.rng.shuffle(n.all)
  for p in n.all:
    var rate = unit(p.up.coefficient)
    if p in n.far: rate *= rate

    for k in n.kinds.values: #row
      n.eachPct(k.row, rate): #column
        sendDatum(p, k, it)
