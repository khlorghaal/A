.PHONY: run multi multi_agentvm owner_measurements check test clean

ifneq ($(TERMUX_VERSION),)
  override fgs += -d:opirRebuild -d:syspaths=$(PREFIX)/include:$(PREFIX)/lib/clang/latest/include:$(PREFIX)/include/aarch64-linux-android
endif # futhark opir hack

#fgs += flags


run: build/A
	./build/A --db-dir build/client/db

game_sources = a.nimble nim.cfg $(wildcard src/*.nim deps/blastd/src/*.nim) \
               deps/termbox.c deps/termbox.h deps/termbox2/termbox2.h

build/A build/A-multi: $(game_sources)

build/A:
	mkdir -p build
	nim c $(fgs) -o:$@ src/a.nim

# Interactive true-color sample; press a key to exit.
build/test/colors: tests/colors.nim $(game_sources)
	mkdir -p build/test
	nim c $(fgs) -o:$@ tests/colors.nim

# Interactive, two-pane rendering launcher; independent of automated tests.
multi: build/A
	@if [ -n "$$TMUX" ]; then \
		id=$$(tmux new-window -P -F "#{window_id}" -n A-test "A_PEER_ID=1 ./build/A --db-dir build/multi/client1/db") || exit; \
		    tmux set-option   -w -t "$$id" remain-on-exit off; \
		    tmux split-window -h -t "$$id" "A_PEER_ID=2 ./build/A --db-dir build/multi/client2/db" || { \
			tmux kill-window  -t "$$id"; exit 1; \
		}; \
	else \
		tmux new-session      -d -s A-test   "A_PEER_ID=1 ./build/A --db-dir build/multi/client1/db" || exit; \
		tmux set-option       -w -t A-test:0 remain-on-exit off; \
		tmux split-window     -h -t A-test:0 "A_PEER_ID=2 ./build/A --db-dir build/multi/client2/db" || { \
			tmux kill-session    -t A-test; exit 1; \
		}; \
		tmux attach-session -t A-test; \
	fi

check: build/A
	nim check $(fgs) src/p2p.nim
	nim check $(fgs) src/sync.nim

blastd_sources = $(wildcard deps/blastd/src/*.nim deps/blastd/tests/*.nim) \
                 deps/blastd/Makefile deps/blastd/blastd.nimble

build/blastd-testpass: $(blastd_sources)
	mkdir -p build
	$(MAKE) -C deps/blastd test
	touch $@

# Automated checks do not launch the interactive tmux session.
test: build/blastd-testpass
	mkdir -p build
	nim c $(fgs) -o:build/game-checks -d:aTests -r src/a.nim
	nim c $(fgs) -o:build/sync-checks           -r tests/sync_checks.nim
	nim c $(fgs) -o:build/doot-hash-checks      -r tests/doot_hash_checks.nim
	nim c $(fgs) -o:build/hmap-checks           -r tests/hmap_checks.nim
	nim c $(fgs) -o:build/trust-checks          -r tests/trust_checks.nim
	nim c $(fgs) -o:build/trustdb-checks        -r tests/trustdb_checks.nim
	nim c $(fgs) -o:build/trustsync-checks      -r tests/trustsync_checks.nim
	nim c $(fgs) -o:build/gateway-frames-checks -r tests/gateway_frames_checks.nim
	nim c $(fgs) -o:build/gateway-snapshot-checks -r tests/gateway_snapshot_checks.nim
	nim c $(fgs) -o:build/gateway-checks          -r tests/gateway_checks.nim

clean:
	rm -rf build

# Four real PTYs plus deterministic in-process network checks.
# The relay is test-only, not the future identity gateway.
multi_agentvm: build/A-multi build/gateway/relay
	nim c $(fgs) -o:build/multi-checks   -r tests/multi_checks.nim
	nim c $(fgs) -o:build/multi-terminal -r tests/multi_terminal.nim

# Deterministic measurements; values are reported rather than locked as targets.
owner_measurements:
	mkdir -p build
	nim c $(fgs) -o:build/owner-measurements -r tests/owner_measurements.nim

build/A-multi: tests/socket_gateway.nim tests/sim_socket.nim
	mkdir -p build
	nim c $(fgs) -d:simSockets -o:$@ src/a.nim

build/gateway/relay: nim.cfg tests/socket_gateway.nim tests/sim_socket.nim src/p2p.nim $(wildcard deps/blastd/src/*.nim)
	@if [ -f build/gateway ]; then mv build/gateway build/gateway.previous; fi
	mkdir -p build/gateway
	nim c $(fgs) -o:$@ tests/socket_gateway.nim
