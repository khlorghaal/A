# Terminal inspection

The earlier port was exercised through a PTY. Rebuild after changes before drawing conclusions from earlier captures.

The controller in tools/vterm.py uses a PTY, pyte and Pillow to capture terminal cells. Install tools/requirements-inspection.txt, build the game, and start it with a tool PTY:

```sh
python3 tools/vterm.py --width 100 --height 36
```

It accepts newline-delimited JSON commands for start, key, mouse, resize, capture and stop. Captures are reconstructions, so check the raw terminal stream when Unicode shaping or terminal behavior is in doubt. Generated captures belong under ignored build/.
