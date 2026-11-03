import std/[tables, math]
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
