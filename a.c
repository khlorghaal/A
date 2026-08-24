#define NCURSES_WIDECHAR 1
#include <ncursesw/ncurses.h>
#include <time.h>
#include <stdint.h>
// #include <stdlib.h>
#include <locale.h>
#include <stddef.h>

#define let(x) if(1;x)
#define ra(   i,n) for(int i=0; i <  n; i++)
#define ra2(i,a,b) for(int i=a; i <  b; i++)
#define re  return
#define rer return r;
#define cst const

//clang.llvm.org/docs/LanguageExtensions.html#vectors-and-extended-vectors
typedef float f2 __attribute__((ext_vector_type(2)));
typedef int   i2 __attribute__((ext_vector_type(2)));
typedef bool  b2 __attribute__((ext_vector_type(2)));
typedef  int64_t i64;
typedef uint64_t u64;
typedef  int32_t i32;
typedef uint32_t u32;
typedef  wchar_t* wch;//nullterm string because utf combining
typedef  cchar_t cch;//cell with format
inline static bool all(i2 v){ re   v.x & v.y; }
inline static bool any(i2 v){ re   v.x | v.y; }

const bool isbound(i2 v, i2 a, i2 b){
	re all( v>=a & v<b );}

//microsecond basis
const u64 usec= 1;
const u64 msec= 1000;
const u64 sec=  1000000;
i64 t0= 0;//zero, appstart, because monotonic
i64 now= 0;
static i64 now_us(void){
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC,&ts);
	re ts.tv_sec*sec + ts.tv_nsec/1000 - t0;
}

static volatile i64 rand_s= 0;
i64 rand(){
	i64 s= rand_s;
	i64 r= s*5374753573;
	r>>=7;
	r^=0x7351311713773;
	rand_s= r;
	rer; }
//todo rng quality lol

i2 sdim;//screen dimension
i2 view= {0,0};

typedef u32 rgb;

//todo contain
static short rgbpair(rgb fg, rgb bg){
	static short color = 16;
	static short pair  =  8;
	short fc = color++;
	short bc = color++;
	init_color(fc,
		((fg >> 16) & 0xff) * 1000 / 255,
		((fg >>  8) & 0xff) * 1000 / 255,
		( fg        & 0xff) * 1000 / 255);
	init_color(bc,
		((bg >> 16) & 0xff) * 1000 / 255,
		((bg >>  8) & 0xff) * 1000 / 255,
		( bg        & 0xff) * 1000 / 255);
	init_pair(pair, fc, bc);
	return pair++;
}
void cchgen(cch* r, wch c, rgb fg, rgb bg, bool bold, bool underline){
	attr_t a = 0;
	if(bold     ) a |= A_BOLD;
	if(underline) a |= A_UNDERLINE;
	setcchar(r, c, a, rgbpair(fg, bg), NULL);
}

#define EMAX 0xffff
// #define BMAX 0xffffff
//opt via rearranger phase
typedef struct{u64 h; u64 l;} uid;
uid genuid(){ re (uid){rand(),rand()}; };

#define E(T,D,I) \
  struct T D;\
  typedef struct D T;\
  T  T##s[EMAX];\
  T* T##s_end= T##s;\
  T init_##T(u64 i){ T r; I; T##s_end++; rer;};
#define ea(E,T) for(T* E=T##s; E!=T##s_end; E++)

E(ship,{
	uid id;         i2 p;  i32 h;  i32 c; i32 m;    cch s;},{
	  r.id=genuid(); r.p=0;   r.h=16; r.c=0; r.m= 255; cchgen(&r.s,L"A",0xeeeeee,0x000000,1,0); });
// E(misl,{ i2 p; i32 h; })
i64 tick;

static void draw(i2 m, cch* c){
	i2 v= m-view+sdim/2;
	mvadd_wch(v.y,v.x,c);
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
	ra(i,8)
		init_ship(i);
	

	//timing
	const u64 tdt= 150*msec;//target dt
	t0= now_us();//init
	now= 0;//most recent
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
			u32* l[7]= {
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
				i2* p= &ships[0].p;
				if(in_k=='u') *p+= (i2){ 0, 1};
				if(in_k=='l') *p+= (i2){-1, 0};
				if(in_k=='r') *p+= (i2){ 1, 0};
				if(in_k=='d') *p+= (i2){ 0,-1};
			}
		}

		//entities
		ea(s,ship){
			draw(s->p,&s->s);
		}
		
		refresh();

		//timing
		tp= now;
		now= now_us();
		i64 ddt= (tdt)-(now-tp);
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
