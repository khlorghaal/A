import std/unicode

doAssert dbDirectory(@[]) == "build/client/db"
doAssert dbDirectory(@["--db-dir", "/tmp/custom"]) == "/tmp/custom"
try:
  discard dbDirectory(@["--db-dir"])
  doAssert false
except ValueError: discard

# Included only with -d:aTests. These checks never initialize the terminal.
doAssert sizeof(TbEvent) == 24
doAssert a_init_locale() != 0
doAssert tb_wcwidth(0x2192) == 1 # arrow
doAssert tb_wcwidth(0x0301) == 0 # combining acute

block geometry:
  doAssert isBound(v(0,0), v(0,0), v(13,13))
  doAssert not isBound(v(13,0), v(0,0), v(13,13))
  doAssert not isBound(v(0,-1), v(0,0), v(13,13))
  for y in 0..<pad.len div 2:
    doAssert pad[y*2].runeLen == 13
    doAssert pad[y*2 + 1].len == 13

block randomSequence:
  randS = 0
  const expected = [
    39271927420482907'i64,
    60871012468863784'i64,
    -18976775968185455'i64,
    36845834294481037'i64,
    -43750064880157872'i64,
    23465641536044409'i64,
    28337817587434774'i64,
    40562348764839469'i64]
  for value in expected: doAssert hrng() == value

block shipsAndInput:
  randS = 0
  initShips()
  doAssert shipsEnd == 7
  doAssert ships[0].kin.p == (-8'f32,0'f32)
  doAssert ships[6].kin.p == (4'f32,0'f32)
  doAssert ships[0].id != ships[1].id
  let other = ships[1].kin.p
  act(actU); doAssert ships[0].kin.p == (-8'f32,-1'f32)
  act(actL); doAssert ships[0].kin.p == (-9'f32,-1'f32)
  act(actR); act(actD); act(actF)
  doAssert ships[0].kin.p == (-8'f32,0'f32)
  doAssert ships[1].kin.p == other

block padButtons:
  sdim = v(100,36)
  let origin = sdim - v(13,13) - v(3,3)
  ships[0].kin.p = (0,0)
  drawPad(origin + v(6,1), act);  doAssert ships[0].kin.p == (0'f32,-1'f32)
  drawPad(origin + v(1,5), act);  doAssert ships[0].kin.p == (-1'f32,-1'f32)
  drawPad(origin + v(11,5), act); doAssert ships[0].kin.p == (0'f32,-1'f32)
  drawPad(origin + v(6,10), act); doAssert ships[0].kin.p == (0'f32,0'f32)

block camera:
  ships[0].kin.p = (42,-17)
  sdim = v(100,36)
  stepShips()
  doAssert view == ships[0].kin.p
  doAssert ships[0].kin.p == view

block capacity:
  shipsEnd = shipMax
  doAssert allocShip() == addr ships[shipMax - 1]
  doAssert shipsEnd == shipMax
  doAssert ccmuMask == etypShip
  doAssert dbgDur == 120

block clock:
  t0 = nowUs()
  let before = nowUs()
  sleep(2)
  doAssert nowUs() >= before + msec

echo "game checks passed (no terminal initialized)"
