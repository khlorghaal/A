import std/[tables, math]
import ../src/[p2p, trustdb, trustsync]
from blastd import nil

static: doAssert not (Milliseconds is blastd.Milliseconds)
static: doAssert not compiles(Milliseconds(1) + Seconds(1))
static: doAssert not compiles(Seconds(1) + Milliseconds(1))
static: doAssert not compiles(Seconds(1) < Milliseconds(1))
doAssert float64(seconds(Milliseconds(1250))) == 1.25
doAssert int64(milliseconds(Seconds(1.25))) == 1250
doAssert int64(milliseconds(Seconds(-0.0015))) == -2
try:
  discard milliseconds(Seconds(NaN))
  doAssert false
except ValueError: discard

var leftDb = new TrustDb
leftDb[].bootstrap(["prior-only"])
leftDb[].setWitness("bob🙂", 0.8)
leftDb[].setSwarm("other", "secret", 0.4)
var rightDb = new TrustDb
rightDb[].setWitness("alice", 1)
rightDb[].setParagon("alice", 1)
rightDb[].refresh()
var left  = initNet(PeerInfo(id: 1, playerId: "alice"), 1)
var right = initNet(PeerInfo(id: 2, playerId: "carol"), 2)
var tx = initTrustSync(left, 4, leftDb)
var rx = initTrustSync(right, 4, rightDb)
tx.publish()
doAssert tx.kind.row.len == 1 # bootstrap prior must not masquerade as firsthand report
right.peers[1] = Peer(info: left.selph, trust: 0.5, up: (0'f32, 1'f32))
right.all = @[right.peers[1]]
right.near = right.all
var delivered: seq[Event]
var joins = @[Event(event: joined, source: right.selph)]
gather = proc(): seq[Event] =
  result = joins
  joins = @[]
traffic = proc(p: Peer) = discard
sendPeers = proc(p: Peer, peers: seq[PeerInfo]) = discard
sendDatum = proc(p: Peer, k: Kind, d: Datum) =
  delivered.add Event(event: data, source: left.selph, kind: k.id, datum: d)
accept = proc(p: Peer, k: Kind, d: Datum): bool = true
left.tick()
doAssert delivered.len >= 1
joins = delivered
let first = delivered[0].datum
delivered.setLen(0)
right.tick()
rx.receive(right)
rightDb[].refresh()
doAssert abs(rightDb[].swarm[("alice", "bob🙂")] - 0.8) < 0.00001
doAssert ("alice", "secret") notin rightDb[].swarm
doAssert abs(rightDb[].credibility("bob🙂") - 0.128) < 0.00001
leftDb[].setWitness("bob🙂", 0.2)
tx.publish()
rx.kind.queue.add (1'u64, tx.kind.row[0])
rx.receive(right)
rx.kind.queue.add (1'u64, first)
rx.receive(right)
doAssert abs(rightDb[].swarm[("alice", "bob🙂")] - 0.2) < 0.00001

block malformedReports:
  let malformed = [
    "{",
    "{\"subject\":\"bob🙂\",\"credibility\":-0.1}",
    "{\"subject\":\"bob🙂\",\"credibility\":1.1}",
    "{\"subject\":\"wrong\",\"credibility\":0.9}",
    "{\"subject\":\"\\u0000\",\"credibility\":0.9}"]
  for raw in malformed:
    var d = first
    d.revision = high(uint64)
    d.bytes = @[]
    for c in raw: d.bytes.add byte(c)
    rx.kind.queue.add (1'u64, d)
  var oversized = first
  oversized.revision = high(uint64)
  oversized.bytes = newSeq[byte](16_385)
  rx.kind.queue.add (1'u64, oversized)
  rx.kind.queue.add (999'u64, first)
  rx.receive(right)
  doAssert rx.kind.queue.len == 0
  doAssert abs(rightDb[].swarm[("alice", "bob🙂")] - 0.2) < 0.00001

  leftDb[].setWitness("bob🙂", 0.6)
  tx.publish()
  rx.kind.queue.add (1'u64, tx.kind.row[0])
  rx.receive(right)
  doAssert abs(rightDb[].swarm[("alice", "bob🙂")] - 0.6) < 0.00001

rx.attachPositionPolicy(right)
doAssert right.positionTrust(Peer(info: PeerInfo(id: 3), ping: blastd.Milliseconds(-1)), 0) == 0
right.reportDesync(1, 1)
rightDb[].advance(1)
doAssert rightDb[].witnessed["alice"] < 1
right.peers[1].ping = blastd.Milliseconds(80)
doAssert abs(right.positionTrust(right.peers[1], 0) - 0.8) < 0.0001
doAssert abs(right.positionTrust(right.peers[1], 0.3) - 0.82) < 0.0001
echo "witness dissemination checks passed"
