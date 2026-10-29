## Position assertions shared by the four-client terminal fixture.
import std/[math, strutils]

type Position* = tuple[x, y: float64]

proc parsePosition*(state: string): Position =
  let fields = state.splitWhitespace()
  if fields.len != 2: raise newException(ValueError, "invalid client state")
  result = (parseFloat(fields[0]), parseFloat(fields[1]))
  if classify(result.x) in {fcNan, fcInf, fcNegInf} or
     classify(result.y) in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, "non-finite client state")

proc checkMotion*(before, after: openArray[Position], elapsed: float64): seq[float64] =
  ## A movement smoke check; the returned offsets quantify owner control.
  doAssert before.len == 4 and after.len == 4
  doAssert elapsed >= 0 and classify(elapsed) notin {fcNan, fcInf, fcNegInf}
  var minX = Inf
  var maxX = NegInf
  var minY = Inf
  var maxY = NegInf
  for i in 0..<4:
    minX = min(minX, after[i].x)
    maxX = max(maxX, after[i].x)
    minY = min(minY, after[i].y)
    maxY = max(maxY, after[i].y)
    doAssert abs(after[i].x - before[i].x - 4*elapsed) < 0.5
    let displacement = before[i].y - after[i].y
    result.add displacement
    doAssert displacement > 0.2
  doAssert maxX - minX < 0.3
  doAssert maxY - minY < 0.3
