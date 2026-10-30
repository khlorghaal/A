## Saturate a scalar to the unit interval.
func sat*(x: float32): float32 = clamp(x, 0'f32, 1'f32)
