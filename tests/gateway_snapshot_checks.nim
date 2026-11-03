## Test map: roundtrip/empty snapshots; malformed schema, IDs, values and limits.
import std/[tables, math]
import ../src/gateway_snapshot

let original = {"é🙂": 0.5'f32, "other": 1'f32}.toTable
let encoded = encodeSnapshot(original, 1024, 10)
doAssert decodeSnapshot(encoded, 1024, 10) == original
doAssert decodeSnapshot(encodeSnapshot(initTable[string, float32](), 1024, 0), 1024, 0).len == 0
for payload in ["{}", "[]", "{", "{\"version\":2,\"kind\":\"paragon\",\"rows\":[]}",
                "{\"version\":1,\"kind\":\"paragon\",\"rows\":[[\"a\",0.5],[\"a\",0.2]]}",
                "{\"version\":1,\"kind\":\"paragon\",\"rows\":[[\"a\",1.1]]}",
                "{\"version\":1,\"kind\":\"paragon\",\"rows\":[[\"é\",0.5]]}"]:
  try:
    discard decodeSnapshot(payload, 1024, 10)
    doAssert false
  except ValueError: discard
for limits in [(1024, 1), (1, 10)]:
  try:
    discard decodeSnapshot(encoded, limits[0], limits[1])
    doAssert false
  except ValueError: discard
try:
  discard encodeSnapshot({"bad": NaN.float32}.toTable, 1024, 10)
  doAssert false
except ValueError: discard
echo "gateway snapshot checks passed"
