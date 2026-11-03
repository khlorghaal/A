## A-to-blastd boundary. Time arguments are seconds; ping is milliseconds.
import blastd except Seconds, Milliseconds, seconds, milliseconds
import units
export blastd except Seconds, Milliseconds, seconds, milliseconds
export units

proc tick*(n: var Net, dt: units.Seconds) =
  blastd.tick(n, blastd.Seconds(float64(dt)))
