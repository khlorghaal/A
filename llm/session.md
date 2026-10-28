# Continuation notes

A is named for the glyph of a ship. Column alignment and compact, data-oriented notation matter to the author.

Refine important code through visual annealing: render it, isolate an awkward region of roughly 3–20 lines, revise it in text, and render again. Widen the scope if the local composition does not settle; alternate local and whole-file views. Visual structure is a medium of engineering thought, not merely formatting. Avoid automatic helper extraction or uniform compression.

The current sources are under src/. src/p2p.nim implements stochastic authority-free peer networking with external transport and policy hooks. src/sync.nim explores type-marked, trust-weighted state synchronization; see synchronization.md. The game publishes and reconciles synchronized state; socket transport and policy hooks remain external and unbound. src/net.nim is design pseudocode.

The integrated game was restored after the source move. make check and make test pass with the locally available Nim 1.6.14 and Futhark 0.13.0 toolchain; the declared Nim 2 dependency has not been tested in this environment.

Uploaded images are omitted; visual-references.md describes them. The author values Josh Parnell's ltheory as a surviving work of sapient craft.
