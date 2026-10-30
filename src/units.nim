## Time units used at network boundaries.
import std/math

type
  Milliseconds* = distinct int64
  Seconds*      = distinct float64

func `<`*(a, b: Milliseconds): bool {.borrow.}
func `==`*(a, b: Milliseconds): bool {.borrow.}
func `+`*(a, b: Seconds): Seconds {.borrow.}
func `-`*(a, b: Seconds): Seconds {.borrow.}
func `<`*(a, b: Seconds): bool {.borrow.}
func `<=`*(a, b: Seconds): bool {.borrow.}
proc `+=`*(a: var Seconds, b: Seconds) = a = a + b

func seconds*(ms: Milliseconds): Seconds =
  Seconds(float64(int64(ms)) / 1000)

func milliseconds*(s: Seconds): Milliseconds =
  let ms = float64(s) * 1000
  if classify(ms) in {fcNan, fcInf, fcNegInf} or
     ms < float64(low(int64)) or ms >= float64(high(int64)):
    raise newException(ValueError, "milliseconds out of range")
  Milliseconds(int64(round(ms)))
