## Test map: writer lease; framed sync; migration/NFC; bounds, bootstrap and atomic saves.
import std/[os, tables, times, math, osproc]
import ../src/[trustdb, identity]
import ../src/[gateway_frames, gateway_snapshot]

if paramCount() == 2 and paramStr(1) in ["--try-lock", "--hold-lock"]:
  try:
    let lock = acquireLock(paramStr(2))
    if paramStr(1) == "--hold-lock":
      writeFile(paramStr(2) & ".ready", "ready")
      while true: sleep(50)
    lock.release()
    quit(0)
  except OSError: quit(3)

# Process-level locking and recovery after owner exit.
block writerOwnership:
  let path = getTempDir() / ("a-ownership-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  createDir(path)
  defer: removeDir(path)
  let file = path / ".owner.lock"
  let owner = acquireLock(file)
  let contender = startProcess(getAppFilename(), args = @["--try-lock", file])
  doAssert contender.waitForExit(2000) == 3
  contender.close()
  owner.release()
  owner.release() # repeated release never closes another descriptor
  let holder = startProcess(getAppFilename(), args = @["--hold-lock", file])
  defer:
    if holder.running: holder.terminate()
    discard holder.waitForExit(2000)
    holder.close()
  let deadline = epochTime() + 2
  while not fileExists(file & ".ready") and epochTime() < deadline: sleep(10)
  doAssert fileExists(file & ".ready")
  var rejected = false
  try:
    let unexpected = acquireLock(file)
    unexpected.release()
  except OSError: rejected = true
  doAssert rejected
  holder.terminate()
  doAssert holder.waitForExit(2000) != -1
  let recovered = acquireLock(file) # lock file remains; kernel ownership gone
  recovered.release()

# Complete snapshot replacement, framing and commit-before-publish behavior.
block framedManualSync:
  let path = getTempDir() / ("a-framed-sync-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  defer: removeDir(path)
  var db: TrustDb
  var reader = initFrameReader(1024)
  let payload = encodeSnapshot({"remote": 0.5'f32}.toTable, 1024, 16)
  let wire = frame(payload, 1024)
  var deliveries = 0
  for c in wire:
    reader.feed($c, proc(body: string) =
      db.syncParagon(decodeSnapshot(body, 1024, 16), path)
      inc deliveries)
  reader.finish()
  doAssert deliveries == 1
  doAssert abs(load(path).credibility("remote") - 0.4) < 0.00001
  doAssert load(path).witnessed.len == 0

block swarmQuota:
  var db = TrustDb(maxSwarmReports: 1)
  db.setSwarm("reporter", "subject", 0.5)
  db.setSwarm("reporter", "subject", 0.6)
  try:
    db.setSwarm("another", "subject", 0.9)
    doAssert false
  except ValueError: discard
  doAssert db.swarm.len == 1
  doAssert db.swarm[("reporter", "subject")] == 0.6'f32

block bootstrapPriors:
  var db: TrustDb
  db.bootstrap(["new"])
  doAssert abs(db.credibility("new") - 0.4) < 0.00001
  doAssert db.witnessed.len == 0 and db.swarm.len == 0
  db.setParagon("new", 0.9)
  db.bootstrap(["new"])
  doAssert abs(db.credibility("new") - 0.56) < 0.00001 # retain original W=.5
  db.setWitness("new", 0.2)
  db.bootstrap(["new"])
  doAssert abs(db.credibility("new") - 0.44) < 0.00001
  var varied: TrustDb
  varied.setParagon("a", 0.2)
  varied.setParagon("b", 0.8)
  varied.bootstrap(["a", "b"])
  doAssert abs(varied.credibility("a") - 0.28) < 0.00001
  doAssert abs(varied.credibility("b") - 0.52) < 0.00001
  let path = getTempDir() / ("a-priors-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  defer: removeDir(path)
  varied.save(path)
  var restored = load(path)
  doAssert restored.witnessed.len == 0
  doAssert abs(restored.credibility("a") - 0.28) < 0.00001
  restored.desync("a", 0.5)
  doAssert abs(restored.witnessed["a"] - 0.5) < 0.00001
  restored.save(path)
  doAssert "a" in load(path).witnessed

block manualSnapshots:
  let path = getTempDir() / ("a-snapshot-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  defer: removeDir(path)
  var db: TrustDb
  db.setWitness("local", 0.7)
  db.setParagon("obsolete", 0.9)
  db.syncParagon({"fresh": 0.5'f32}.toTable, path)
  doAssert "obsolete" notin db.paragon
  doAssert abs(db.credibility("fresh") - 0.4) < 0.00001
  doAssert db.witnessed["local"] == 0.7'f32
  doAssert "fresh" notin db.witnessed
  let before = readFile(path / "trust.toml")
  try:
    db.syncParagon({"bad": NaN.float32}.toTable, path)
    doAssert false
  except ValueError: discard
  doAssert readFile(path / "trust.toml") == before
  doAssert "fresh" in db.paragon
  createDir(path / "trust.toml.tmp")
  try:
    db.syncParagon({"different": 0.2'f32}.toTable, path)
    doAssert false
  except IOError, OSError: discard
  doAssert "fresh" in db.paragon and "different" notin db.paragon
  removeDir(path / "trust.toml.tmp")
  db.syncParagon(initTable[string, float32](), path)
  doAssert db.paragon.len == 0
  doAssert db.witnessed["local"] == 0.7'f32

block transactions:
  let path = getTempDir() / ("a-transaction-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  createDir(path)
  defer: removeDir(path)
  writeFile(path / "trust_witnessed.toml", "[trust]\nsubject = 0.6\n")
  writeFile(path / "trust_paragon.toml", "[trust]\nsubject = 0.2\n")
  var db = load(path)
  db.save(path)
  doAssert fileExists(path / "trust.toml")
  writeFile(path / "trust_paragon.toml", "invalid legacy file")
  doAssert abs(load(path).paragon["subject"] - 0.2) < 0.00001
  let committed = readFile(path / "trust.toml")
  writeFile(path / "trust.toml.tmp", "incomplete replacement")
  doAssert readFile(path / "trust.toml") == committed
  doAssert abs(load(path).witnessed["subject"] - 0.6) < 0.00001
  removeFile(path / "trust.toml.tmp")
  createDir(path / "trust.toml.tmp") # force staging failure
  db.setWitness("subject", 0.9)
  try:
    db.save(path)
    doAssert false
  except IOError, OSError: discard
  doAssert readFile(path / "trust.toml") == committed
  removeDir(path / "trust.toml.tmp")
  db.save(path)
  doAssert abs(load(path).witnessed["subject"] - 0.9) < 0.00001
  writeFile(path / "trust.toml", "[trust]\nsubject = 0.8\n")
  try:
    discard load(path)
    doAssert false
  except ValueError: discard # no fallback to stale legacy state

block isolatedClients:
  let tmp = getTempDir() / ("a-db-fixture-" & $getCurrentProcessId() & "-" & $int(epochTime()))
  for i in 1..4:
    let dir = tmp / "A" / ("testclient" & $i)
    var client: TrustDb
    client.setWitness("shared-peer", float32(i) / 4)
    client.save(dir)
  for i in 1..4:
    let dir = tmp / "A" / ("testclient" & $i)
    doAssert abs(load(dir).witnessed["shared-peer"] - float32(i) / 4) < 0.00001
  removeDir(tmp)

let dir = getTempDir() / ("a-trustdb-" & $getCurrentProcessId() & "-" & $int(epochTime()))
createDir(dir)
var db: TrustDb
let composed = "é🙂"
let decomposed = "é🙂"

doAssert playerId(decomposed) == composed
doAssert playerId("Ａ") != playerId("A")
for invalid in ["", "bad\0id", "\xFF"]:
  try:
    discard playerId(invalid)
    doAssert false
  except ValueError: discard

db.setWitness(composed, 0.8)
db.setWitness(decomposed, 0.8)
db.setWitness("quote\"\\\n", 0.7)
db.setWitness("apostrophe' and esc\x1b", 0.6)
db.setWitness("literal\\e and \\'", 0.4)
db.setParagon(composed, 0.5)
db.setWitness("alice", 1)
db.setParagon("alice", 1)
db.setSwarm("alice", composed, 0.5)
db.save(dir)

let loaded = load(dir)
doAssert abs(loaded.witnessed[composed] - 0.8) < 0.00001
doAssert decomposed notin loaded.witnessed
doAssert abs(loaded.credibility(decomposed) - loaded.credibility(composed)) < 0.00001
doAssert abs(loaded.witnessed["quote\"\\\n"] - 0.7) < 0.00001
doAssert abs(loaded.witnessed["apostrophe' and esc\x1b"] - 0.6) < 0.00001
doAssert abs(loaded.witnessed["literal\\e and \\'"] - 0.4) < 0.00001
doAssert loaded.swarm.len == 0
doAssert not fileExists(dir / "trust_swarm.toml")

var direct: TrustDb
direct.witnessed[decomposed] = 0.3
direct.save(dir)
doAssert abs(load(dir).witnessed[composed] - 0.3) < 0.00001
direct.witnessed[composed] = 0.4
try:
  direct.save(dir)
  doAssert false
except ValueError: discard
doAssert abs(load(dir).witnessed[composed] - 0.3) < 0.00001

var invalid: TrustDb
invalid.witnessed["would-replace"] = 0.9
invalid.paragon["invalid"] = NaN.float32
try:
  invalid.save(dir)
  doAssert false
except ValueError: discard
doAssert abs(load(dir).witnessed[composed] - 0.3) < 0.00001

if fileExists(dir / "trust.toml"): removeFile(dir / "trust.toml")
writeFile(dir / "trust_witnessed.toml", "[trust]\nalice = 0.5 # standard TOML comment\n")
doAssert abs(load(dir).witnessed["alice"] - 0.5) < 0.00001

var persisted: TrustDb
persisted.setWitness("subject", 0.8)
persisted.desync("subject", 0.6)
persisted.save(dir)
var restarted = load(dir)
persisted.advance(1)
restarted.advance(1)
doAssert abs(persisted.witnessed["subject"] - restarted.witnessed["subject"]) < 0.000001
persisted.witnessed.del("subject")
try:
  persisted.save(dir)
  doAssert false
except ValueError: discard
doAssert "subject" in load(dir).witnessed

db.refresh()
db.refresh()
doAssert abs(db.credibility(composed) - 0.6) < 0.00001
var poisoned: TrustDb
poisoned.setWitness("reporter", 0.5)
poisoned.refresh()
let previous = poisoned.credibility("reporter")
poisoned.swarm[("reporter", "subject")] = Inf.float32
try:
  poisoned.refresh()
  doAssert false
except ValueError: discard
doAssert poisoned.credibility("reporter") == previous
poisoned.swarm.clear()
poisoned.witnessed[decomposed] = 0.5
try:
  poisoned.refresh()
  doAssert false
except ValueError: discard

db.setSwarm("alice", composed, 1)
db.refresh()
doAssert abs(db.credibility(composed) - 0.68) < 0.00001
db.desync(composed, 1)
db.advance(1)
doAssert db.witnessed[composed] < 0.8

try:
  db.setWitness("bad", NaN.float32)
  doAssert false
except ValueError: discard

if fileExists(dir / "trust.toml"): removeFile(dir / "trust.toml")
writeFile(dir / "trust_witnessed.toml", "[trust]\n\"é\" = 0.5\n\"é\" = 0.6\n")
try:
  discard load(dir)
  doAssert false
except ValueError: discard
removeFile(dir / "trust_witnessed.toml")

writeFile(dir / "trust_paragon.toml", "[trust]\n\"bad\" = 1.5\n")
try:
  discard load(dir)
  doAssert false
except ValueError: discard
writeFile(dir / "trust_paragon.toml", "[trust]\n\"bad\" = [1, 2]\n")
try:
  discard load(dir)
  doAssert false
except ValueError: discard
removeDir(dir)
echo "trust database checks passed"
