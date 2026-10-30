# DOOT: source-grounded architectural notes for Codex

Source: https://github.com/khlorghaal/doot/tree/master (master; inspected README.md, doot.hpp, defs.hpp, primitives.hpp, arr.hpp, list.hpp, idheap.hpp, ptrs.hpp, thread.hpp, buffer.hpp, lut.hpp).

DOOT = Data Oriented Orthodox Template Library. Not a conventional utility library: it attempts to replace the C++ standard-library-centered idiom with small data transformations and explicit memory/lifetime rules. Read the README as a design specification, but compare every declaration against implementation; code is experimental and contains unfinished parts.

## Most interesting ideas

1. **Ownership versus views:** `arr<T>` is only a typed interval (`base,stop`) with no allocation ownership; `list<T>` adds capacity and ownership. This distinction is intentional and underlies APIs that accept arrays without entangling allocation policies.
2. **Relocation as a design axiom:** storage uses raw realloc/memcpy; elements are expected to tolerate bitwise relocation and pointer invalidation. The README forbids escaping container-element pointers beyond local operations and restricts memory transfers. This deliberately exchanges general C++ object semantics for simpler, contiguous representations. Preserve the invariant before editing algorithms.
3. **Persistent identity decoupled from moving storage:** `idheap<T>` implements `id -> dense index -> T`, with aligned `heap` and `ids` arrays and an `id -> index` map; removals swap the final element into gaps. `index_recycler` supplies compact recycled IDs; `bag<T>` combines the mechanisms. `idpt<T>` resolves a persistent ID through the owning heap rather than retaining an unstable address. This is DOOT's ECS-oriented centerpiece.
4. **Distinct layers of absence:** `maybe<T>` holds an optional reference/pointer; `maybe_i<T>` uses a sentinel value; `maybe_v<T>` stores a value and presence flag. The representations track different data-layout and lookup costs, not just API aesthetics.
5. **Constrained concurrency model:** README and `thread.hpp` describe fixed thread topology, warp dispatch of array segments, thread-local variable-length output lists, collection after joining, immutable warp scope during execution, and explicit transfer of ownership for inter-warp messages. The desired concurrency safety is architectural rather than dependent on arbitrary user-visible locks.
6. **Type-preserving interface, opaque implementation:** `OPAQ_OBJ`, `OPAQ_XTRN_OBJ`, and related macros mediate narrow objects whose implementation and dependencies stay in source files; warp dispatch similarly adapts typed callbacks through `void*` plumbing. The goal is minimal includes and compilation units, not generic object hierarchies.
7. **Syntax as a small alternate language:** `defs.hpp` compresses C++ syntax (`tplt`, `cre`, `re`, `op`), while `doot.hpp` defines iteration and optional-value control macros (`each`, `en`, `zip`, `may_if`, `may_re`, `let`). These are intended as a visually economical DSL; do not automatically translate them into STL/ranges or verbose templates.
8. **Explicit semantic constraints:** allocations should match frees within one scope; methods should mutate only `this` and explicit reference parameters; behavioral inputs should remain explicit. This is an attempt to make dataflow legible by local inspection.
9. **Predictable fixed representations:** `fixedarr`, `dynarr`, `ringbuffer`, compact numerical aliases, nanosecond-based times, and interpolating LUTs show a preference for predictable representation and direct access.
10. **An unusually personal lexical philosophy:** terms `add/sub/make/kill`, suffix `n't`, and humorous macro aliases are intentional authorial choices. They aren't necessarily desirable in a general library, but reflect DOOT's treatment of syntax as part of the model of computation.

## Caveats worth investigating before modernization

- `list<T>` performs raw realloc and has explicit copy/move constructors despite README's blanket prohibition; determine the precise safe subset. Check destruction, `pop`, `sub_idx`, and realloc shrink behavior for nontrivial T.
- `idheap<T>` recycles numeric IDs without visible generation counters. Check stale `idpt` aliasing after reuse, and verify map/heap invariants after removing last and non-last entries.
- `list<T>::insert` is explicitly unimplemented (`ass(false)`); other files include apparent draft fragments (e.g. `lut.hpp`). Do not presume the tree builds cleanly.
- `thread.hpp` sets `WARP_NO_MULTITHREAD=true`, so distinguish planned warp semantics from verified concurrent behavior.
- `buffer.hpp` documents overwrite-on-new-push; inspect ownership and locking before using it as a reliable thread primitive.
- Raw `rcas` and bytewise copy could breach strict aliasing or object-lifetime rules; assess target compiler constraints rather than silently imposing generic STL semantics.

## Guidance

First characterize the author's invariants and the interaction between them. Preserve its distinctive dense data-model architecture. Prefer surgical correctness fixes, small compile/test fixtures, and explicit empirical benchmarks over aesthetic normalization. For important code, respect visual composition as a mechanism of reasoning; try local visual annealing rather than mechanical formatting.
