flags = -Wno-parentheses -Wno-ambiguous-reversed-operator -Wno-string-compare\
 -Werror=return-stack-address -Werror=uninitialized -Werror=shift-negative-value\
 -I"./deps/" -L"./deps"\
 -ferror-limit=4 -fcaret-diagnostics-max-lines=4\
 -fsanitize=shift -fsanitize=address
flags_rls:= -O3 -gmlt
flags_dbg:= -O1 -ggdb3

a:
	clang a.c -o a $(flags) \
	 --std=c23 -lncurses 
	chmod +x a
	./a
