## Interactive true-color termbox sample.
import ../src/client

proc main(): int =
  if tb_init() != TB_OK: return 1
  defer: discard tb_shutdown()

  discard tb_set_output_mode(TB_OUTPUT_TRUECOLOR)
  discard tb_clear()

  const rows = [
    (0x000001'u32, 0xffffff'u32, "white"),
    (0x000001'u32, 0xff0000'u32, "red"),
    (0x000001'u32, 0x00ff00'u32, "green"),
    (0x000001'u32, 0x0000ff'u32, "blue"),
    (0x000001'u32, 0xffff00'u32, "yellow"),
    (0x000001'u32, 0x00ffff'u32, "cyan"),
    (0x000001'u32, 0xff00ff'u32, "magenta"),
    (0x654321'u32, 0x123456'u32, "custom")]

  for i, (fg, bg, label) in rows:
    discard tb_print(1, int32(i+1), fg, bg, label.cstring)

  discard tb_present()
  var event: TbEvent
  discard tb_poll_event(addr event)
  0

when isMainModule: quit main()
