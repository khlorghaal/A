## Gateway report state. Host supplies authenticated sessions and credibility policy.
import std/[tables, sets, math]
import identity

type
  GatewayReport* = object
    value*: float32
    revision*: uint64
  Gateway* = object
    paragons: HashSet[string]
    sessions: Table[string, uint64]
    reports: Table[tuple[reporter, subject: string], GatewayReport]

proc setParagons*(g: var Gateway, ids: openArray[string]) =
  var replacement: HashSet[string]
  for id in ids: replacement.incl playerId(id)
  g.paragons = move(replacement)
  var removed: seq[string]
  for id in g.sessions.keys:
    if id notin g.paragons: removed.add id
  for id in removed: g.sessions.del(id)
  var stale: seq[tuple[reporter, subject: string]]
  for key in g.reports.keys:
    if key.reporter notin g.paragons: stale.add key
  for key in stale: g.reports.del(key)

proc beginSession*(g: var Gateway, reporter: string, epoch: uint64) =
  ## Host epoch must be fresh and bound to authenticated connection, never body data.
  let id = playerId(reporter)
  if id notin g.paragons: raise newException(ValueError, "reporter not paragon")
  if id in g.sessions and g.sessions[id] == epoch:
    raise newException(ValueError, "session epoch reused")
  g.sessions[id] = epoch
  var keys: seq[tuple[reporter, subject: string]]
  for key in g.reports.keys:
    if key.reporter == id: keys.add key
  for key in keys: g.reports.del(key) # new session starts fresh report snapshot

proc receive*(g: var Gateway, reporter, subject: string,
              epoch, revision: uint64, value: float32): bool =
  let reporter = playerId(reporter)
  let subject = playerId(subject)
  if reporter notin g.paragons or reporter notin g.sessions or
     g.sessions[reporter] != epoch: return false
  if classify(value) in {fcNan, fcInf, fcNegInf} or value < 0 or value > 1:
    raise newException(ValueError, "invalid gateway report")
  let key = (reporter, subject)
  if key in g.reports and revision <= g.reports[key].revision: return false
  g.reports[key] = GatewayReport(value: value, revision: revision)
  true

proc snapshot*(g: Gateway, credibility: proc(id: string): float32): Table[string, float32] =
  ## Caller supplies one immutable previous-score view for entire aggregation step.
  if credibility.isNil: raise newException(ValueError, "missing reporter weights")
  var weights: Table[string, float32]
  var totals: Table[string, tuple[sum: float64, count: int]]
  for key, report in g.reports:
    if key.reporter notin g.paragons: continue
    if key.reporter notin weights:
      let weight = credibility(key.reporter)
      if classify(weight) in {fcNan, fcInf, fcNegInf} or weight < 0 or weight > 1:
        raise newException(ValueError, "invalid reporter weight")
      weights[key.reporter] = weight
    totals.mgetOrPut(key.subject, (0.0, 0)).sum += float64(weights[key.reporter])*float64(report.value)
    inc totals[key.subject].count
  for subject, total in totals: result[subject] = float32(total.sum / float64(total.count))
