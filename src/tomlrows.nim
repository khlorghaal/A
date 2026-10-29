## Small TOML subset used by the application's scalar tables.
import std/[algorithm, json, math, os, sequtils, strutils, tables]

type Sections* = Table[string, Table[string, JsonNode]]

proc readSections*(path: string): Sections =
  if not fileExists(path): return
  var section = ""
  for raw in lines(path):
    let line = raw.strip()
    if line.len == 0 or line[0] == '#': continue
    if line[0] == '[' and line[^1] == ']':
      section = line[1..^2]
      if section.len == 0 or section in result:
        raise newException(ValueError, "invalid or repeated TOML section")
      result[section] = initTable[string, JsonNode]()
      continue
    if section.len == 0 or line[0] != '"':
      raise newException(ValueError, "invalid TOML entry in " & path)
    var i = 1
    var escaped = false
    while i < line.len:
      if not escaped and line[i] == '"': break
      if not escaped and line[i] == '\\': escaped = true
      else: escaped = false
      inc i
    if i >= line.len: raise newException(ValueError, "unterminated TOML key")
    let key = parseJson(line[0..i]).getStr()
    let tail = line[i+1..^1].strip()
    if tail.len < 2 or tail[0] != '=':
      raise newException(ValueError, "invalid TOML value")
    if key in result[section]: raise newException(ValueError, "duplicate TOML key")
    result[section][key] = parseJson(tail[1..^1].strip())

proc writeSections*(path: string, sections: Sections) =
  var names: seq[string]
  for name in sections.keys: names.add name
  names.sort()
  var data = ""
  for name in names:
    if name.len == 0 or name.anyIt(it notin {'a'..'z', 'A'..'Z', '0'..'9', '_'}):
      raise newException(ValueError, "invalid TOML section name")
    data.add "[" & name & "]\n"
    var keys: seq[string]
    for key in sections[name].keys: keys.add key
    keys.sort()
    for key in keys:
      let value = sections[name][key]
      if value.isNil or value.kind notin {JString, JInt, JFloat, JBool}:
        raise newException(ValueError, "unsupported TOML value")
      if value.kind == JFloat and classify(value.getFloat()) in {fcNan, fcInf, fcNegInf}:
        raise newException(ValueError, "nonfinite TOML value")
      data.add $(%key) & " = " & $value & "\n"
    data.add "\n"
  let tmp = path & ".tmp"
  writeFile(tmp, data)
  moveFile(tmp, path)
