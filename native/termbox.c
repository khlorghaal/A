#define TB_IMPL 1
#include "termbox.h"

#include <locale.h>

int a_init_locale(void){
	return setlocale(LC_ALL, "") != NULL;
}
