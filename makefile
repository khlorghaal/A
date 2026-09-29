flags = -Wno-parentheses -Wno-ambiguous-reversed-operator -Wno-string-compare\
 -Werror=return-stack-address -Werror=uninitialized -Werror=shift-negative-value\
 -I"./deps/" -L"./deps"\
 -ferror-limit=4 -fcaret-diagnostics-max-lines=4\
 -fsanitize=shift 
 #-fsanitize=address
flags_rls:= -O3 -gmlt
flags_dbg:= -O1 -g3

.PRECIOUS: A
.PHONY: A colorcount

A: a.c
	clang a.c -o A $(flags) $(flags_dbg)\
	 --std=c23 
	chmod +x A
	#gdb -q ./A -x ./gdb.cfg -ex run
	./A

colorcount:
	printf '%s\n' '#include <stdio.h>' '#include <ncursesw/ncurses.h>' 'int main(){initscr();start_color();printf("%d %d %d\n",COLORS,COLOR_PAIRS,can_change_color());endwin(); return 0;}' | clang -xc - -L$PREFIX/lib -I$PREFIX/include -lncursesw -o x
