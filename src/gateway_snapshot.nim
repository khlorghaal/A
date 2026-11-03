## Draft v1 manual paragon snapshot payload; transport and auth remain external.
import std/[json, tables, math]
import identity

proc decodeSnapshot*(payload: string,
                     maxBytes, maxEntries: int): Table[string, float32] =
  if maxBytes <= 0 or maxEntries < 0 or payload.len > maxBytes:
    raise newException(ValueError, "snapshot exceeds limits")

  let root = parseJson(payload)
  if root.kind != JObject or root.len != 3 or not root.hasKey("version") or
     not root.hasKey("kind") or not root.hasKey("rows"):
    raise newException(ValueError, "invalid snapshot envelope")
  if root["version"].kind != JInt or root["version"].getInt != 1 or
     root["kind"].kind != JString or root["kind"].getStr != "paragon" or
     root["rows"].kind != JArray or root["rows"].len > maxEntries:
    raise newException(ValueError, "unsupported snapshot")

  for row in root["rows"]:
    if row.kind != JArray or row.len != 2 or row[0].kind != JString or
       row[1].kind notin {JInt, JFloat}:
      raise newException(ValueError, "invalid snapshot row")
    let raw   = row[0].getStr
    let id    = playerId(raw)
    let value = row[1].getFloat
    if id != raw or id in result or classify(value) in {fcNan, fcInf, fcNegInf} or
       value < 0 or value > 1:
      raise newException(ValueError, "invalid snapshot value or identity")
    result[id] = float32(value)

proc encodeSnapshot*(values: Table[string, float32],
                     maxBytes, maxEntries: int): string =
  if maxBytes <= 0 or maxEntries < 0 or values.len > maxEntries:
    raise newException(ValueError, "snapshot exceeds limits")
  var rows = newJArray()
  for id, value in values:
    if playerId(id) != id or classify(value) in {fcNan, fcInf, fcNegInf} or
       value < 0 or value > 1:
      raise newException(ValueError, "invalid snapshot value or identity")
    rows.add %*[id, value]
  result = $(%*{"version": 1, "kind": "paragon", "rows": rows})
  if result.len > maxBytes: raise newException(ValueError, "snapshot exceeds limits")
