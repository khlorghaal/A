# The header owns constants and ABI; compile the implementation exactly once.
import std/os

const root = currentSourcePath().parentDir
{.passC: "-I" & root.}
{.compile: "native/termbox.c".}

{.push header: "native/termbox.h".}
type
  TbEvent* {.bycopy, importc: "struct tb_event".} = object
    `type`*, `mod`*: uint8
    key*: uint16
    ch*: uint32
    w*, h*, x*, y*: int32

{.pop.}
const
  TB_EVENT_KEY*   = 1'u8
  TB_EVENT_RESIZE* = 2'u8
  TB_EVENT_MOUSE* = 3'u8
  TB_KEY_CTRL_C*  = 0x03'u16
  TB_KEY_ESC*     = 0x1b'u16
  TB_KEY_ARROW_UP*   = 0xffff'u16 - 18
  TB_KEY_ARROW_DOWN* = 0xffff'u16 - 19
  TB_KEY_ARROW_LEFT* = 0xffff'u16 - 20
  TB_KEY_ARROW_RIGHT* = 0xffff'u16 - 21
  TB_KEY_MOUSE_LEFT* = 0xffff'u16 - 23
  TB_INPUT_ESC*        = 1.cint
  TB_INPUT_MOUSE*      = 4.cint
  TB_OUTPUT_TRUECOLOR* = 5.cint
{.push header: "native/termbox.h", importc.}

proc a_init_locale*(): cint
proc tb_wcwidth*(ch: uint32): cint
proc tb_init*(): cint
proc tb_shutdown*(): cint
proc tb_width*(): cint
proc tb_height*(): cint
proc tb_set_input_mode*(mode: cint): cint
proc tb_set_output_mode*(mode: cint): cint
proc tb_set_clear_attrs*(fg, bg: uint32): cint
proc tb_hide_cursor*(): cint
proc tb_clear*(): cint
proc tb_present*(): cint
proc tb_peek_event*(event: ptr TbEvent, timeout: cint): cint
proc tb_print*(x, y: cint, fg, bg: uint32, text: cstring): cint
proc tb_set_cell_ex*(x, y: cint, ch: ptr uint32, n: csize_t,
                     fg, bg: uint32): cint
{.pop.}
