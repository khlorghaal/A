# A

A is the glyph of a ship. Keep columns aligned and preserve the compact, data-oriented notation.

For important code, use visual annealing: render, locate an awkward region of about 3–20 lines, revise in text, and render again. Widen the scope when local edits do not settle; revisit the whole file. Visual structure participates in reasoning. Do not impose uniform compression or extract helpers automatically.

Sources are in src/. The game uses src/client.nim and src/sync.nim; src/p2p.nim provides the network core. Transport and policy hooks remain external. src/net.nim is design pseudocode. See llm/ for design and visual reference notes. Keep uploaded reference images and generated builds or captures out of Git.

Use visual-review iterations in proportion to the remaining token budget; reserve enough for tests, fixes, and reporting. See llm/style.md for observations from doot.
