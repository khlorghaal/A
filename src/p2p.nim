## A-to-blastd boundary. Core time values are unsigned milliseconds.
import blastd
import units
export blastd
export units

proc tick*(n: var Net, dt: units.Seconds) =
  let duration = int64(milliseconds(dt))
  if duration < 0: raise newException(ValueError, "negative tick duration")
  blastd.tick(n, uint64(duration))
