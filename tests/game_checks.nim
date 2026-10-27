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
  doAssert ships[0].p == v(-8,0)
  doAssert ships[6].p == v(4,0)
  doAssert ships[0].id != ships[1].id
  let other = ships[1].p
  act(actU); doAssert ships[0].p == v(-8,-1)
  act(actL); doAssert ships[0].p == v(-9,-1)
  act(actR); act(actD); act(actF)
  doAssert ships[0].p == v(-8,0)
  doAssert ships[1].p == other

block padButtons:
  sdim = v(100,36)
  let origin = sdim - v(13,13) - v(3,3)
  ships[0].p = v(0,0)
  drawPad(origin + v(6,1));  doAssert ships[0].p == v( 0,-1)
  drawPad(origin + v(1,5));  doAssert ships[0].p == v(-1,-1)
  drawPad(origin + v(11,5)); doAssert ships[0].p == v( 0,-1)
  drawPad(origin + v(6,10)); doAssert ships[0].p == v( 0, 0)

block camera:
  ships[0].p = v(42,-17)
  sdim = v(100,36)
  stepShips()
  doAssert view == ships[0].p
  doAssert ships[0].p - view + sdim div 2 == v(50,18)

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
