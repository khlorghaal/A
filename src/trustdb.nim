## Persistent credibility values; swarm reports remain in memory.
import std/[math, os, sets, tables]
import toml_serialization
import trust, identity

type
  TrustDb* = object
    witnessed*, paragon*: Table[string, float32]
    swarm*              : Table[tuple[reporter, subject: string], float32]
    scores, discredit   : Table[string, float32]

func validValue(x: float32): bool =
  classify(x) notin {fcNan, fcInf, fcNegInf} and x >= 0 and x <= 1

proc checkedId(id: string, value: float32): string =
  result = playerId(id)
  if not validValue(value):
    raise newException(ValueError, "invalid credibility")

proc setWitness*(db: var TrustDb, id: string, value: float32) =
  db.witnessed[checkedId(id, value)] = value

proc setParagon*(db: var TrustDb, id: string, value: float32) =
  db.paragon[checkedId(id, value)] = value

proc setSwarm*(db: var TrustDb, reporter, subject: string, value: float32) =
  let reporter = checkedId(reporter, value)
  let subject = playerId(subject)
  db.swarm[(reporter, subject)] = value

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
  let id = checkedId(id, severity)
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
  if not fileExists(path): return
  var root: TomlValueRef
  try: root = Toml_v100.loadFile(path, TomlValueRef)
  except TomlError as e: raise newException(ValueError, "invalid trust TOML: " & e.msg)
  if root.kind != TomlKind.Table or root.tableVal.len != 1 or
     "trust" notin root.tableVal:
    raise newException(ValueError, "invalid trust TOML: " & path)
  let trust = root.tableVal["trust"]
  if trust.kind notin {TomlKind.Table, TomlKind.InlineTable}:
    raise newException(ValueError, "invalid trust TOML: " & path)
  for id, node in trust.tableVal:
    let value = case node.kind
      of TomlKind.Float: float32(node.floatVal)
      of TomlKind.Int:   float32(node.intVal)
      else: raise newException(ValueError, "invalid credibility")
    let normalized = checkedId(id, value)
    if normalized in result:
      raise newException(ValueError, "duplicate normalized player ID in " & path)
    result[normalized] = value

proc writeDb(path: string, values: Table[string, float32]) =
  let root = Toml_v100.decode("[trust]\n", TomlValueRef)
  let trust = root.tableVal["trust"]
  for id, value in values:
    let normalized = checkedId(id, value)
    if normalized in trust.tableVal:
      raise newException(ValueError, "duplicate normalized player ID in " & path)
    trust.tableVal[normalized] = TomlValueRef(kind: TomlKind.Float,
                                             floatVal: value.float64)
  # The library emits non-TOML 1.0 escapes for ESC and apostrophe.
  let encoded = Toml_v100.encode(root)
  var data = ""
  var i = 0
  while i < encoded.len:
    if encoded[i] == '\\' and i + 1 < encoded.len:
      case encoded[i+1]
      of 'e':  data.add "\\u001B"
      of '\'': data.add '\''
      else:    data.add encoded[i..i+1]
      i += 2
    else:
      data.add encoded[i]
      inc i
  let tmp = path & ".tmp"
  writeFile(tmp, data)
  moveFile(tmp, path)

proc load*(directory: string): TrustDb =
  result.witnessed = readDb(directory / "trust_witnessed.toml")
  result.paragon   = readDb(directory / "trust_paragon.toml")
  result.refresh()

proc save*(db: TrustDb, directory: string) =
  # Validate both tables before replacing either file.
  for values in [db.witnessed, db.paragon]:
    var ids: HashSet[string]
    for id, value in values:
      let normalized = checkedId(id, value)
      if normalized in ids:
        raise newException(ValueError, "duplicate normalized player ID")
      ids.incl normalized
  createDir(directory)
  writeDb(directory / "trust_witnessed.toml", db.witnessed)
  writeDb(directory / "trust_paragon.toml",   db.paragon)
