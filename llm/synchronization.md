# Typed state synchronization

Ship.p is sync_v2 and Ship.trigger is sync_b. sync_f marks a scalar float. Generic fieldPairs traversal derives encoding and reconciliation from field types; ordinary fields stay local. sync_v2 is a float32 tuple, so another tuple of the same shape also counts as this type. No per-entity serializer or registration macro is required.

The ownership table is Sync.owners: entity UID → peer ID. This table is local session state, never inferred from position packets. An owner receives +0.5 effective trust for its entity. Negative effective trust is clamped to zero; nonfinite trust is ignored. The shared seven-ship demonstration assigns initial ownership to peer 1. A_PEER_ID selects this process's peer ID (default 1). Entity creation and ownership transfer still require a session-level protocol; receiving state does not create unknown entities.

Each active peer has one latest report per known entity. Reconciliation computes their trust-weighted mean, then applies an exponential time step. With incoming trust sum W, local effective trust L, and response rate k:

    alpha = 1 - exp(-k*W*dt/(1 + L))

The local owner's bonus supplies resistance as well as increasing its influence when another peer receives it. Default k is 8/s; reports expire after 2 seconds without a newer revision. dt is elapsed local monotonic time in seconds, not packet count or remote wall-clock time. All peers continue simulation. The camera retains fractional position until final rasterization.

sync_b is persistent boolean state with hidden confidence. Local writes use set(); reads use .value. Received true/false values pull confidence toward 1/0 by the same time/trust rule. It turns true at 0.6 and false at 0.4. This hysteresis is a provisional choice: it does not deliver one-shot events, and brief pulses may be missed. The Fire action currently toggles the trigger flag.

publish refreshes the kind's persistent outgoing row. Each datum includes the complete 128-bit entity ID and only synchronized fields, using little-endian encoding. The 64-bit transport key is checked for collision against the full ID. Receivers reject stale revisions independently for each sender/entity, malformed records, nonfinite floats and unknown entities. Expired reports retain revision watermarks so replay cannot renew their influence. Kind IDs and field schemas must agree across peers; a field-order/schema migration is not negotiated yet.

The game drains P2P input when transport callbacks have been bound, simulates, reconciles, and publishes each frame. Socket transport, authentication and discovery remain the existing external P2P hooks; this change does not silently invent a UDP protocol. The in-memory two-peer test exercises actual p2p.tick transmission and receipt, ownership weights, step-size equivalence, duplicate/replay rejection, expiry, boolean switching and preservation of unsynchronized fields. make test runs it alongside the game checks.

Current cost is a scan of cached reports per entity, plus decoding. This is an initial integration for the small scene; index reports by entity and bound session membership before scaling up.
