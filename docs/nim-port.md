# Nim port

`a.nim` ports `a.c`, using the earlier Nim draft supplied in chat. `a.c` is retained as a reference. Network code remains separate in `p2p.nim`.

Build with Nim 1.6.14 or newer, a C compiler, and the pinned termbox2 submodule:

```sh
git submodule update --init
make
make test
make check
make run
```

`make` builds without launching the game. `make test` exercises geometry, movement, allocation limits, RNG and monotonic timing without initializing a terminal.

Preserved: seven initial ships; A glyph; positions, stats and colors; the first ship responds to arrow keys; signed RNG remainders; horizontal random drift; 25ms target frame interval; ESC/Ctrl-C exit; terminal cleanup. The C allocation limit still overwrites the last slot and reports the capacity condition.

Corrections made during port:

- Initialize the process locale for libc Unicode width handling. Explicit 32-bit termbox attributes and event ABI, with one C implementation unit. UTF-8 graphemes are converted to codepoint sequences for `tb_set_cell_ex`.
- Only live ships are visited, rather than the entire fixed allocation.
- RNG arithmetic wraps explicitly; C's signed-overflow behavior was undefined. The shift is arithmetic, matching the original target.
- Monotonic microseconds come from one reading. Frame sleep uses time spent in the current frame rather than the prior frame's sleep interval.
- Pad dimensions derive from its complete 13 rows and terminal columns. The C array declared 16 strings but supplied 26, drew only seven rows, and allowed hit indices outside its row maps. The larger pad in the earlier Nim draft also mixed UTF-8 bytes with terminal columns and indexed beyond its rows. This port keeps the C's smaller design and completes it.
- Absent mouse input uses an off-screen sentinel; resize events no longer stop draining the input queue.
- Truecolor is requested directly. The C fallback chain treated success (zero) as failure, potentially replacing the intended mode with grayscale. Termbox does not detect terminal truecolor support; use a truecolor terminal for inspection.

After visual inspection, Up and Down were corrected to match screen coordinates. Ships use the base background so their A glyphs are visible. After movement, the view offset follows the local ship; its position projects to screen center. The local ship still participates in the existing random drift.
