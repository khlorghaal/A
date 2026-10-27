NIM ?= nim
NIMFLAGS ?= --nimcache:build/nimcache

.PHONY: all run check test clean c-run colorcount
all: build/A

build/A: a.nimble a.nim client.nim sync.nim p2p.nim deps/termbox.c deps/termbox.h deps/termbox2/termbox2.h
	mkdir -p build
	$(NIM) c $(NIMFLAGS) --out:$@ a.nim

run: build/A
	./build/A

check: build/A
	$(NIM) check $(NIMFLAGS) p2p.nim
	$(NIM) check $(NIMFLAGS) sync.nim

test:
	mkdir -p build
	$(NIM) c $(NIMFLAGS) -d:aTests --out:build/game-checks -r a.nim
	$(NIM) c $(NIMFLAGS) --path:. --out:build/sync-checks -r tests/sync_checks.nim

# Keep the original C implementation available for comparison.
# It has pre-existing Clang extensions and excess pad initializers.
c-run:
	mkdir -p build
	clang -std=c2x -O1 -g a.c -o build/A-c
	./build/A-c

clean:
	rm -rf build
