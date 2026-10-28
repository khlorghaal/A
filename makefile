.PHONY: all run check test clean c-run colorcount

all: build/A

build/A: a.nimble a.nim client.nim sync.nim p2p.nim deps/termbox.c deps/termbox.h deps/termbox2/termbox2.h
	mkdir -p build
	nim c $(NIMFLAGS) --out:$@ a.nim

run: build/A
	./build/A

check: build/A
	nim check p2p.nim
	nim check sync.nim

test:
	mkdir -p build
	nim c -d:aTests --out:build/game-checks -r a.nim
	nim c --path:. --out:build/sync-checks -r tests/sync_checks.nim

clean:
	rm -rf build
