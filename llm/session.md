Current session
├─ queue: docs/todo.txt; plain indented text with a defer>>> remainder
│  ├─ all later lines deferred, even headings and unindented items
│  ├─ explicitly deferred entries above the boundary also excluded
│  └─ removed old duplicate queue from llm/todo.txt
├─ local skills: .agents/skills/{todo,do}/SKILL.md
│  └─ cloud skill sources have no write tool; project overrides live here
├─ commits: coherent checkpoints before large changes; verified segments afterward
├─ verified toolchain: Nim 2.4, Clang 19, Futhark 0.16 under /workspace/toolchains
├─ game fix: bind allocated pointer before assignment to avoid double allocation
├─ tests: Nim four-PTY harness; terminal image capture separate in llm/terminal
└─ open: owner echoes dilute eight inputs to ~5.34/4.32 cells; trust/game integration
├─ hash_t is uint32; integer hash port committed and verified
├─ Nim map port remains a draft; preserve unbounded Monte Carlo allocation
│  └─ no growth cap or collision cutoff; expansion padding is part of the design
└─ next active work: map port, gateway, databases, Unicode identity, owner control
