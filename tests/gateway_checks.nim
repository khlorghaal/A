## Test map: report revisions/roles; persistence/migration; tombstones/quotas; dispatch.
import std/[tables, math, os, options, json]
import ../src/gateway_snapshot
import ../src/gateway
var g: Gateway
g.setParagons(["a", "b"])
g.beginSession("a", 1)
g.beginSession("b", 2)
doAssert g.receive("a", "ship", 1, 10, 1)
doAssert not g.receive("a", "ship", 1, 10, 0)
doAssert not g.receive("a", "ship", 0, 11, 0)
doAssert not g.receive("other", "ship", 0, 1, 1)
doAssert g.receive("b", "ship", 2, 1, 0.5)
let weights = proc(id: string): float32 = (if id == "a": 0.4'f32 else: 0.8'f32)
doAssert abs(g.snapshot(weights)["ship"] - 0.4) < 0.00001
g.beginSession("a", 3)
doAssert not g.receive("a", "ship", 1, 100, 1)
doAssert g.receive("a", "ship", 3, 1, 0.5)
doAssert abs(g.snapshot(weights)["ship"] - 0.3) < 0.00001
g.setParagons(["b"])
doAssert not g.receive("a", "ship", 3, 2, 1)
doAssert abs(g.snapshot(weights)["ship"] - 0.4) < 0.00001
g.setParagons(["a", "b"])
doAssert abs(g.snapshot(weights)["ship"] - 0.4) < 0.00001
doAssert not g.receive("a", "ship", 3, 3, 1) # re-add must not revive old session
try:
  discard g.receive("b", "ship", 2, 2, NaN.float32)
  doAssert false
except ValueError: discard
try:
  discard g.snapshot(proc(id: string): float32 = Inf.float32)
  doAssert false
except ValueError: discard
echo "gateway report state checks passed"

# Save failures preserve committed bytes; restart restores data, not live sessions.
block persistence:
  let path = getTempDir() / ("a-gateway-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  defer: removeDir(path)
  doAssert g.receive("b", "ship", 2, high(uint64), 0.5)
  g.save(path)
  let committed = readFile(path / "gateway.json")
  try:
    g.save(path, maxBytes = 1)
    doAssert false
  except ValueError: discard
  doAssert readFile(path / "gateway.json") == committed
  writeFile(path / "gateway.json.tmp", "abandoned")
  var restored = loadGateway(path)
  doAssert abs(restored.snapshot(weights)["ship"] - 0.4) < 0.00001
  doAssert not restored.receive("b", "ship", 2, high(uint64), 0.5)
  restored.beginSession("b", 4)
  doAssert restored.receive("b", "ship", 4, 1, 0.25)
  doAssert abs(restored.snapshot(weights)["ship"] - 0.2) < 0.00001
  removeFile(path / "gateway.json.tmp")
  createDir(path / "gateway.json.tmp")
  try:
    restored.save(path)
    doAssert false
  except IOError, OSError: discard
  doAssert readFile(path / "gateway.json") == committed
  removeDir(path / "gateway.json.tmp")
  try:
    discard loadGateway(path, maxBytes = 1)
    doAssert false
  except ValueError: discard

block legacyGateway:
  let path = getTempDir() / ("a-gateway-v1-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  createDir(path)
  defer: removeDir(path)
  writeFile(path / "gateway.json",
    "{\"version\":1,\"paragons\":[\"a\"],\"reports\":[[\"a\",\"ship\",0.5,\"1\"]]}")
  let restored = loadGateway(path)
  doAssert abs(restored.snapshot(weights)["ship"] - 0.2) < 0.00001
  writeFile(path / "gateway.json", "{}")
  try:
    discard loadGateway(path)
    doAssert false
  except ValueError: discard

block deletion:
  var state: Gateway
  state.setParagons(["a", "b"])
  state.beginSession("a", 1)
  state.beginSession("b", 2)
  doAssert state.receive("a", "ship", 1, 1, 1)
  doAssert state.receive("b", "ship", 2, 1, 0.5)
  doAssert state.receive("a", "ship", 1, 2, 0, deleted = true)
  doAssert not state.receive("a", "ship", 1, 1, 1)
  doAssert abs(state.snapshot(weights)["ship"] - 0.4) < 0.00001
  doAssert state.receive("a", "ship", 1, 3, 1)
  doAssert state.receive("b", "ship", 2, 2, 0, deleted = true)
  doAssert state.receive("a", "ship", 1, 4, 0, deleted = true)
  doAssert "ship" notin state.snapshot(weights)
  let path = getTempDir() / ("a-tombstones-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  defer: removeDir(path)
  state.save(path)
  doAssert "ship" notin loadGateway(path).snapshot(weights)

block quotas:
  var state = initGateway(maxReports = 1)
  state.setParagons(["a"])
  state.beginSession("a", 1)
  doAssert state.receive("a", "first", 1, 1, 0.5)
  doAssert state.receive("a", "first", 1, 2, 0.4)
  try:
    discard state.receive("a", "second", 1, 1, 0.5)
    doAssert false
  except ValueError: discard
  doAssert state.snapshot(weights).len == 1

# Snapshot access and report authority remain distinct at dispatch boundary.
block operationDispatch:
  var state: Gateway
  state.setParagons(["a"])
  state.beginSession("a", 1)
  let ordinary = some(GatewaySession(playerId: "ordinary", epoch: 7))
  let paragon = some(GatewaySession(playerId: "a", epoch: 1))
  let snapshot = "{\"version\":1,\"operation\":\"snapshot\"}"
  let report = "{\"version\":1,\"operation\":\"report\",\"subject\":\"ship\",\"revision\":\"1\",\"value\":0.5}"
  for session in [none(GatewaySession), ordinary]:
    try:
      discard state.dispatch(session, report, weights)
      doAssert false
    except ValueError: discard
  doAssert parseJson(state.dispatch(paragon, report, weights))["accepted"].getBool
  doAssert not parseJson(state.dispatch(paragon, report, weights))["accepted"].getBool
  doAssert abs(decodeSnapshot(state.dispatch(ordinary, snapshot, weights), 65536, 4096)["ship"] - 0.2) < 0.00001
  var forged = parseJson(report)
  forged["reporter"] = %"other"
  try:
    discard state.dispatch(paragon, $forged, weights)
    doAssert false
  except ValueError: discard
  state.setParagons([])
  try:
    discard state.dispatch(paragon, report, weights)
    doAssert false
  except ValueError: discard
  doAssert decodeSnapshot(state.dispatch(ordinary, snapshot, weights), 65536, 4096).len == 0

block storedDispatch:
  var state: Gateway
  state.setParagons(["a"])
  state.beginSession("a", 1)
  let session = some(GatewaySession(playerId: "a", epoch: 1))
  let report = "{\"version\":1,\"operation\":\"report\",\"subject\":\"ship\",\"revision\":\"1\",\"value\":0.5}"
  let path = getTempDir() / ("a-stored-dispatch-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  createDir(path)
  defer: removeDir(path)
  createDir(path / "gateway.json.tmp")
  try:
    discard state.dispatchStored(session, report, path, weights)
    doAssert false
  except IOError, OSError: discard
  doAssert "ship" notin state.snapshot(weights)
  removeDir(path / "gateway.json.tmp")
  let ack = state.dispatchStored(session, report, path, weights)
  doAssert parseJson(ack)["accepted"].getBool
  doAssert abs(loadGateway(path).snapshot(weights)["ship"] - 0.2) < 0.00001
