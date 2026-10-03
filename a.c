#include <limits.h>
#define TB_IMPL 1
#define TB_OPT_ATTR_W 32
#define TB_OPT_LIBC_WCHAR
#define TB_OPT_EGC 1 /*unicode*/
#include "deps/termbox2/termbox2.h"
#include <time.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdint.h>
#include <locale.h>
#include <stddef.h>
#include <stdio.h>

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
typedef   size_t siz;
typedef u32 rgb;
typedef struct{
	wch* g;
	siz n;
	rgb fg,bg;
} cell;

inline static bool all(i2 v){ re v.x & v.y; }
inline static bool any(i2 v){ re v.x | v.y; }

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
inline i64 hrng(){
	i64 s= rand_s+17171;
	i64 r=  s*0x5D747531573B1BULL;
	r= (r>>7)^0x73513D1B7117B3ULL;
	rand_s= r;
	rer; }


// #define RGB32
const u64 tdt= 25*msec;//target dt



i2 sdim;//screen dimension
i2 view= {0,0};

cst rgb col_base_fg=0xfafafa;
cst rgb col_base_bg=0x020202;
cst rgb col_dpad_fg=0x111111;
cst rgb col_dpad_bg=0x222222;
cst rgb col_dbg_fg =0x000000;
cst rgb col_dbg_bg =0x00ee00;
cst rgb col_ship_bg=0xeeeeee;

typedef struct{u64 h; u64 l;} uid;
uid genuid(){ re (uid){hrng(),hrng()}; };

char const* dbgp="init";
i64 dbgdur=0;
void bad(char const* s){ dbgp=s; dbgdur=120; }

typedef u64 etyp;
cst etyp etyp_ship= 0b0001;
cst etyp etyp_misl= 0b0010;
cst etyp etyp_figt= 0b0100;
cst etyp etyp_sttn= 0b1000;

//cannot create more units- starcraft style
etyp ccmu_mask= 0;
void ccmu(etyp v){
	ccmu_mask|= v;
	bad("cant more entity"); }

#define E(T,MAX,D) \
  typedef struct D T;\
  cst u64 T##_MAX= MAX;\
  T  T##s[MAX];\
  T* T##s_end= T##s;\
  T* T##s_cap= T##s+MAX;\
  T* aloc_##T(){ \
	  if(T##s_end>=T##s_cap){\
		  ccmu(etyp_##T); T##s_end--; }\
	  re T##s_end++;}\

#define ea(E,T) for(T* E=T##s; E!=T##s_end; E++)

//opt via rearranger phase
E(ship,0xffffe,{
   uid id;
    i2 p;//pos
	 i32 hp;//health
	 i32 cd;//cooldown
	 i32 msl;//missile count
   wch* chr;//display character
   rgb fac;//faction, equal to color
});

void init_ships(){
	ra(i,7){
	  ship* s= aloc_ship();
	  *s= (ship){
            .id = genuid(), .hp = 16, .cd = 0, .msl = 255,
            .chr= L"A", .fac= 0xeeeeee,
            .p = (i2){i * 2 - 8, i % 2 * 3}}; }}
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

static void draw(i2 m, cell c){
	i2 v=m-view+sdim/2;
	tb_set_cell_ex(v.x,v.y, c.g,c.n, c.fg,c.bg);
}

int main(void){
	//init ui
	setlocale(LC_ALL,"");
	if(tb_init())
		re 1;
	sdim=(i2){tb_width(),tb_height()};
	tb_set_input_mode(TB_INPUT_ESC|TB_INPUT_MOUSE);
  if     (tb_set_output_mode(TB_OUTPUT_TRUECOLOR)){}
	else if(tb_set_output_mode(TB_OUTPUT_256      )){}
	else if(tb_set_output_mode(TB_OUTPUT_NORMAL   )){}
	else if(tb_set_output_mode(TB_OUTPUT_GRAYSCALE)){}
	else bad(tb_strerror(tb_last_errno()));
	tb_set_clear_attrs(col_base_fg,col_base_bg);
	tb_hide_cursor();
	tb_clear();
	
	//init entity
	init_ships();
  
	//timing
	t0= now_us();//init
	now= 0;//most recent
	u64 tp= 0;//previous
	//monad
	while(1){
		//input
		i2 mau={0,0};
		//nonblocking
		struct tb_event ev;
		while(!tb_peek_event(&ev,0)){
			if(!(ev.type==TB_EVENT_KEY||ev.type==TB_EVENT_MOUSE))
				break;
			switch(ev.key){
				case TB_KEY_ARROW_UP   : act(ACT_U); break;
				case TB_KEY_ARROW_LEFT : act(ACT_L); break;
				case TB_KEY_ARROW_RIGHT: act(ACT_R); break;
				case TB_KEY_ARROW_DOWN : act(ACT_D); break;
				case TB_KEY_MOUSE_LEFT:
					mau=(i2){ev.x,ev.y};
					break;
				case TB_KEY_CTRL_C:
				case TB_KEY_ESC:
					goto exit;
				default:
					#ifdef DBG_KBD
					//seq dbg
						// mvprintw(0, 0, "ch= %d 0x%x", ch, ch);
					#endif
					break;
			}
		}

		{
			static char const*const l[16*2]= {
				"      ┌─────┐      ","      uuuuuuu      ",
				"      │↑↑↑↑↑│      ","      uuuuuuu      ",
				"      │↑↑↑↑↑│      ","      uuuuuuu      ",
				"      │↑↑↑↑↑│      ","      uuuuuuu      ",
				"┌─────┼─────┼─────┐","llllll uuuuu rrrrrr",
				"│←←←←←│     │→→→→→│","lllllll     rrrrrrr",
				"│←←←←←│     │→→→→→│","lllllll     rrrrrrr",
				"│←←←←←│     │→→→→→│","lllllll     rrrrrrr",
				"└─────┼─────┼─────┘","llllll ddddd rrrrrr",
				"      │↓↓↓↓↓│      ","      ddddddd      ",
				"      │↓↓↓↓↓│      ","      ddddddd      ",
				"      │↓↓↓↓↓│      ","      ddddddd      ",
				"      └─────┘      ","      ddddddd      "};
			const i2 pad_wh= {strlen(l[0]),16};
			const i2 pad_o= sdim-pad_wh-3;

			ra(i,pad_wh.y)
					tb_print(pad_o.x,pad_o.y+i,	col_dpad_fg,col_dpad_bg, l[i*2]);
			
			i2 dp= mau-pad_o;
			if(isbound(dp, 0,pad_wh)){
				char in_k= l[dp.y*2+1][dp.x];
				
				if(in_k=='u') act(ACT_U);//allow multiple
				if(in_k=='l') act(ACT_L);
				if(in_k=='r') act(ACT_R);
				if(in_k=='d') act(ACT_D);
			}
		}

		//entities
		ea(s,ship){
			i2 sv;
			switch(hrng()%5){
				case 0: sv= (i2){ 1,0}; break;
				case 1: sv= (i2){-1,0}; break;
				default:sv= 0;
			}
			s->p+= sv;
			cell c= {.g=s->chr,.n=1,.fg=s->fac,.bg=col_ship_bg};
			draw(s->p,c);
		}
		
		//header
		if(dbgdur-->0){
			tb_print(0,0,col_dbg_fg,col_dbg_bg,dbgp);
		}
		
		//bg draw
		// ra(y,sdim.y) ra(x,sdim.x)
		// 	addch(bgch);
		
		//net
		// qnd, quantum nondeterminism
		// clients torrent stochastic updates to stochastic recipients
		// hacking false updates is game balanced via trust scalar
		//   trusted clients may choose to expend trust
		// gateway is a subdir-mounted ftp
		//
		// jamming and countermeasures cause client to stop emitting packets for veiled entities

		tb_present();//flush
		tb_clear();

		sdim=(i2){tb_width(),tb_height()};

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
	tb_shutdown();
	return 0;
}
