## Persistent credibility values; swarm reports remain in memory.
import std/[json, math, os, sets, tables]
import trust, tomlrows, identity

type
  TrustDb* = object
    witnessed*, paragon*: Table[string, float32]
    swarm*              : Table[tuple[reporter, subject: string], float32]
    scores, discredit   : Table[string, float32]

func validValue(x: float32): bool =
  classify(x) notin {fcNan, fcInf, fcNegInf} and x >= 0 and x <= 1

proc check(id: string, value: float32) =
  discard playerId(id)
  if not validValue(value):
    raise newException(ValueError, "invalid player ID or credibility")

proc setWitness*(db: var TrustDb, id: string, value: float32) =
  check(id, value)
  db.witnessed[playerId(id)] = value
proc setParagon*(db: var TrustDb, id: string, value: float32) =
  check(id, value)
  db.paragon[playerId(id)] = value
proc setSwarm*(db: var TrustDb, reporter, subject: string, value: float32) =
  check(reporter, value)
  check(subject, value)
  db.swarm[(playerId(reporter), playerId(subject))] = value
proc credibility*(db: TrustDb, subject: string): float32 =
  db.scores.getOrDefault(playerId(subject))

proc refresh*(db: var TrustDb) =
  ## One simultaneous step uses the previous combined scores for reporters.
  var subjects: HashSet[string]
  for id in db.witnessed.keys: subjects.incl id
  for id in db.paragon.keys: subjects.incl id
  for edge in db.swarm.keys:
    subjects.incl edge.reporter
    subjects.incl edge.subject
  var totals: Table[string, tuple[sum: float32, count: int]]
  for edge, value in db.swarm:
    totals.mgetOrPut(edge.subject, (0'f32, 0)).sum +=
      db.scores.getOrDefault(edge.reporter) * value
    inc totals[edge.subject].count
  var next: Table[string, float32]
  for subject in subjects:
    let t = totals.getOrDefault(subject)
    let swarm = if t.count == 0: 0'f32 else: t.sum / float32(t.count)
    next[subject] = combined(db.witnessed.getOrDefault(subject),
                             db.paragon.getOrDefault(subject), swarm)
  db.scores = next

proc desync*(db: var TrustDb, id: string, severity: float32) =
  ## Severity is per discrepancy; packet-independent values need their own rule.
  check(id, severity)
  let id = playerId(id)
  var c = Credibility(value: db.witnessed.getOrDefault(id),
                      discredit: db.discredit.getOrDefault(id))
  c.desync(severity)
  if id notin db.witnessed: db.witnessed[id] = c.value
  db.discredit[id] = c.discredit

proc advance*(db: var TrustDb, dt: float32) =
  if classify(dt) in {fcNan, fcInf, fcNegInf} or dt < 0:
    raise newException(ValueError, "invalid elapsed time")
  for id, value in db.witnessed.mpairs:
    var c = Credibility(value: value, discredit: db.discredit.getOrDefault(id))
    c.advance(dt)
    value = c.value
    if c.discredit > 0: db.discredit[id] = c.discredit
    else: db.discredit.del(id)
  db.refresh()

proc readDb(path: string): Table[string, float32] =
  let sections = readSections(path)
  if not fileExists(path): return
  if sections.len != 1 or "trust" notin sections:
    raise newException(ValueError, "invalid trust TOML: " & path)
  for id, node in sections["trust"]:
    if node.kind notin {JFloat, JInt}:
      raise newException(ValueError, "invalid credibility")
    let value = node.getFloat().float32
    check(id, value)
    let normalized = playerId(id)
    if normalized in result:
      raise newException(ValueError, "duplicate normalized player ID in " & path)
    result[normalized] = value

proc writeDb(path: string, values: Table[string, float32]) =
  var sections: Sections
  sections["trust"] = initTable[string, JsonNode]()
  for id, value in values:
    check(id, value)
    sections["trust"][id] = %value
  writeSections(path, sections)

proc load*(directory: string): TrustDb =
  result.witnessed = readDb(directory / "trust_witnessed.toml")
  result.paragon   = readDb(directory / "trust_paragon.toml")
  result.refresh()

proc save*(db: TrustDb, directory: string) =
  createDir(directory)
  writeDb(directory / "trust_witnessed.toml", db.witnessed)
  writeDb(directory / "trust_paragon.toml",   db.paragon)
