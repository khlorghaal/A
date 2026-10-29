import std/[os, tables, times, math]
import ../src/[trustdb, identity]

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
doAssert loaded.swarm.len == 0
doAssert not fileExists(dir / "trust_swarm.toml")

db.refresh()
db.refresh()
doAssert abs(db.credibility(composed) - 0.6) < 0.00001
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
removeDir(dir)
echo "trust database checks passed"
