import std/[tables, math]
import ../src/[p2p, sync]
import sim_socket

type Entity = object
  id : Uid
  pos: sync_v2

block gatewayTiming:
  var g = initGateway(100, 0, 0, 1)
  let e = Event(event: data, source: PeerInfo(id: 1))
  g.send(2, e)
  g.advance(99)
  doAssert g.recv(2).len == 0
  g.advance(1)
  doAssert g.recv(1).len == 0
  doAssert g.recv(2).len == 1
  doAssert g.recv(2).len == 0
  var lost = initGateway(0, 0, 1, 1)
  lost.send(2, e)
  doAssert lost.dropped == 1 and lost.recv(2).len == 0

let id: Uid = (17'u64, 23'u64)
var gateway = initGateway(80, 35, 0.25, 123)
var
  nets    : array[4, Net]
  states  : array[4, Sync]
  entities: array[4, seq[Entity]]
  active  : PeerId

for i in 0..<4:
  let self = PeerId(i + 1)
  nets[i] = initNet(PeerInfo(id: self), int64(self))
  for j in 0..<4:
    if i == j: continue
    let p = Peer(info: PeerInfo(id: PeerId(j + 1)), trust: 0.5, up: (0'f32, 1'f32))
    nets[i].peers[p.info.id] = p
    nets[i].all.add p
    nets[i].near.add p
  states[i] = initSync(nets[i], 7)
  states[i].owners[id] = 1
  entities[i] = @[Entity(id: id, pos: sv(if i == 0: 10 else: 0, 0))]
  states[i].publish(entities[i])

gather = proc(): seq[Event] = gateway.recv(active)
traffic = proc(p: Peer) = discard
accept = proc(p: Peer, k: Kind, d: Datum): bool = true
sendPeers = proc(p: Peer, peers: seq[PeerInfo]) = discard
sendDatum = proc(p: Peer, k: Kind, d: Datum) =
  gateway.send(p.info.id, Event(event: data, source: PeerInfo(id: active),
                               kind: k.id, datum: d))

# The owner stays at its target; all peers repeatedly exchange reports.
for tick in 0..<500:
  gateway.advance(25)
  for i in 0..<4:
    active = PeerId(i + 1)
    if i == 0: entities[i][0].pos = sv(10, 0)
    states[i].publish(entities[i])
    nets[i].tick()
    if i != 0: states[i].reconcile(nets[i], entities[i], 0.025)

doAssert gateway.sent > 0 and gateway.dropped > 0
for i in 1..<4:
  doAssert abs(entities[i][0].pos.x - 10) < 0.1

echo "four-client simulated network checks passed"

proc kineticRun(count: int, compensate: bool): float32 =
  type Body = object
    id : Uid
    kin: sync_k2
  var g = initGateway(80, 35, 0.25, 123)
  var nets: seq[Net]
  var syncs: seq[Sync]
  var bodies: seq[seq[Body]]
  var active: PeerId
  for i in 0..<count:
    var n = initNet(PeerInfo(id: PeerId(i+1)), int64(i+1))
    for j in 0..<count:
      if i == j: continue
      let p = Peer(info: PeerInfo(id: PeerId(j+1)), trust: 0.5, up: (0'f32, 1'f32))
      n.peers[p.info.id] = p
      n.all.add p
      n.near.add p
    syncs.add initSync(n, 7)
    syncs[^1].owners[id] = 1
    nets.add n
    bodies.add @[Body(id: id, kin: sync_k2(v: sv(10,0)))]
    syncs[^1].publish(bodies[^1])

  gather = proc(): seq[Event] =
    result = g.recv(active)
    if not compensate:
      for e in result.mitems: e.datum.age = 0
  sendDatum = proc(p: Peer, k: Kind, d: Datum) =
    g.send(p.info.id, Event(event: data, source: PeerInfo(id: active),
                            kind: k.id, datum: d))

  for tick in 0..<320:
    g.advance(25)
    for i in 0..<count:
      active = PeerId(i+1)
      if i == 0 and tick == 160: bodies[i][0].kin.v = sv(0,0)
      bodies[i][0].kin.drift(0.025)
      syncs[i].publish(bodies[i])
      nets[i].tick()
      if i != 0: syncs[i].reconcile(nets[i], bodies[i], 0.025)
    if tick == 159:
      for i in 1..<count:
        result = max(result, abs(bodies[i][0].kin.p.x - bodies[0][0].kin.p.x))
  for i in 1..<count:
    doAssert abs(bodies[i][0].kin.p.x - bodies[0][0].kin.p.x) < 0.1
    doAssert abs(bodies[i][0].kin.v.x) < 0.01

for count in [2, 4, 16]:
  let corrected = kineticRun(count, true)
  let lagged = kineticRun(count, false)
  doAssert corrected < 0.01, $count & " peers: " & $corrected
  doAssert lagged > 0.1
  echo count, " peers, moving-position error: ", corrected, " (without transit age: ", lagged, ")"
