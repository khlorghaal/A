## Credibility and locally measured network reliability.

type
  Credibility* = object
    value*, discredit*: float32
  Opinion* = object
    reporter*, value*: float32

func unit(x: float32): float32 = clamp(x, 0'f32, 1'f32)

proc desync*(c: var Credibility, severity: float32) =
  ## Severity already accounts for the packet interval.
  c.discredit = unit(c.discredit + severity)

proc advance*(c: var Credibility, dt: float32) =
  c.discredit = unit(c.discredit - 0.05'f32 * dt)
  c.value = unit(c.value + (1 - c.value - c.discredit*c.discredit) * 0.001'f32 * dt)

func aggregate*(opinions: openArray[Opinion]): float32 =
  ## One current opinion per reporter; empty categories contribute zero.
  if opinions.len == 0: return 0
  for o in opinions:
    result += unit(o.reporter) * unit(o.value)
  result /= float32(opinions.len)

func combined*(witnessed, paragon, swarm: float32): float32 =
  0.4'f32*unit(witnessed) + 0.4'f32*unit(paragon) + 0.2'f32*unit(swarm)

func reliability*(pingMs: float32): float32 =
  const points = [(30'f32, 1'f32), (80'f32, 0.8'f32),
                  (150'f32, 0.5'f32), (400'f32, 0.05'f32)]
  if pingMs <= points[0][0]: return points[0][1]
  for i in 1..<points.len:
    let (x1, y1) = points[i]
    if pingMs <= x1:
      let (x0, y0) = points[i-1]
      return y0 + (y1-y0)*(pingMs-x0)/(x1-x0)
  points[^1][1]

func positionTrust*(cred, reliab: float32): float32 =
  0.1'f32*unit(cred) + 0.9'f32*unit(reliab)

func selfHitTrust*(cred, reliab: float32): float32 =
  0.8'f32*unit(cred) + 0.2'f32*unit(reliab)

func otherHitTrust*(cred, reliab: float32): float32 =
  0.5'f32*unit(cred) + 0.5'f32*unit(reliab)
