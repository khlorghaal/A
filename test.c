#define TB_IMPL 1
#define TB_OPT_ATTR_W 32
#include "deps/termbox2/termbox2.h"

int main(void){
	if(tb_init()!=TB_OK)
		return 1;

	tb_set_output_mode(TB_OUTPUT_TRUECOLOR);
	// tb_set_clear_attrs(0xffffff,0x000000);
	tb_clear();

	tb_print(1,1,0x000001,0xffffff,"white");
	tb_print(1,2,0x000001,0xff0000,"red");
	tb_print(1,3,0x000001,0x00ff00,"green");
	tb_print(1,4,0x000001,0x0000ff,"blue");
	tb_print(1,5,0x000001,0xffff00,"yellow");
	tb_print(1,6,0x000001,0x00ffff,"cyan");
	tb_print(1,7,0x000001,0xff00ff,"magenta");
	tb_print(1,8,0x654321,0x123456,"custom");

	tb_present();

	tb_poll_event(&(struct tb_event){0});

	tb_shutdown();
	return 0;
}
