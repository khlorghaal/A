import std/[macros, times, unicode, posix]

{.emit: """
#define TB_IMPL 1
#define TB_OPT_ATTR_W 32
#define TB_OPT_LIBC_WCHAR
#define TB_OPT_EGC 1
#include "deps/termbox2/termbox2.h"
""".}

type
  i2 =array[2, int32]
  rgb=uint32
  i32= int32
  u32=uint32
  str=string

macro vecOps(T: typedesc; ops: varargs[untyped]): untyped=
  for op in ops: result.add quote do:
    proc `op`(a,b: `T`): `T`= [a.x `op` b.x, a.y `op` b.y]
vecOps(i2, `+`, `-`, `*`, `/`)

proc all(v: array[2, bool]): bool=  v.x and v.y
proc any(v: array[2, bool]): bool=  v.x  or v.y

proc isBound(v, a, b: i2): bool=
  let lo= v >= a
  let hi= v < b
  all([lo.x and hi.x, lo.y and hi.y])

const
  usec=         1'u64
  msec=      1000'u64
  sec = 1_000_000'u64

var
  t0: int64
  tdt= 25 * msec
  now: int64
  randS: int64
  tick: int64

  sdim: i2
  view: i2= [0, 0]

  colBaseFg: rgb= 0xfafafa
  colBaseBg: rgb= 0x020202
  colDpadFg: rgb= 0x111111
  colDpadBg: rgb= 0x222222
  colDbgFg : rgb= 0x000000
  colDbgBg : rgb= 0x00ee00
  colShipBg: rgb= 0xeeeeee

type
  Uid= object
    h, l: uint64
  grapheme= distinct string
  
  Ship= object
    id : Uid
    p  : i2
    hp : int32
    cd : int32
    msl: int32
    chr: grapheme
    fac: rgb

  Cell= object
    g: grapheme
    fg, bg: rgb

proc nowUs(): int64=
  getMonoTime().toUnixFloat().int64 * sec.int64 +
    (getMonoTime().nanosecond div 1000).int64 - t0

proc hrng(): int64=
  let s= randS + 17171
  var r=           s * cast[int64](0x5D747531573B1B'u64);\
      r= (r shr 7) xor cast[int64](0x73513D1B7117B3'u64)
  randS= r
  r

proc genUid(): Uid=
  Uid(h: cast[uint64](hrng()), l: cast[uint64](hrng()))

const
  etypShip= 0b0001'u64
  etypMisl= 0b0010'u64
  etypFigt= 0b0100'u64
  etypSttn= 0b1000'u64

var
  ccmuMask: uint64
  dbgDur: int64
  dbgp= "init"

proc bad(s: string)=
  dbgp= s
  dbgDur= 120

const shipMax= 0xffffe

var
  ships: array[shipMax, Ship]
  shipsEnd: int

proc allocShip(): ptr Ship=
  if shipsEnd >= shipMax:
    ccmuMask= ccmuMask or etypShip
    bad("cant more entity")
    dec shipsEnd

  result= addr ships[shipsEnd]
  inc shipsEnd

proc initShips()=
  for i in 0..<7:
    let s= allocShip()
    s[]= Ship(
      id: genUid(),
      hp: 16,
      cd: 0,
      msl: 255,
      chr: "A",
      fac: 0xeeeeee,
      p: [int32(i * 2 - 8), int32(i mod 2 * 3)]
    )

const
  actU= 0'u16
  actL= 1'u16
  actR= 2'u16
  actD= 3'u16
  actF= 4'u16

proc act(a: uint16)=
  var p= addr ships.x.p

  case a
  of actU: p[] += [0, 1]
  of actL: p[] += [-1, 0]
  of actR: p[] += [1, 0]
  of actD: p[] += [0, -1]
  else: discard
proc egcCodepoints(s: string): seq[uint32]=
  ## Convert exactly one UTF-8 grapheme cluster to the codepoint
  ## sequence expected by tb_set_cell_ex().
  for r in s.runes:
    result.add r.uint32

proc draw(m: i2; c: Cell)=
  let v= m - view + sdim / 2
  let cp= egcCodepoints(c.g)

  if cp.len != 0:
    tb_set_cell_ex(
      v.x.cint,
      v.y.cint,
      cast[ptr uint32](cp.x.addr),
      cp.len.csize_t,
      c.fg,
      c.bg
    )

proc main()=
  if tb_init() != 0:
    return

  defer:
    tb_shutdown()

  sdim= [tb_width().int32, tb_height().int32]

  tb_set_input_mode(tbInputEsc or tbInputMouse)

  if tb_set_output_mode(tbOutputTruecolor)== 0:
    discard
  elif tb_set_output_mode(tbOutput256)== 0:
    discard
  elif tb_set_output_mode(tbOutputNormal)== 0:
    discard
  elif tb_set_output_mode(tbOutputGrayscale)== 0:
    discard
  else:
    bad($tb_strerror(tb_last_errno()))

  tb_set_clear_attrs(colBaseFg, colBaseBg)
  tb_hide_cursor()
  tb_clear()

  initShips()

  t0= nowUs()
  now= 0
  var tp: int64

  while true:
    var
      mau: i2= [0, 0]
      ev: TbEvent

    while tb_peek_event(addr ev, 0)== 0:
      if ev.`type` != tbEventKey.uint8 and ev.`type` != tbEventMouse.uint8:
        break

      case ev.key
      of tbKeyArrowUp: act(actU)
      of tbKeyArrowLeft: act(actL)
      of tbKeyArrowRight: act(actR)
      of tbKeyArrowDown: act(actD)

      of tbKeyMouseLeft:
        mau= [ev.x, ev.y]

      of tbKeyCtrlC, tbKeyEsc:
        return

      else:
        discard

    block:
      const l= [
        "      ┌─────┐      ", "      uuuuuuu      ",
        "      │↑↑↑↑↑│      ", "      uuuuuuu      ",
        "      │↑↑↑↑↑│      ", "      uuuuuuu      ",
        "      │↑↑↑↑↑│      ", "      uuuuuuu      ",
        "┌─────┼─────┼─────┐", "llllll uuuuu rrrrrr",
        "│←←←←←│     │→→→→→│", "lllllll     rrrrrrr",
        "│←←←←←│     │→→→→→│", "lllllll     rrrrrrr",
        "│←←←←←│     │→→→→→│", "lllllll     rrrrrrr",
        "└─────┼─────┼─────┘", "llllll ddddd rrrrrr",
        "      │↓↓↓↓↓│      ", "      ddddddd      ",
        "      │↓↓↓↓↓│      ", "      ddddddd      ",
        "      │↓↓↓↓↓│      ", "      ddddddd      ",
        "      └─────┘      ", "      ddddddd      "
      ]

      let
        padWh: i2= [l[0].len.int32, 16]
        padO= sdim - padWh - [3, 3]

      for i in 0..<padWh.y:
        tb_print(
          padO.x.cint,
          (padO.y + i).cint,
          colDpadFg,
          colDpadBg,
          l[i * 2].cstring
        )

      let dp= mau - padO

      if isBound(dp, [0, 0], padWh):
        case l[dp.y * 2 + 1][dp.x]
        of 'u': act(actU)
        of 'l': act(actL)
        of 'r': act(actR)
        of 'd': act(actD)
        else: discard

    for s in ships:
      var sv: i2

      case hrng().mod(5)
      of 0: sv= [ 1, 0]
      of 1: sv= [-1, 0]
      else: sv= [ 0, 0]

      s.p+= sv

      draw(s.p, Cell(
         g: s.chr,
        fg: s.fac,
        bg: colShipBg
      ))

    if dbgDur > 0:
      tb_print(0, 0, colDbgFg, colDbgBg, dbgp.cstring)
      dec dbgDur

    tb_present()
    tb_clear()

    sdim= [tb_width(), tb_height()]

    tp= now
    now= nowUs()
    let ddt= int64(tdt) - (now - tp)
    if ddt > 2:
      sleep(ddt div 1000)

    inc tick

when isMainModule:
  main()
