# Terminal inspection

The earlier port was exercised through a PTY. Rebuild after changes before drawing conclusions from earlier captures.

The controller in llm/terminal/vterm.py uses a PTY, pyte and Pillow to capture terminal cells. Install llm/terminal/requirements.txt, build the game, and start it with a tool PTY:

```sh
python3 llm/terminal/vterm.py --width 100 --height 36
```

It accepts newline-delimited JSON commands for start, key, mouse, resize, capture and stop. Captures are reconstructions, so check the raw terminal stream when Unicode shaping or terminal behavior is in doubt. Generated captures belong under ignored build/.

Four-client network inspection: `make multi_agentvm` builds a test-only game and Nim gateway, then runs four PTYs through tests/multi_terminal.nim. The gateway uses loopback UDP solely to couple processes; tests/sim_socket.nim schedules simulated delay, jitter and loss. Test builds disable random drift, accept A_TEST_VX for a constant-velocity fixture, and write atomic position snapshots under build/multi. Normal game builds are unaffected. The harness checks movement propagation, convergence, clean Escape exits and supervisor cleanup after a client crash. Raw terminal output is under build/multi; use the separate inspection tool for rendered captures.

Source annealing: rendered all runtime src/*.nim files and the makefile, reviewed
whole-file images, refined local declaration, table and recipe regions, and
rendered the changes again. src/net.nim is design pseudocode and was excluded.
Before/after images are ignored artifacts under build/annealing. This pass ran
no builds or tests at the user's request; verification was visual and diff review.
