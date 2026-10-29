## Quantify owner control with mutually re-reported state.
import std/[math, tables]
import ../src/[p2p, sync]
import sim_socket

type Body = object
  id : Uid
  pos: sync_v2

const id: Uid = (71'u64, 19'u64)

proc measure(latency, jitter: int64, loss: float64,
             holdOwner, dissent: bool): array[4, float32] =
  var gateway = initGateway(latency, jitter, loss, 123)
  var
    nets  : array[4, Net]
    states: array[4, Sync]
    bodies: array[4, seq[Body]]
    active: PeerId

  for i in 0..<4:
    let self = PeerId(i+1)
    nets[i] = initNet(PeerInfo(id: self), int64(self))
    for j in 0..<4:
      if i == j: continue
      let p = Peer(info: PeerInfo(id: PeerId(j+1)), trust: 0.5,
                   up: (0'f32, 1'f32))
      nets[i].peers[p.info.id] = p
      nets[i].all.add p
      nets[i].near.add p
    states[i] = initSync(nets[i], 7)
    states[i].owners[id] = 1
    bodies[i] = @[Body(id: id)]
    states[i].publish(bodies[i])

  gather = proc(): seq[Event] = gateway.recv(active)
  traffic = proc(p: Peer) = discard
  accept = proc(p: Peer, k: Kind, d: Datum): bool = true
  sendPeers = proc(p: Peer, peers: seq[PeerInfo]) = discard
  sendDatum = proc(p: Peer, k: Kind, d: Datum) =
    gateway.send(p.info.id, Event(event: data, source: PeerInfo(id: active),
                                 kind: k.id, datum: d))

  for tick in 0..<400:
    gateway.advance(25)
    for i in 0..<4:
      active = PeerId(i+1)
      # A one-time jump, a held owner target, or a held dissenting report.
      if i == 0 and (tick == 20 or (holdOwner and tick >= 20)):
        bodies[i][0].pos.x = 8
      if i == 1 and dissent and tick >= 20: bodies[i][0].pos.x = 0
      states[i].publish(bodies[i])
      nets[i].tick()
      states[i].reconcile(nets[i], bodies[i], 0.025)
  for i in 0..<4:
    result[i] = bodies[i][0].pos.x
    doAssert classify(result[i]) notin {fcNan, fcInf, fcNegInf}

for latency in [0'i64, 80'i64]:
  let jitter = if latency == 0: 0'i64 else: 35'i64
  let loss = if latency == 0: 0.0 else: 0.25
  let impulse = measure(latency, jitter, loss, false, false)
  let held    = measure(latency, jitter, loss, true,  false)
  let dissent = measure(latency, jitter, loss, true,  true)
  doAssert impulse[0] > 0
  doAssert abs(held[0] - 8) < 0.01
  echo "latency=", latency, " impulse=", impulse, " held=", held,
       " dissent=", dissent
