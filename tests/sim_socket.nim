## Deterministic datagram gateway. Time is advanced explicitly in milliseconds.
import std/[random, algorithm]
import ../src/p2p

type
  Flight = object
    at, sent: int64
    dst     : PeerId
    event   : Event
  Gateway* = object
    now*, latency*, jitter*: int64
    loss*          : float64
    sent*, dropped*: int
    rng            : Rand
    flights        : seq[Flight]

proc initGateway*(latency, jitter: int64, loss: float64, seed: int64): Gateway =
  doAssert latency >= 0 and jitter >= 0 and loss >= 0 and loss <= 1
  Gateway(latency: latency, jitter: jitter, loss: loss, rng: initRand(seed))

proc send*(g: var Gateway, dst: PeerId, e: Event) =
  inc g.sent
  if g.rng.rand(1.0) < g.loss:
    inc g.dropped
    return
  let variation = if g.jitter == 0: 0'i64 else: g.rng.rand(int(g.jitter * 2)).int64 - g.jitter
  g.flights.add Flight(at: g.now + max(0'i64, g.latency + variation),
                       sent: g.now, dst: dst, event: e)

proc advance*(g: var Gateway, dt: int64) =
  doAssert dt >= 0
  g.now += dt

proc recv*(g: var Gateway, dst: PeerId): seq[Event] =
  g.flights.sort(proc(a,b: Flight): int = cmp(a.at, b.at))
  var pending: seq[Flight]
  for f in g.flights:
    if f.dst == dst and f.at <= g.now:
      var e = f.event
      e.datum.age += float64(g.now - f.sent)/1000
      result.add e
    else: pending.add f
  g.flights = pending
