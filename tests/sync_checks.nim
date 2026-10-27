import std/[tables, math]
import ../[p2p, sync]

type Entity = object
  id     : Uid
  pos    : sync_v2
  trigger: sync_b
  scalar : sync_f
  health : int

proc network(id, other: PeerId): Net =
  result = initNet(PeerInfo(id: id), int64(id))
  let p = Peer(info: PeerInfo(id: other), trust: 0.25, up: (0'f32, 1'f32))
  result.peers[other] = p
  result.all = @[p]
  result.near = @[p]

let id: Uid = (11'u64, 22'u64)
var left  = network(1, 2)
var right = network(2, 1)
var tx = initSync(left, 7)
var rx = initSync(right, 7)
var a = @[Entity(id: id, pos: sv(10,20), scalar: sync_f(6), health: 10)]
var b = @[Entity(id: id, health: 99)]
a[0].trigger.set(true)
tx.owners[id] = 1
rx.owners[id] = 1
rx.publish(b) # registers the known entity IDs; updates cannot create entities

doAssert rx.weight(1, id, 0.25) == 0.75
doAssert rx.weight(2, id, 0.25) == 0.25

# Exercise the actual P2P kind, transmission sampling and incoming queue.
var pending: seq[Event]
gather = proc(): seq[Event] =
  result = pending
  pending = @[]
traffic = proc(p: Peer) = discard
sendDatum = proc(p: Peer, k: Kind, d: Datum) =
  if p.info.id == 2:
    pending.add Event(event: data, source: PeerInfo(id: 1), kind: k.id, datum: d)
accept = proc(p: Peer, k: Kind, d: Datum): bool = true
sendPeers = proc(p: Peer, infos: seq[PeerInfo]) = discard

tx.publish(a)
left.tick()
right.tick()
doAssert rx.kind.queue.len == 1
rx.reconcile(right, b, 0.5)
doAssert b[0].pos.x > 9 and b[0].pos.x < 10
doAssert b[0].trigger.value
doAssert float32(b[0].scalar) > 5
doAssert b[0].health == 99 # unmarked fields stay local

proc trajectory(steps: int, owner: PeerId, trust: float32,
                duplicates = 1): float32 =
  var n = network(2, 1)
  n.peers[1].trust = trust
  var s = initSync(n, 7)
  s.owners[id] = owner
  var entities = @[Entity(id: id)]
  s.publish(entities)
  for i in 0..<duplicates: s.kind.queue.add (1'u64, tx.kind.row[0])
  for i in 0..<steps: s.reconcile(n, entities, 1.0/float64(steps))
  entities[0].pos.x

let whole = trajectory(1, 1, 0.25)
doAssert abs(whole - trajectory(100, 1, 0.25)) < 0.0001
doAssert abs(whole - trajectory(1, 1, 0.25, 100)) < 0.0001
doAssert trajectory(1, 1, 0.25) > trajectory(1, 2, 0.25)
doAssert abs(trajectory(1, 2, 0.25) - trajectory(100, 2, 0.25)) < 0.0001
doAssert trajectory(1, 2, -1) == 0

# Expiry, replay and malformed input cannot renew an old influence.
rx.reconcile(right, b, 3)
let expired = b[0].pos
rx.kind.queue.add (1'u64, tx.kind.row[0])
rx.reconcile(right, b, 0.1)
doAssert b[0].pos == expired
var broken = tx.kind.row[0]
inc broken.revision
broken.bytes.setLen(2)
rx.kind.queue.add (1'u64, broken)
rx.reconcile(right, b, 0.1)
doAssert b[0].pos == expired

# A newer false state must overcome the boolean's hysteresis.
a[0].trigger.set(false)
tx.publish(a)
rx.kind.queue.add (1'u64, tx.kind.row[0])
rx.reconcile(right, b, 0.5)
doAssert not b[0].trigger.value

echo "sync checks passed"
