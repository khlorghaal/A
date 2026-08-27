#include <wchar.h>
#define NCURSES_WIDECHAR 1
#include <ncursesw/ncurses.h>
#include <time.h>
#include <stdint.h>
// #include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
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
typedef  uint8_t  u8;
typedef uint16_t u16;
typedef  int64_t i64;
typedef uint64_t u64;
typedef  int32_t i32;
typedef uint32_t u32;
typedef  wchar_t wch;//always nullterm string because utf combining
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
inline i64 rand(){
	i64 s= rand_s;
	i64 r=  s*0x5E747531573B1BULL;
	r= (r>>7)^0x73513E1B7117B3ULL;
	rand_s= r;
	rer; }

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
	re pair++;}
cch* cchgen(cch* r, wch* c, rgb fg, rgb bg, bool bold, bool underline){
	attr_t a = 0;
	if(bold     ) a |= A_BOLD;
	if(underline) a |= A_UNDERLINE;
	setcchar(r, c, a, rgbpair(fg, bg), NULL);
	rer;}

void bad(char* s){}
typedef struct{u64 h; u64 l;} uid;
uid genuid(){ re (uid){rand(),rand()}; };


typedef u64 etyp;
cst etyp etyp_ship= 0;
cst etyp etyp_misl= 1;
cst etyp etyp_figt= 2;
cst etyp etyp_sttn= 4;

//cannot create more units- starcraft style
etyp ccmu_mask= 0;
void ccmu(etyp v){
	ccmu_mask|= v;
	bad("cant more entity"); }

#define E(T,MAX,D,I) \
  typedef struct D T;\
  cst u64 T##_MAX= MAX;\
  T  T##s[MAX];\
  T* T##s_end= T##s;\
  T* T##s_cap= T##s+MAX;\
  T* init_##T(){ \
	  if(T##s_end>=T##s_cap){\
		  ccmu(etyp_##T); T##s_end--; }\
	  re T##s_end++;}
#define ea(E,T) for(T* E=T##s; E!=T##s_end; E++)

//opt via rearranger phase
E(ship,0xffffe,{
	uid id;         i2 p;  i32 h;  i32 c; i32 m;    cch s;},({
	   .id=genuid(),  .p=0,   .h=16,  .c=0,  .m= 255,
	    .s= cchgen(&.s,L"A",0xeeeeee,0x000000,1,0) }));
//fix palletize cchars
// E(misl,{ i2 p; i32 h; })
i64 tick;


const u16 ACT_U= 0;//direction
const u16 ACT_L= 1;
const u16 ACT_R= 2;
const u16 ACT_D= 3;
const u16 ACT_F= 4;
void act(u16 a){
  ship* own= ships+0;
  i2* p= &own->p;
	switch(a){
		case (ACT_U): *p+= (i2){ 0, 1}; break;
		case (ACT_L): *p+= (i2){-1, 0}; break;
		case (ACT_R): *p+= (i2){ 1, 0}; break;
		case (ACT_D): *p+= (i2){ 0,-1}; break;
}}

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
		init_ship();
		
	

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
			i2* p= &ships[0].p;
				case KEY_UP   : act(ACT_U); break;
				case KEY_LEFT : act(ACT_L); break;
				case KEY_RIGHT: act(ACT_R); break;
				case KEY_DOWN : act(ACT_D); break;
			default:
			#ifdef DBG_KBD
			//seq dbg
				// mvprintw(0, 0, "ch= %d 0x%x", ch, ch);
				// struct timespec sl2= {0,200000000};
				// nanosleep(&sl2,0);
			#endif
				break;
			// case 27://ESC
			// 	goto exit;

			// default: break;
			}
		}

		{
			i2 pad_wh= {7,7};
			i2 pad_o= sdim-pad_wh-3;
			wch* l[7]= {
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
				
				if(in_k=='u') act(ACT_U);//allow multiple
				if(in_k=='l') act(ACT_L);
				if(in_k=='r') act(ACT_R);
				if(in_k=='d') act(ACT_D);
			}
		}

		//entities
		ea(s,ship){
			draw(s->p,&s->s);
		}
		
		refresh();

		//net
		// qnd, quantum nondeterminism
		// clients torrent stochastic updates to stochastic recipients
		// hacking false updates is game balanced via trust scalar
		//   trusted clients may choose to expend trust
		// gateway is a subdir-mounted ftp

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
