import std/[os, unicode]
import futhark

const root = currentSourcePath().parentDir
{.passC: "-I" & root.}
{.compile: "deps/termbox.c".}

importc:
  path root / "deps"
  rename struct_tb_event, TbEvent
  rename "struct_tb_event.type", kind
  "termbox.h"

type
  i2*       = tuple[x, y: int32]
  rgb*      = uint32
  Grapheme* = distinct string
  Action*   = enum actU, actL, actR, actD, actF

  Cell* = object
    g*      : Grapheme
    fg*, bg*: rgb

func `+`*(a, b: i2): i2          = (a.x + b.x, a.y + b.y)
func `-`*(a, b: i2): i2          = (a.x - b.x, a.y - b.y)
func `div`*(a: i2, b: int32): i2 = (a.x div b, a.y div b)
proc `+=`*(a: var i2, b: i2) = a = a + b
func v*(x, y: int32): i2 = (x, y)

func isBound*(v, a, b: i2): bool =
  v.x >= a.x and v.x < b.x and
  v.y >= a.y and v.y < b.y

const
  colBaseFg  = 0xfafafa'u32
  colBaseBg* = 0x020202'u32
  colDpadFg  = 0x111111'u32
  colDpadBg  = 0x444444'u32
  colDbgFg   = 0x000000'u32
  colDbgBg   = 0x00ee00'u32

var sdim*, view*: i2

proc initScreen*(): bool =
  if a_init_locale() == 0 or tb_init() != 0: return false
  discard tb_set_input_mode(TB_INPUT_ESC or TB_INPUT_MOUSE)
  discard tb_set_output_mode(TB_OUTPUT_TRUECOLOR)
  discard tb_set_clear_attrs(colBaseFg, colBaseBg)
  discard tb_hide_cursor()
  discard tb_clear()
  true

proc closeScreen*() = discard tb_shutdown()

proc screenSize*() =
  sdim = (int32(tb_width()), int32(tb_height()))

proc presentScreen*() =
  discard tb_present()
  discard tb_clear()

proc debugHeader*(text: string) =
  discard tb_print(0, 0, colDbgFg, colDbgBg, text.cstring)

proc draw*(m: i2, c: Cell) =
  let v = m - view + sdim div 2
  var cp: seq[uint32]
  for r in string(c.g).runes: cp.add uint32(r)
  if cp.len == 0: return

  discard tb_set_cell_ex(v.x, v.y, addr cp[0], csize_t(cp.len), c.fg, c.bg)

const pad* = [ # paired display / hit map; widths are terminal columns
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

proc drawPad*(mouse: i2, act: proc(a: Action)) =
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

