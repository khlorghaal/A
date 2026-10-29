import ../src/doot_hash

doAssert dootHash(0'u32) == 0'u32
doAssert dootHash(1'u32) == 0xbba813b2'u32
doAssert dootHash(high(uint32)) == 0xbba813b2'u32
doAssert dootHash(0'u64) == 0'u32
doAssert dootHash(1'u64) == 0x0130d34b'u32
doAssert dootHash(high(uint64)) == 0x0130d34b'u32
doAssert dootHash(-1'i32) == dootHash(high(uint32))
doAssert dootHash(-1'i64) == dootHash(high(uint64))
doAssert dootRand(0'u32) == 0
doAssert dootRand(0'f32) == 0
echo "doot hash checks passed"
