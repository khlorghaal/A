## Fixed-depth buckets; a mutation can invalidate references into the map.
import std/hashes
import doot_hash

const BucketDepth* = 4

type
  Slot[K, V] = object
    occupied: bool
    key: K
    value: V
  HMap*[K, V] = object
    slots: seq[Slot[K, V]]
    count: int
    growFactor*: int
    expandPad*: int

func keyHash[K](key: K): uint32 =
  when K is uint32 or K is uint64 or K is int32 or K is int64 or K is pointer:
    dootHash(key)
  else:
    mixin hash
    cast[uint32](hash(key))

proc initHMap*[K, V](buckets = 32): HMap[K, V] =
  if buckets < 1: raise newException(ValueError, "bucket count must be positive")
  result.slots = newSeq[Slot[K, V]](buckets * BucketDepth)
  result.growFactor = 4
  result.expandPad = 1

func len*[K, V](m: HMap[K, V]): int = m.count

func bucket[K, V](m: HMap[K, V], key: K): int =
  int(uint64(keyHash(key)) mod uint64(m.slots.len div BucketDepth)) * BucketDepth

func find[K, V](m: HMap[K, V], key: K): int =
  if m.slots.len == 0: return -1
  let start = m.bucket(key)
  for i in start ..< start + BucketDepth:
    if not m.slots[i].occupied: return -1
    if m.slots[i].key == key: return i
  -1

func contains*[K, V](m: HMap[K, V], key: K): bool = m.find(key) >= 0

proc `[]`*[K, V](m: HMap[K, V], key: K): V =
  let i = m.find(key)
  if i < 0: raise newException(KeyError, "key not found")
  m.slots[i].value

proc grow[K, V](m: var HMap[K, V]) =
  if m.growFactor < 2 or m.expandPad < 1 or m.expandPad >= BucketDepth:
    raise newException(ValueError, "invalid growth settings")
  var buckets = m.slots.len div BucketDepth
  var counts: seq[int]
  # Monte Carlo allocation: keep expanding until padding fits every bucket.
  while true:
    buckets *= m.growFactor
    counts = newSeq[int](buckets)
    var fits = true
    for slot in m.slots:
      if slot.occupied:
        let b = int(uint64(keyHash(slot.key)) mod uint64(buckets))
        inc counts[b]
        if counts[b] + m.expandPad >= BucketDepth:
          fits = false
          break
    if fits: break
  var replacement = newSeq[Slot[K, V]](buckets * BucketDepth)
  for slot in m.slots:
    if slot.occupied:
      let start = int(uint64(keyHash(slot.key)) mod uint64(buckets)) * BucketDepth
      for i in start ..< start + BucketDepth:
        if not replacement[i].occupied:
          replacement[i] = slot
          break
  m.slots = move(replacement)

proc `[]=`*[K, V](m: var HMap[K, V], key: K, value: V) =
  if m.slots.len == 0: m = initHMap[K, V]()
  let existing = m.find(key)
  if existing >= 0:
    m.slots[existing].value = value
    return
  var start = m.bucket(key)
  if m.slots[start + BucketDepth - 1].occupied:
    m.grow()
    start = m.bucket(key)
  for i in start ..< start + BucketDepth:
    if not m.slots[i].occupied:
      m.slots[i] = Slot[K, V](occupied: true, key: key, value: value)
      inc m.count
      return
  raise newException(ValueError, "hash bucket is full")

proc del*[K, V](m: var HMap[K, V], key: K): bool =
  let i = m.find(key)
  if i < 0: return false
  let start = (i div BucketDepth) * BucketDepth
  var last = i
  while last + 1 < start + BucketDepth and m.slots[last + 1].occupied: inc last
  if i != last: m.slots[i] = move(m.slots[last])
  m.slots[last] = default(Slot[K, V])
  dec m.count
  true

proc clear*[K, V](m: var HMap[K, V]) =
  for slot in m.slots.mitems: slot = default(Slot[K, V])
  m.count = 0

iterator pairs*[K, V](m: HMap[K, V]): tuple[key: K, value: V] =
  for slot in m.slots:
    if slot.occupied: yield (slot.key, slot.value)
