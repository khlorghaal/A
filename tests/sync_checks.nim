import std/[tables, math]
import ../src/[p2p, sync]

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
var a = @[Entity(id: id, pos: (10,20), scalar: sync_f(6), health: 10)]
var b = @[Entity(id: id, health: 99)]
a[0].trigger.set(true)
tx.owners[id] = 1
rx.owners[id] = 1
rx.publish(b) # registers the known entity IDs; updates cannot create entities

doAssert abs(rx.weight(1, id, 0.25) - 0.55) < 0.00001
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
doAssert tx.kind.row[0].bytes == @[
  11'u8, 0, 0, 0, 0, 0, 0, 0, 22, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 32, 65, 0, 0, 160, 65, 1, 0, 0, 192, 64]
left.tick()
right.tick()
doAssert rx.kind.queue.len == 1
rx.reconcile(right, b, 0.5)
let expectedAlpha = 1 - exp(-8 * 0.55 / 1.55 * 0.5)
doAssert abs(float64(b[0].pos.x) - 10 * expectedAlpha) < 0.0001
doAssert b[0].trigger.state
doAssert abs(float64(float32(b[0].scalar)) - 6 * expectedAlpha) < 0.0001
doAssert b[0].health == 99 # unmarked fields stay local

block ownerCredibility:
  var policy = network(2, 1)
  var bonuses: seq[float32]
  policy.positionTrust = proc(p: Peer, bonus: float32): float32 =
    bonuses.add bonus
    0.5'f32
  var own = initSync(policy, 8)
  own.owners[id] = 1
  var entities = @[Entity(id: id)]
  own.publish(entities)
  own.kind.queue.add (1'u64, tx.kind.row[0])
  own.reconcile(policy, entities, 0.1)
  doAssert bonuses.len == 1 and abs(bonuses[0] - 0.3) < 0.00001

  bonuses.setLen(0)
  var other = initSync(policy, 9)
  other.owners[id] = 2
  other.publish(entities)
  other.kind.queue.add (1'u64, tx.kind.row[0])
  other.reconcile(policy, entities, 0.1)
  doAssert bonuses == @[0'f32]

  policy.positionTrust = proc(p: Peer, bonus: float32): float32 = Inf.float32
  var invalid = initSync(policy, 10)
  var unchanged = @[Entity(id: id)]
  invalid.publish(unchanged)
  invalid.kind.queue.add (1'u64, tx.kind.row[0])
  invalid.reconcile(policy, unchanged, 0.1)
  doAssert unchanged[0].pos == (0'f32, 0'f32)

block senderAge:
  var age = 0.0
  let send = sendDatum
  sendDatum = proc(p: Peer, k: Kind, d: Datum) = age = float64(d.age)
  left.tick(0.075)
  doAssert abs(age - 0.075) < 0.000001
  left.tick(0.025)
  doAssert abs(age - 0.1) < 0.000001
  sendDatum = send

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
doAssert not b[0].trigger.state

echo "sync checks passed"

block kineticSamples:
  type Body = object
    id : Uid
    kin: sync_k2
    tag: int
  var n = network(2, 1)
  var tx = initSync(n, 8)
  var source = @[Body(id: id, kin: sync_k2(p: (0,0), v: (10,0)))]
  tx.publish(source)
  var sample = tx.kind.row[0]
  sample.age = Seconds(0.2)

  var rx = initSync(n, 9)
  rx.horizon = Seconds(1)
  var bodies = @[Body(id: id, kin: sync_k2(p: (2,0), v: (10,0)), tag: 17)]
  rx.publish(bodies)
  rx.kind.queue.add (1'u64, sample)
  rx.reconcile(n, bodies, 0.01)
  doAssert abs(bodies[0].kin.p.x - 2) < 0.0001 # transit age included
  for i in 0..<10:
    bodies[0].kin.drift(0.05)
    rx.reconcile(n, bodies, 0.05)
  doAssert abs(bodies[0].kin.p.x - 7) < 0.0001 # cached age also included
  doAssert bodies[0].tag == 17

  # A stop is a new velocity sample, not an inferred intention.
  source[0].kin = sync_k2(p: (7,0), v: (0,0))
  tx.publish(source)
  sample = tx.kind.row[0]
  sample.age = Seconds(0.15)
  rx.kind.queue.add (1'u64, sample)
  rx.reconcile(n, bodies, 0.25)
  doAssert bodies[0].kin.v.x < 10

  # Motion reports beyond the horizon are discarded, not frozen as targets.
  var capped = initSync(n, 10)
  capped.rate = 1000
  bodies[0].kin = sync_k2()
  capped.publish(bodies)
  tx.publish(@[Body(id: id, kin: sync_k2(v: (10,0)))])
  sample = tx.kind.row[0]
  sample.age = Seconds(0.25)
  capped.kind.queue.add (1'u64, sample)
  capped.reconcile(n, bodies, 0.1)
  doAssert abs(bodies[0].kin.p.x - 2.5) < 0.0001

  let projected = bodies[0].kin
  sample.age = Seconds(1)
  inc sample.revision
  capped.kind.queue.add (1'u64, sample)
  capped.reconcile(n, bodies, 0.1)
  doAssert bodies[0].kin == projected

  # Malformed ages cannot poison state or advance the revision watermark.
  let old = bodies[0].kin
  for age in [-1.0, Inf, NaN]:
    sample.age = Seconds(age)
    inc sample.revision
    capped.kind.queue.add (1'u64, sample)
    capped.reconcile(n, bodies, 0)
    doAssert bodies[0].kin == old

  # Finite coordinates may still overflow during projection.
  tx.publish(@[Body(id: id, kin: sync_k2(p: (3.4e38,0), v: (3.4e38,0)))])
  sample = tx.kind.row[0]
  sample.revision = 100
  sample.age = Seconds(0.25)
  capped.kind.queue.add (1'u64, sample)
  capped.reconcile(n, bodies, 0.1)
  doAssert bodies[0].kin == old

  var expired = initSync(n, 11)
  expired.publish(bodies)
  sample.age = expired.ttl
  expired.kind.queue.add (1'u64, sample)
  expired.reconcile(n, bodies, 0.1)
  doAssert bodies[0].kin == old

  echo "kinetic sample checks passed"
