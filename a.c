#include <ncurses.h>
#include <time.h>
#include <stdint.h>
#include <stdlib.h>

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
typedef uint64_t u64;
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

i2 p= {10,10};

static void draw(i2 p, char c){
	mvaddch(p.y,p.x,c);
}

static void update(i2* p){
	int ch=getch();

	if(ch==3){
		endwin();
		exit(0);
	}

	i2 d=(i2){0,0};
	
	(*p)+= d;
}

int main(void){
	initscr();
	noecho();
	cbreak();
	timeout(0);
	mousemask(ALL_MOUSE_EVENTS,NULL);
	start_color();

	//palette
	init_pair(1, COLOR_WHITE, COLOR_BLACK);

	//timing
	const u64 tdt= 16*msec;//target dt
	t0= now_us();//init
	u64 t = 0;//most recent
	u64 tp= 0;//previous
	while(1){
		getmaxyx(stdscr,sdim.y,sdim.x);
		clear();
		wbkgd(stdscr, COLOR_PAIR(1)|'.');//fill
		
		//input
		i2 in_p= {0,0};
		
		int   ch= getch();
		while(ch=!ERR){
			int ch= getch();
			switch(ch){
			case KEY_MOUSE:
				MEVENT m;
				if(getmouse(&m)!=OK)
					break;
				in_p= (i2){m.x,m.y};
				break;

			case 27://ESC
				goto exit;
			}
		}

		{
			i2 pad_wh= {7,7};
			i2 pad_o= sdim-pad_wh;
			if(!isbound( in_p,pad_o,pad_o+pad_wh ))
				break;
			i2 dp= in_p-pad_o;

			mvaddstr( pad_o.y,pad_o.x,
				"  ┌─┐  \n"
				"  │↑│  \n"
				"┌─┼─┼─┐\n"
				"│←│ │→│\n"
				"└─┼─┼─┘\n"
				"  │↓│  \n"
				"  └─┘    ");
			char kmap_dpad[7][7]= {
				"  uuu  ",
				"  uuu  ",
				"ll   rr",
				"ll   rr",
				"ll   rr",
				"  ddd  ",
				"  ddd  "};
			char in_k= kmap_dpad[dp.y][dp.x];
			if(in_k=='u') dp+= (i2){ 0, 1};
			if(in_k=='l') dp+= (i2){-1, 0};
			if(in_k=='r') dp+= (i2){ 1, 0};
			if(in_k=='d') dp+= (i2){0,-1};
			
			#undef l
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
		u64 ddt= (tdt)-(t-tp);
		if(ddt>1){
			struct timespec sl={0,ddt*1000};
			nanosleep(&sl,NULL);
		}else{//lag
			;
		}
	}

exit:
	endwin();
	re 0;
}
