import ../src/hmap

var m = initHMap[int32, string](1)
for i in 0'i32..<200'i32: m[i] = $i
doAssert m.len == 200
for i in 0'i32..<200'i32: doAssert m[i] == $i
m[7'i32] = "seven"
doAssert m.len == 200 and m[7'i32] == "seven"
for i in 0'i32..<200'i32:
  doAssert m.del(i)
  doAssert not m.contains(i)
  doAssert not m.del(i)
doAssert m.len == 0
m[4'i32] = "four"
m.clear()
doAssert m.len == 0 and not m.contains(4'i32)

echo "doot hash map checks passed"
