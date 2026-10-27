# Terra handoff

The game is built but has NOT been launched or visually inspected. Three local commits are requested; do not push or open a PR yet.

The Nim port passed `make check`, `make test` and `make`. No terminal was initialized during the game checks. Compiler: Nim 1.6.14, GCC 13.3. This older Nim compiler emits C const/noreturn warnings; the build and assertions succeed.

## Inspecting after the model switch

A PTY controller is ready in a live tool terminal. Its session ID is recorded below. Use `write_stdin` to send JSON commands, each followed by a newline. If that session has expired, start another:

```sh
cd /workspace/scratch/8e756e99e038/A
python3 tools/vterm.py --width 100 --height 36
```

Run this with a tool PTY (`tty: true`). It prints `game_started: false` and waits. After the user switches to Terra:

```json
{"action":"start"}
{"action":"capture","name":"initial"}
{"action":"key","key":"Up"}
{"action":"capture","name":"after-up"}
{"action":"resize","width":60,"height":22}
{"action":"capture","name":"smaller"}
{"action":"key","key":"Escape"}
{"action":"stop"}
```

Send one command at a time. Allow at least a frame interval (25ms) before capture. Open the returned PNG with the image viewer. Captures include a reconstructed PNG, plain terminal text and the cumulative raw ANSI stream. Mouse commands use zero-based cell coordinates: `{"action":"mouse","x":85,"y":22}` sends a left click at that cell.

The controller uses a real PTY with a controlling terminal and `TERM=xterm-256color`, feeds output through pyte, and renders terminal cells with DejaVu Sans Mono. It avoids tmux because this container rejects its socket connection. PNGs are terminal-cell reconstructions, not GUI screenshots: font fallback, cursor, shaping and some terminal modes may differ. Validate actual Unicode and color behavior against the raw stream when ambiguous.

Inspect normal and small viewports (including one shorter than the pad), resizing, arrow input, pad hit regions and exit cleanup. RNG seed is deterministic; frame counts at the time of input/capture vary.

Potential inherited artifacts: ship foreground equals background (`0xeeeeee`), and positive Y for `actU` moves down on screen. Preserve the C baseline until inspecting and deciding the correction. Pad drawing was completed from C's truncated/bounds-unsafe array; inspect all 13 rows. See nim-port.md for deliberate deviations.

## Recreating the build

Install Nim, a C compiler, Python 3, DejaVu Sans Mono and `tools/requirements-inspection.txt`. Initialize the termbox2 submodule, then run `make check test all`.

In this container, the compiler was unpacked into scratch because the system package cache is unwritable:

```sh
export PATH=/workspace/scratch/8e756e99e038/toolchain/bin:$PATH
make check test all
```

The scratch-only toolchain is not tracked. `A_FONT` overrides the capture font path. All binaries and captures go under ignored `build/`.

Prepared tool terminal session: `56022` (100×36), waiting for JSON; game not started. Recreate it with the command above if the session is unavailable. A synthetic arrow/box-drawing/24-bit-color sample passed the renderer check; this does not establish that the game renders correctly.
