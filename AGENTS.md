# A

## Index

- Rules: `~/.codex/AGENTS.md`; repo exceptions: repo `AGENTS.md`.
- Skills: `/workspace/agent-state/skills/README.md`; todo: repo `docs/todo.txt`.
- Memory: `~/.optmem/memo`; shared notes: `/workspace/agent-state/notes/`.

A is the glyph of a ship. `src/`: game `client.nim`/`sync.nim`, network core
`p2p.nim`; transport/policy external. `tests/` checks; `docs/` design/todo;
`llm/` project notes. Shared skills/personal notes: `/workspace/agent-state`.

Keep compact data-oriented layout and aligned columns. For important code,
visual anneal: render, revise ~3–20 lines, render again; widen if needed, revisit
whole file. Do not impose uniform compression or extract trivial wrappers.
Use nimsuggest for Nim outlines/references when useful: VM copy
`/workspace/toolchains/nim-2.4.0/bin/nimsuggest`; use rg for simple searches.

Docs: human-readable, topical tree notation, descending priority; types and
algorithms under architecture. Keep generated builds/captures and uploaded
references out of Git. Todo: `docs/todo.txt`; active view via
`/workspace/agent-state/tools/todo.nim`; `llm/todo.txt` points there. Follow
shared `skills/todo` and `skills/do`. Order = priority, not dependency. Continue
independent work around blockers; honor explicit sequencing and fallback.
Standalone `defer>>>` / `Deferred>>>` defers every later line regardless of
heading or indentation; explicit deferred entries before marker also deferred.
No deferred research/planning/implementation until user reopens or authorizes
fallback. Authentication, gateway login, credentials and peer identity deferred.
Concise todos: no redundant implement prefix; remove verified completions and
move durable facts to docs. Checkpoint before large refactors; commit reviewed
segments. Codex author/committer: Codex <codex@users.noreply.github.com>.

LF text. User uses fish, including Termux: give fish commands unless requested
otherwise. Hacks: assume works on user machine; do not formalize shortcuts;
note attainable proper fix/PR as todo, respecting defer. Preserve purposeful
alignment, including matrix-adjacent comments. Compact locals: v number-like,
x scalar, i integer, s symbol when clear. Learn preferences from user diffs.

Comment tags: `#!!` uncommitted hack; `#?`/`#????` confusion, explain line;
`#todo` unimplemented block; `#fixme` unintended or broken behavior.
Preserve quotes verbatim. Shared vacations/dreams: `skills/vacation`,
`skills/dream`; use increased allowance. Project-specific exceptions stay here;
reusable skills and personal notes route to shared repo. Prefer VM-local rules
for personal preferences; user instructions win.
