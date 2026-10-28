# Nim port

Sources are in src/. The game uses client.nim for terminal rendering and GUI, and sync.nim with the P2P core for state synchronization. Socket transport and policy hooks remain external and unbound. net.nim is design pseudocode. The original C game remains in Git history.

Initialize the deps/termbox2 submodule and install the Nimble, C and Clang dependencies before building. Run `make`, `make check`, `make test`, or `make run`. The game follows the local ship with a simple position offset.

Futhark generates terminal bindings from deps/termbox.h. After changing a header, regenerate its cached imports, for example with `make NIMFLAGS=-d:opirRebuild`.
