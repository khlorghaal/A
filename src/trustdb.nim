## Persistent credibility values; swarm reports remain in memory.
import std/[math, os, sets, tables]
import toml_serialization
import trust, identity
when defined(posix):
  from std/posix import nil

type
  TrustDb* = object
    witnessed*, paragon*: Table[string, float32]
    swarm*              : Table[tuple[reporter, subject: string], float32]
    scores, discredit, prior: Table[string, float32]

func validValue(x: float32): bool =
  classify(x) notin {fcNan, fcInf, fcNegInf} and x >= 0 and x <= 1

proc checkedId(id: string, value: float32): string =
  result = playerId(id)
  if not validValue(value):
    raise newException(ValueError, "invalid credibility")

proc setWitness*(db: var TrustDb, id: string, value: float32) =
  let id = checkedId(id, value)
  db.witnessed[id] = value
  db.prior.del(id)

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
  for id, v in db.prior:
    if checkedId(id, v) != id or id in db.witnessed:
      raise newException(ValueError, "invalid bootstrap prior")
    subjects.incl id
  for id, v in db.witnessed:
    if checkedId(id, v) != id: raise newException(ValueError, "noncanonical player ID")
    subjects.incl id
  for id, v in db.paragon:
    if checkedId(id, v) != id: raise newException(ValueError, "noncanonical player ID")
    subjects.incl id
  for edge, v in db.swarm:
    if checkedId(edge.reporter, v) != edge.reporter or
       playerId(edge.subject) != edge.subject:
      raise newException(ValueError, "noncanonical player ID")
    subjects.incl edge.reporter
    subjects.incl edge.subject
  var totals: Table[string, tuple[sum: float32, count: int]]
  for edge, v in db.swarm:
    totals.mgetOrPut(edge.subject, (0'f32, 0)).sum +=
      db.scores.getOrDefault(edge.reporter) * v
    inc totals[edge.subject].count
  var next: Table[string, float32]
  for subject in subjects:
    let t = totals.getOrDefault(subject)
    let swarm = if t.count == 0: 0'f32 else: t.sum / float32(t.count)
    next[subject] = combined(db.witnessed.getOrDefault(subject, db.prior.getOrDefault(subject)),
                             db.paragon.getOrDefault(subject), swarm)
  db.scores = next

proc bootstrap*(db: var TrustDb, subjects: openArray[string]) =
  ## Seed unseen subjects; prior is local initialization, never firsthand evidence.
  var ids: seq[string]
  for id in subjects: ids.add playerId(id)
  var total = 0.0
  for id, value in db.paragon:
    if checkedId(id, value) != id: raise newException(ValueError, "noncanonical player ID")
    total += float64(value)
  let initial = if db.paragon.len == 0: 0.5'f32
                else: float32(total / float64(db.paragon.len))
  for id in ids:
    if id notin db.paragon: db.paragon[id] = 0.5'f32
    if id notin db.witnessed and id notin db.prior: db.prior[id] = initial
  db.refresh()

proc desync*(db: var TrustDb, id: string, severity: float32) =
  ## Severity is per discrepancy; packet-independent values need their own rule.
  let id = checkedId(id, severity)
  var c = Credibility(value: db.witnessed.getOrDefault(id, db.prior.getOrDefault(id)),
                      discredit: db.discredit.getOrDefault(id))
  c.desync(severity)
  db.setWitness(id, c.value)
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

proc readDb(path: string, witnessed = false, unified = false):
    tuple[trust, discredit, paragon, prior: Table[string, float32]] =
  if not fileExists(path): return
  var root: TomlValueRef
  try: root = Toml_v100.loadFile(path, TomlValueRef)
  except TomlError as e: raise newException(ValueError, "invalid trust TOML: " & e.msg)
  if root.kind != TomlKind.Table or "trust" notin root.tableVal:
    raise newException(ValueError, "invalid trust TOML: " & path)
  if unified and ("discredit" notin root.tableVal or "paragon" notin root.tableVal):
    raise newException(ValueError, "incomplete trust state: " & path)
  for name, section in root.tableVal:
    if name != "trust" and not (witnessed and name == "discredit") and
       not (unified and name in ["paragon", "prior"]):
      raise newException(ValueError, "invalid trust TOML: " & path)
    if section.kind notin {TomlKind.Table, TomlKind.InlineTable}:
      raise newException(ValueError, "invalid trust TOML: " & path)
    var values: Table[string, float32]
    for id, node in section.tableVal:
      let value = case node.kind
        of TomlKind.Float: float32(node.floatVal)
        of TomlKind.Int:   float32(node.intVal)
        else: raise newException(ValueError, "invalid credibility")
      let normalized = checkedId(id, value)
      if normalized in values:
        raise newException(ValueError, "duplicate normalized player ID in " & path)
      values[normalized] = value
    if name == "trust": result.trust      = move(values)
    elif name == "paragon": result.paragon = move(values)
    elif name == "prior": result.prior = move(values)
    else:               result.discredit = move(values)

proc writeDb(path: string, values: Table[string, float32],
             discredit, paragon, prior: Table[string, float32]) =
  let root = Toml_v100.decode("[trust]\n[discredit]\n[paragon]\n[prior]\n", TomlValueRef)
  for (name, data) in [("trust", values), ("discredit", discredit), ("paragon", paragon), ("prior", prior)]:
    if name notin root.tableVal: continue
    let section = root.tableVal[name]
    for id, value in data:
      let normalized = checkedId(id, value)
      if normalized in section.tableVal:
        raise newException(ValueError, "duplicate normalized player ID in " & path)
      section.tableVal[normalized] = TomlValueRef(kind: TomlKind.Float,
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
  var f = open(tmp, fmWrite)
  try:
    f.write(data)
    f.flushFile()
    when defined(posix):
      if posix.fsync(cint(f.getFileHandle())) != 0: raiseOSError(osLastError())
  finally: f.close()
  moveFile(tmp, path)
  when defined(posix):
    let fd = posix.open(parentDir(path).cstring, posix.O_RDONLY)
    if fd < 0: raiseOSError(osLastError())
    defer: discard posix.close(fd)
    if posix.fsync(fd) != 0: raiseOSError(osLastError())

proc load*(directory: string): TrustDb =
  let unified = fileExists(directory / "trust.toml")
  let witnessed = if unified: readDb(directory / "trust.toml", witnessed = true, unified = true)
                  else: readDb(directory / "trust_witnessed.toml", witnessed = true)
  result.witnessed = witnessed.trust
  result.discredit = witnessed.discredit
  result.prior = witnessed.prior
  for id in result.discredit.keys:
    if id notin result.witnessed:
      raise newException(ValueError, "discredit without witnessed credibility")
  result.paragon = if unified: witnessed.paragon
                   else: readDb(directory / "trust_paragon.toml").trust
  result.refresh()

proc save*(db: TrustDb, directory: string) =
  # Validate complete state before replacing live file.
  for values in [db.witnessed, db.paragon, db.discredit, db.prior]:
    var ids: HashSet[string]
    for id, value in values:
      let normalized = checkedId(id, value)
      if normalized in ids:
        raise newException(ValueError, "duplicate normalized player ID")
      ids.incl normalized
  var witnesses: HashSet[string]
  for id in db.witnessed.keys: witnesses.incl playerId(id)
  for id in db.discredit.keys:
    if id notin witnesses:
      raise newException(ValueError, "discredit without witnessed credibility")
  for id in db.prior.keys:
    if playerId(id) in witnesses:
      raise newException(ValueError, "prior overlaps firsthand witness")
  createDir(directory)
  writeDb(directory / "trust.toml", db.witnessed, db.discredit, db.paragon, db.prior)
