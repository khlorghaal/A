# Style observations from doot

Source: https://github.com/khlorghaal/doot/tree/master (2d.hpp, arr.hpp, doot.hpp, hmap.hpp, quem.hpp, thread.impl.hpp and README). These are observations, not rules to copy mechanically into Nim.

Code is arranged around data and transformations. State, ownership, allocation and mutation are visible; resource acquisition, operation and release often stay in the same small continuous block. Helpers and abstraction earn their place by clarifying a real relationship. The README explicitly favors minimal headers, explicit behavioral parameters and scoped ownership.

Notation is compact and often deliberately coined: short names, dense local expressions, direct conditionals, small wrappers and custom vocabulary. Related declarations and expressions align in columns; whitespace and vertical spacing group phases. Repeated operations can remain adjacent where their similarity is meaningful. Terseness is a means of making the structure apprehensible, not a reason to obscure an invariant.

Comments frequently use lowercase, fragments and contractions; they sit beside or just before the relevant operation. They record ownership, invariants, assumptions, risks and rationale, including candid uncertainty. Humor, irreverence and occasional profanity coexist with serious technical judgment. Do not imitate personality as ornament or regularize the author's voice. Distinguish exploratory notes from verified facts.

My reading: the code seeks a small, personally coherent language for direct thought, with spatial form carrying relationships alongside semantics. Preserve its visible continuity when refining it. Do not mistake unusual spelling or a terse name for a defect by itself; investigate behavior and context. Avoid importing all of doot's C++ conventions wholesale into Nim.
