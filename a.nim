import std/[monotimes, os, unicode]
import termbox

type
  i2       = tuple[x, y: int32]
  rgb      = uint32
  Uid      = tuple[h, l: uint64]
  Grapheme = distinct string

  Ship = object
    id : Uid
    p  : i2
    hp : int32
    cd : int32
    msl: int32
    chr: Grapheme
    fac: rgb

  Cell = object
    g     : Grapheme
    fg, bg: rgb

func `+`(a, b: i2): i2          = (a.x + b.x, a.y + b.y)
func `-`(a, b: i2): i2          = (a.x - b.x, a.y - b.y)
func `div`(a: i2, b: int32): i2 = (a.x div b, a.y div b)
proc `+=`(a: var i2, b: i2) = a = a + b
func v(x, y: int32): i2 = (x, y)

func isBound(v, a, b: i2): bool =
  v.x >= a.x and v.x < b.x and
  v.y >= a.y and v.y < b.y

const
  usec =         1'i64
  msec =      1000'i64
  sec  = 1_000_000'i64
  tdt  = 25*msec

  colBaseFg = 0xfafafa'u32
  colBaseBg = 0x020202'u32
  colDpadFg = 0x111111'u32
  colDpadBg = 0x444444'u32
  colDbgFg  = 0x000000'u32
  colDbgBg  = 0x00ee00'u32
  colShipBg = 0xeeeeee'u32

  etypShip  = 0b0001'u64
  shipMax   = 0xffffe

var
  t0, now, tick: int64
  randS       : int64
  sdim, view  : i2
  ccmuMask    : uint64
  dbgDur      : int64
  dbgp        = "init"

  ships       : array[shipMax, Ship]
  shipsEnd    : int

proc nowUs(): int64 = getMonoTime().ticks div 1000 - t0

proc hrng(): int64 =
  let s = randS +% 17171
  var r = s *% 0x5D747531573B1B'i64
  r = ashr(r, 7) xor 0x73513D1B7117B3'i64
  randS = r
  r

proc genUid(): Uid =
  (cast[uint64](hrng()), cast[uint64](hrng()))

proc bad(s: string) =
  dbgp   = s
  dbgDur = 120

proc allocShip(): ptr Ship =
  if shipsEnd >= shipMax:
    ccmuMask = ccmuMask or etypShip
    bad("cant more entity")
    dec shipsEnd

  result = addr ships[shipsEnd]
  inc shipsEnd

proc initShips() =
  for i in 0..<7:
    allocShip()[] = Ship(
      id : genUid(), hp: 16, cd: 0, msl: 255,
      chr: Grapheme("A"), fac: 0xeeeeee,
      p  : (int32(i*2 - 8), int32(i mod 2*3)))

type Action = enum actU, actL, actR, actD, actF

proc act(a: Action) =
  case a
  of actU: ships[0].p += v( 0, 1)
  of actL: ships[0].p += v(-1, 0)
  of actR: ships[0].p += v( 1, 0)
  of actD: ships[0].p += v( 0,-1)
  of actF: discard

proc draw(m: i2, c: Cell) =
  let v = m - view + sdim div 2
  var cp: seq[uint32]
  for r in string(c.g).runes: cp.add uint32(r)
  if cp.len == 0: return

  discard tb_set_cell_ex(v.x, v.y, addr cp[0], csize_t(cp.len), c.fg, c.bg)

const pad = [ # paired display / hit map; widths are terminal columns
  "    ┌───┐    ", "    uuuuu    ",
  "    │↑↑↑│    ", "    uuuuu    ",
  "    │↑↑↑│    ", "    uuuuu    ",
  "    │↑↑↑│    ", "    uuuuu    ",
  "┌───┼───┼───┐", "llll     rrrr",
  "│←←←│   │→→→│", "llll     rrrr",
  "│←←←│   │→→→│", "llll     rrrr",
  "│←←←│   │→→→│", "llll     rrrr",
  "└───┼───┼───┘", "llll     rrrr",
  "    │↓↓↓│    ", "    ddddd    ",
  "    │↓↓↓│    ", "    ddddd    ",
  "    │↓↓↓│    ", "    ddddd    ",
  "    └───┘    ", "    ddddd    "]

proc drawPad(mouse: i2) =
  const wh: i2 = (int32(pad[0].runeLen), int32(pad.len div 2))
  let origin = sdim - wh - v(3, 3)
  for y in 0..<wh.y:
    discard tb_print(origin.x, origin.y + y,
                     colDpadFg, colDpadBg, pad[y*2].cstring)

  let p = mouse - origin
  if not isBound(p, v(0, 0), wh): return
  case pad[p.y*2 + 1][p.x]
  of 'u': act(actU)
  of 'l': act(actL)
  of 'r': act(actR)
  of 'd': act(actD)
  else: discard

proc stepShips() =
  for i in 0..<shipsEnd:
    case hrng() mod 5
    of 0: ships[i].p += v( 1, 0)
    of 1: ships[i].p += v(-1, 0)
    else: discard

    let s = ships[i]
    draw(s.p, Cell(g: s.chr, fg: s.fac, bg: colShipBg))

proc main(): int =
  if a_init_locale() == 0: return 1
  if tb_init() != 0: return 1
  defer: discard tb_shutdown()

  discard tb_set_input_mode(TB_INPUT_ESC or TB_INPUT_MOUSE)
  discard tb_set_output_mode(TB_OUTPUT_TRUECOLOR)
  discard tb_set_clear_attrs(colBaseFg, colBaseBg)
  discard tb_hide_cursor()
  discard tb_clear()

  initShips()
  t0 = nowUs()
  now = 0

  while true:
    let started = nowUs()
    sdim = (int32(tb_width()), int32(tb_height()))
    var mouse: i2 = v(-1,-1)
    var ev: TbEvent

    while tb_peek_event(addr ev, 0) == 0:
      if ev.`type` == TB_EVENT_RESIZE:
        sdim = (ev.w, ev.h)
        continue
      if ev.`type` notin [TB_EVENT_KEY, TB_EVENT_MOUSE]: continue

      case ev.key
      of TB_KEY_ARROW_UP   : act(actU)
      of TB_KEY_ARROW_LEFT : act(actL)
      of TB_KEY_ARROW_RIGHT: act(actR)
      of TB_KEY_ARROW_DOWN : act(actD)
      of TB_KEY_MOUSE_LEFT : mouse = (ev.x, ev.y)
      of TB_KEY_CTRL_C, TB_KEY_ESC: return 0
      else: discard

    drawPad(mouse)
    stepShips()
    if dbgDur > 0:
      discard tb_print(0, 0, colDbgFg, colDbgBg, dbgp.cstring)
      dec dbgDur

    discard tb_present()
    discard tb_clear()

    now = nowUs()
    let remaining = tdt - (now - started)
    if remaining >= msec: sleep(int(remaining div msec))
    inc tick

when defined(aTests):
  include tests/game_checks
elif isMainModule:
  quit main()
