# A

A is the glyph of a ship. Keep columns aligned and preserve the compact, data-oriented notation.

For important code, use visual annealing: render, locate an awkward region of about 3–20 lines, revise in text, and render again. Widen the scope when local edits do not settle; revisit the whole file. Visual structure participates in reasoning. Do not impose uniform compression or extract helpers automatically.

Sources are in src/. The game uses src/client.nim and src/sync.nim; src/p2p.nim provides the network core. Transport and policy hooks remain external. src/net.nim is design pseudocode.

Use llm/ as the agent workspace: choose formats freely for notes, thoughts, and experiments. Personal musings, including unrelated ones, and eccentricity are welcome. Keep project work aligned with A and maintain its quality.

Keep docs/ human-readable, presentable, and organized by topic (for example, network.txt, gameplay.txt, architecture.txt). Write entries in tree notation, sorted by descending priority. Put types and algorithms under architecture. Keep uploaded reference images and generated builds or captures out of Git.

Use visual-review iterations in proportion to the remaining token budget; reserve enough for tests, fixes, and reporting. See llm/style.md for observations from doot.

Todo workflow: docs/todo.txt is authoritative; llm/todo.txt is only a pointer.
Follow .agents/skills/todo/SKILL.md and .agents/skills/do/SKILL.md for local
refinements to the cloud skills. A standalone defer>>> or Deferred>>> marker
(case-insensitive) defers every subsequent line, regardless of headings or
indentation. Do not execute explicitly deferred entries above the marker either.
Use concise task phrases without redundant "implement" prefixes. Remove verified
completed entries and move enduring details into docs when warranted. Commit
reviewed checkpoints before large refactors and changes, and completed segments
with their relevant verification.
