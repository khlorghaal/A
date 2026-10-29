.PHONY: all run multi multi_agentvm check test clean

all: build/A

build/A build/A-multi: a.nimble nim.cfg src/a.nim src/client.nim src/sync.nim src/p2p.nim deps/termbox.c deps/termbox.h deps/termbox2/termbox2.h

build/A:
	mkdir -p build
	nim c $(NIMFLAGS) --out:$@ src/a.nim

run: build/A
	./build/A

multi: build/A
	@if [ -n "$$TMUX" ]; then \
		id=$$(tmux new-window -P -F "#{window_id}" -n A-test "A_PEER_ID=1 ./build/A") || exit; \
		tmux set-option -w -t "$$id" remain-on-exit off; \
		tmux split-window -h -t "$$id" "A_PEER_ID=2 ./build/A" || { tmux kill-window -t "$$id"; exit 1; }; \
	else \
		tmux new-session -d -s A-test "A_PEER_ID=1 ./build/A" || exit; \
		tmux set-option -w -t A-test:0 remain-on-exit off; \
		tmux split-window -h -t A-test:0 "A_PEER_ID=2 ./build/A" || { tmux kill-session -t A-test; exit 1; }; \
		tmux attach-session -t A-test; \
	fi

check: build/A
	nim check src/p2p.nim
	nim check src/sync.nim

test:
	mkdir -p build
	nim c $(NIMFLAGS) -d:aTests --out:build/game-checks -r src/a.nim
	nim c $(NIMFLAGS) --out:build/sync-checks -r tests/sync_checks.nim
	nim c $(NIMFLAGS) --out:build/trust-checks -r tests/trust_checks.nim
	nim c $(NIMFLAGS) --out:build/trustdb-checks -r tests/trustdb_checks.nim
	nim c $(NIMFLAGS) --out:build/trustsync-checks -r tests/trustsync_checks.nim

clean:
	rm -rf build

multi_agentvm: build/A-multi build/gateway
	nim c $(NIMFLAGS) --out:build/multi-checks -r tests/multi_checks.nim
	nim c $(NIMFLAGS) --out:build/multi-terminal -r tests/multi_terminal.nim

build/A-multi: tests/socket_gateway.nim tests/sim_socket.nim
	mkdir -p build
	nim c $(NIMFLAGS) -d:simSockets --out:$@ src/a.nim

build/gateway: tests/socket_gateway.nim tests/sim_socket.nim src/p2p.nim
	mkdir -p build
	nim c $(NIMFLAGS) --out:$@ tests/socket_gateway.nim
