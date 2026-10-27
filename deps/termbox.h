#ifndef A_TERMBOX_H
#define A_TERMBOX_H
#define TB_OPT_ATTR_W 32
#define TB_OPT_LIBC_WCHAR
#define TB_OPT_EGC 1
#include "termbox2/termbox2.h"
enum {
	keyUp    = TB_KEY_ARROW_UP,
	keyDown  = TB_KEY_ARROW_DOWN,
	keyLeft  = TB_KEY_ARROW_LEFT,
	keyRight = TB_KEY_ARROW_RIGHT,
	keyClick = TB_KEY_MOUSE_LEFT,
};
int a_init_locale(void);
#endif
