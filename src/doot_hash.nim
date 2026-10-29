## The original integer hash returns the low 32 bits (hash_t = uint32).

type Hash32* = uint32

func dootHash*(input: uint32): Hash32 =
  let a0 = input * 0x9E3779B1'u32
  let a1 = input * 0x85EBCA77'u32
  let a2 = input * 0xC2B2AE3D'u32
  let a3 = input * 0x27D4EB2F'u32
  var y = uint64(a2 xor a3)
  y = y xor ((y shl 16) or (y shr 16))
  (a0 xor a1) xor uint32(y and 0xffffffff'u64)

func dootHash*(input: uint64): Hash32 =
  let a0 = input * 0xC43A65E071D385B1'u64
  let a1 = input * 0x9A232294BAEEBB27'u64
  let a2 = input * 0xAC0671A220DFABF7'u64
  let a3 = input * 0xB59BC8E3F34FFF6B'u64
  var y = a2 xor a3
  y = y xor ((y shl 32) or (y shr 32))
  uint32((a0 xor a1 xor y) and 0xffffffff'u64)

func dootHash*(input: int32): Hash32 = dootHash(cast[uint32](input))
func dootHash*(input: int64): Hash32 = dootHash(cast[uint64](input))
func dootHash*(input: pointer): Hash32 = dootHash(cast[uint64](input))

func dootRand*(input: uint32): uint32 = dootHash(input)
func dootRand*(input: float32): float32 =
  float32(dootRand(cast[uint32](input))) / float32(high(uint32))
