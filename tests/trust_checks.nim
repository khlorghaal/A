import std/math
import ../src/trust

template near(a, b: untyped) = doAssert abs(a - b) < 0.00001
near aggregate([Opinion(reporter: 0.5, value: 0.8),
                Opinion(reporter: 1.0, value: 0.6)]), 0.5
near aggregate([]), 0
near combined(1, 0.5, 0), 0.6
near reliability(30), 1
near reliability(80), 0.8
near reliability(150), 0.5
near reliability(400), 0.05
near reliability(55), 0.9
near reliability(999), 0.05
near positionTrust(0, 1), 0.9
near selfHitTrust(1, 0), 0.8
near otherHitTrust(1, 0), 0.5
var c = Credibility(value: 0.5)
c.desync(1)
c.advance(1)
near c.discredit, 0.95
near c.value, 0.4995975
c.advance(19)
near c.discredit, 0
near c.value, 0.509105
echo "trust checks passed"
