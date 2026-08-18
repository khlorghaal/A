#define NCURSES_WIDECHAR 1
#include <ncursesw/ncurses.h>
#include <time.h>
#include <stdint.h>
#include <stdlib.h>
#include <locale.h>
#include <stddef.h>

#define let(x) if(1;x)
#define ra(   i,n) for(int i=0; i <  n; i++)
#define ra2(i,a,b) for(int i=a; i <  b; i++)
#define ea(   e,s) for(  e=s.a; e!=s.b; e++)
#define en( i,e,s) for(int i=0, e =s.a; e!=s.b;e++,i++)
#define re  return
#define rer return r;

//clang.llvm.org/docs/LanguageExtensions.html#vectors-and-extended-vectors
typedef float f2 __attribute__((ext_vector_type(2)));
typedef int   i2 __attribute__((ext_vector_type(2)));
typedef bool  b2 __attribute__((ext_vector_type(2)));
typedef  int64_t i64;
typedef uint64_t u64;
typedef  wchar_t wch;
inline static bool all(i2 v){ re   v.x & v.y; }
inline static bool any(i2 v){ re   v.x | v.y; }
bool isbound(i2 v, i2 a, i2 b){
	re all( v>=a & v<b );}

//microsecond basis
u64 usec= 1;
u64 msec= 1000;
u64 sec=  1000000;
u64 t0= 0;//zero, appstart, because monotonic
static u64 now_us(void){
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC,&ts);
	re (u64)ts.tv_sec*sec + ts.tv_nsec/1000 - t0;
}

i2 sdim;//screen dimension

i2 p= {0,0};
i64 tick;

static void draw(i2 p, char c){
	mvaddch(p.y,p.x,c);
}

static void update(i2* p){
}

int main(void){
	setlocale(LC_ALL, "C.utf8");
	initscr();
	noecho();
	cbreak();
	timeout(0);
	curs_set(0);
	mousemask(ALL_MOUSE_EVENTS,NULL);//REPORT_MOUSE_POSITION todo mobile dichot
	mouseinterval(0);
	nodelay(stdscr,1);
	set_escdelay(0);
	start_color();

	//palette
	init_pair(1, COLOR_WHITE, COLOR_BLACK);
	attron(1);
	wbkgd(stdscr, COLOR_PAIR(1)|'.');//fill

	//init
	getmaxyx(stdscr,sdim.y,sdim.x);
	p= sdim/2;

	//timing
	const u64 tdt= 20*msec;//target dt
	t0= now_us();//init
	u64 t = 0;//most recent
	u64 tp= 0;//previous
	//monad
	while(1){
		getmaxyx(stdscr,sdim.y,sdim.x);
		// sdim.x= 20; sdim.y= 20;//!!
		clear();
		
		//input
		i2 mau= {0,0};
		
		int ch= 0;
		while((ch=getch())!=ERR){
			switch(ch){
			case KEY_MOUSE:
				MEVENT m;
			if(getmouse(&m)!=OK)
					break;
				mau= (i2){m.x,m.y};
				break;

			case 27://ESC
				goto exit;

			default: break;
			}
		}

		{
			i2 pad_wh= {7,7};
			i2 pad_o= sdim-pad_wh-3;
			if(!isbound( mau,pad_o,pad_o+pad_wh ))
				goto end_input;
			wch l[7][22]= {
				L"  ┌─┐  ",
				L"  │↑│  ",
				L"┌─┼─┼─┐",
				L"│←│ │→│",
				L"└─┼─┼─┘",
				L"  │↓│  ",
				L"  └─┘  "};
			ra(i,7)
				mvaddwstr( pad_o.y+i,pad_o.x,l[i]);
			i2 dp= mau-pad_o;
			if(!isbound( dp,(i2){0,0},(i2){7,7} ))
				goto end_input;

			char kmap_dpad[7][8]= {//8 as null
				"  uuu  ",
				"  uuu  ",
				"ll   rr",
				"ll   rr",
				"ll   rr",
				"  ddd  ",
				"  ddd  "};
			char in_k= kmap_dpad[dp.y][dp.x];
			if(in_k=='u') p+= (i2){ 0, 1};
			if(in_k=='l') p+= (i2){-1, 0};
			if(in_k=='r') p+= (i2){ 1, 0};
			if(in_k=='d') p+= (i2){ 0,-1};

			end_input:
		}

		//entities
		{
			update(&p);
			draw(p,'A');
		}
		
		refresh();

		//timing
		tp= t;
		t= now_us();
		i64 ddt= (tdt)-(t-tp);
		if(ddt>2){
			struct timespec sl={0,ddt*1000};
			nanosleep(&sl,NULL);
		}else{//lag
			;
		}
		tick++;
	}

exit:
	endwin();
	re 0;
}
