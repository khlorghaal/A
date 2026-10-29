# Build flags apply to every compiled target.
NIMFLAGS ?=

.PHONY: run multi multi_agentvm check test clean

run: build/A
	./build/A

game_sources = a.nimble nim.cfg $(wildcard src/*.nim) \
               deps/termbox.c deps/termbox.h deps/termbox2/termbox2.h

build/A build/A-multi: $(game_sources)

build/A:
	mkdir -p build
	nim c $(NIMFLAGS) -o:$@ src/a.nim

# Interactive, two-pane rendering launcher; independent of automated tests.
multi: build/A
	@if [ -n "$$TMUX" ]; then \
		id=$$(tmux new-window -P -F "#{window_id}" -n A-test "A_PEER_ID=1 ./build/A") || exit; \
		tmux set-option -w -t "$$id" remain-on-exit off; \
		tmux split-window -h -t "$$id" "A_PEER_ID=2 ./build/A" || { \
			tmux kill-window -t "$$id"; exit 1; \
		}; \
	else \
		tmux new-session -d -s A-test "A_PEER_ID=1 ./build/A" || exit; \
		tmux set-option -w -t A-test:0 remain-on-exit off; \
		tmux split-window -h -t A-test:0 "A_PEER_ID=2 ./build/A" || { \
			tmux kill-session -t A-test; exit 1; \
		}; \
		tmux attach-session -t A-test; \
	fi

check: build/A
	nim check src/p2p.nim
	nim check src/sync.nim

# Automated checks do not launch the interactive tmux session.
test:
	mkdir -p build
	nim c $(NIMFLAGS) -d:aTests -o:build/game-checks -r src/a.nim
	nim c $(NIMFLAGS) -o:build/sync-checks -r tests/sync_checks.nim
	nim c $(NIMFLAGS) -o:build/doot-hash-checks -r tests/doot_hash_checks.nim
	nim c $(NIMFLAGS) -o:build/hmap-checks -r tests/hmap_checks.nim
	nim c $(NIMFLAGS) -o:build/trust-checks -r tests/trust_checks.nim
	nim c $(NIMFLAGS) -o:build/trustdb-checks -r tests/trustdb_checks.nim
	nim c $(NIMFLAGS) -o:build/trustsync-checks -r tests/trustsync_checks.nim

clean:
	rm -rf build

# Four real PTYs plus deterministic in-process network checks.
# build/gateway is a test relay, not the future identity gateway.
multi_agentvm: build/A-multi build/gateway
	nim c $(NIMFLAGS) -o:build/multi-checks -r tests/multi_checks.nim
	nim c $(NIMFLAGS) -o:build/multi-terminal -r tests/multi_terminal.nim

build/A-multi: tests/socket_gateway.nim tests/sim_socket.nim
	mkdir -p build
	nim c $(NIMFLAGS) -d:simSockets -o:$@ src/a.nim

build/gateway: nim.cfg tests/socket_gateway.nim tests/sim_socket.nim src/p2p.nim
	mkdir -p build
	nim c $(NIMFLAGS) -o:$@ tests/socket_gateway.nim
