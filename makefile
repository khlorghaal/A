flags = -Wno-parentheses -Wno-ambiguous-reversed-operator -Wno-string-compare\
 -Werror=return-stack-address -Werror=uninitialized -Werror=shift-negative-value\
 -I"./deps/" -L"./deps"\
 -ferror-limit=4 -fcaret-diagnostics-max-lines=4\
 -fsanitize=shift 
 #-fsanitize=address
flags_rls:= -O3 -gmlt
flags_dbg:= -O1 -g3

.PRECIOUS: A
.PHONY: A

A: a.c
	clang a.c -o A $(flags) $(flags_dbg)\
	 --std=c23 -lncursesw
	chmod +x A
	#gdb -q ./A -x ./gdb.cfg -ex run
	./A
