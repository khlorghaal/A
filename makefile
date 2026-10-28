.PHONY: all run check test clean

all: build/A

build/A: a.nimble src/a.nim src/client.nim src/sync.nim src/p2p.nim deps/termbox.c deps/termbox.h deps/termbox2/termbox2.h
	mkdir -p build
	nim c $(NIMFLAGS) --out:$@ src/a.nim

run: build/A
	./build/A

check: build/A
	nim check src/p2p.nim
	nim check src/sync.nim

test:
	mkdir -p build
	nim c $(NIMFLAGS) -d:aTests --out:build/game-checks -r src/a.nim
	nim c $(NIMFLAGS) --out:build/sync-checks -r tests/sync_checks.nim

clean:
	rm -rf build
