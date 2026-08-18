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
i2 view= {0,0};

i2 p= {0,0};
i64 tick;

static void draw(i2 m, char c){
	i2 v= m-view+sdim/2;
	mvaddch(v.y,v.x,c);
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

	//timing
	const u64 tdt= 150*msec;//target dt
	t0= now_us();//init
	u64 t = 0;//most recent
	u64 tp= 0;//previous
	//monad
	while(1){
		getmaxyx(stdscr,sdim.y,sdim.x);
		erase();
		
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
			default:
			//seq dbg
				// mvprintw(0, 0, "ch= %d 0x%x", ch, ch);
				// struct timespec sl2= {0,200000000};
				// nanosleep(&sl2,0);
				break;
			// case 27://ESC
			// 	goto exit;

			// default: break;
			}
		}

		{
			i2 pad_wh= {7,7};
			i2 pad_o= sdim-pad_wh-3;
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
			if(isbound(dp, 0,pad_wh)){
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
			}
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
