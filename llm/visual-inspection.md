# Terminal inspection

The earlier port was exercised through a PTY. Rebuild after changes before drawing conclusions from earlier captures.

The controller in tools/vterm.py uses a PTY, pyte and Pillow to capture terminal cells. Install tools/requirements-inspection.txt, build the game, and start it with a tool PTY:

```sh
python3 tools/vterm.py --width 100 --height 36
```

It accepts newline-delimited JSON commands for start, key, mouse, resize, capture and stop. Captures are reconstructions, so check the raw terminal stream when Unicode shaping or terminal behavior is in doubt. Generated captures belong under ignored build/.

Four-client network inspection: `make multi_agentvm` builds a test-only game and Nim gateway, then runs four PTYs through tools/multi_agentvm.py. The gateway uses loopback UDP solely to couple processes; tests/sim_socket.nim schedules simulated delay, jitter and loss. Test builds disable random drift and write atomic position snapshots under build/multi. Normal game builds are unaffected. The harness checks movement propagation, convergence, visible ship glyphs, clean Escape exits and supervisor cleanup after a client crash. Captures are under build/multi. Install tools/requirements-inspection.txt first.
