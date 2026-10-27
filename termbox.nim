import std/os
import futhark

const root = currentSourcePath().parentDir
{.passC: "-I" & root.}
{.compile: "deps/termbox.c".}

importc:
  path root / "deps"
  rename struct_tb_event, TbEvent
  rename "struct_tb_event.type", kind
  "termbox.h"
