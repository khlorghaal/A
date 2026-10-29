Current session
├─ queue: docs/todo.txt; active view via llm/todo.nim
│  └─ defer>>> / Deferred>>> defers every following line, regardless of indentation
├─ workflow: .agents/skills/{todo,do}/SKILL.md; completed details go into docs
│  ├─ coherent checkpoints before large changes; reviewed segments afterward
│  └─ Codex commits use Codex <codex@users.noreply.github.com>
├─ toolchain: Nim 2.4, Clang 19, Futhark 0.16 under /workspace/toolchains
│  └─ GLib runtime provides NFC normalization
├─ code
│  ├─ bind allocated ship pointer before assignment to avoid double allocation
│  ├─ doot integer hashes return uint32
│  ├─ Nim hmap preserves unbounded Monte Carlo expansion and padding
│  └─ trust-store IDs use NFC; duplicate normalized file entries fail loading
├─ last verification, before cleanup: make test, make check, make multi_agentvm passed
│  └─ cleanup pass: source/diff review only; user requested no tests
└─ open work (details remain in docs/todo.txt)
   ├─ gateway, authenticated peer mapping, isolated databases and trust/game integration
   ├─ NFC enforcement in future gateway and authenticated peer identities
   └─ owner-control measurements and requested +.3 credibility rule
      └─ eight inputs settle near 5.3/4.3 cells in current four-client scenarios
