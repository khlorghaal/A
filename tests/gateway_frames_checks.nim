import ../src/gateway_frames

let wire = frame("hello\0world", 32) & frame("", 32) & frame("last", 32)
for split in 0..wire.len:
  var r = initFrameReader(32)
  var got: seq[string]
  let take = proc(body: string) = got.add body
  r.feed(wire[0..<split], take)
  r.feed(wire[split..<wire.len], take)
  r.finish()
  doAssert got == @["hello\0world", "", "last"]
block bytewise:
  var r = initFrameReader(32)
  var got: seq[string]
  for c in wire: r.feed($c, proc(body: string) = got.add body)
  r.finish()
  doAssert got.len == 3
for count in 1..<frame("payload", 32).len:
  var r = initFrameReader(32)
  r.feed(frame("payload", 32)[0..<count], proc(body: string) = discard)
  try:
    r.finish()
    doAssert false
  except ValueError: discard
block oversized:
  var r = initFrameReader(4)
  try:
    r.feed("\xff\xff\xff\xff", proc(body: string) = doAssert false)
    doAssert false
  except ValueError: discard
  try:
    r.feed("", proc(body: string) = discard)
    doAssert false
  except ValueError: discard
for limit in [0, -1]:
  try:
    discard initFrameReader(limit)
    doAssert false
  except ValueError: discard
try:
  discard frame("12345", 4)
  doAssert false
except ValueError: discard
echo "gateway framing checks passed"
