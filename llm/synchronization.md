# Typed state synchronization

Ship.kin is sync_k2: a position p and velocity v in world units per second. sync_v2, sync_f and sync_b still mark ordinary vectors, scalars and persistent boolean state. fieldPairs derives encoding and reconciliation from these types; unmarked fields stay local. sync_v2 is structurally a float32 tuple. Each kinetic pair is explicit, so replication does not guess which position belongs to which velocity.

The game integrates kin.drift(dt). Directional buttons still move one cell per press; they do not predict held input. The demonstration's random drift now sets velocity and integrates elapsed time. There is no acceleration model. Rendering and camera centering use kin.p as a simple offset.

## Time and age

Datum.age is a nonnegative finite estimate of the sample's age at receipt, in seconds. publish creates a fresh sample. Net.tick(dt) ages existing outgoing rows before transmission; pass zero when a row was just published. The game publishes at the end of a frame and calls tick(dt) in the next frame. Transport must add its queue and transit estimate; ordinary remote clocks need not share an epoch. The simulated gateway adds its measured residence time. The loopback adapter also measures carrier and socket-buffer waiting time using the shared OS monotonic clock. That shared clock is a test facility, not an assumption about Internet peers or a production latency estimator.

Replication retains receipt time on its local elapsed clock. On every correction it adds time spent in the report cache, then advances a received kinetic pair by p += v*age. It neither infers intent nor integrates acceleration. Duplicate and reordered revisions do not refresh the cache or its age.

The default horizon is 0.25s. A record containing kinematics is ignored beyond that age, rather than repeatedly pulling toward a frozen projected point. Other records retain the default 2s TTL. Ignoring the whole kinetic record keeps its marked fields together. Local simulation continues with its current velocity when reports expire; no stop or brake is inferred from missing packets. A horizon is therefore an information cutoff, not a guarantee that the last velocity remains correct.

## Trust and correction

Sync.owners maps entity UIDs to peer IDs. It is local session state, never inferred from position packets. ownerBonus defaults to 4, increased from the earlier 0.5; negative effective trust is clamped to zero and nonfinite peer trust is ignored. The demonstration assigns all initial ships to peer 1; A_PEER_ID selects the local peer (default 1).

Each connected sender contributes at most one latest report per entity. Fresh reports, projected to the present, form a trust-weighted target. With incoming trust sum W, local effective trust L, and rate k:

    alpha = 1 - exp(-k*W*dt/(1 + L + W))

Default k is 8/s. The denominator bounds the correction rate as neighbor count or total trust increases. This is not full independence from graph degree: adding genuinely different evidence still changes both target and pull. A local owner resists correction; an incoming owner's observation has greater weight. Finite owner preference mitigates dilution but does not guarantee preservation of all movement. Echoed estimates remain correlated; no provenance consensus or strict ownership authority is claimed.

sync_b stores persistent state with hidden confidence, turning true at 0.6 and false at 0.4. Write with set(), read with .value. It is not reliable one-shot event delivery. Fire toggles this flag. Damage and defender-favoring hit resolution are not implemented; health remains local.

## Transport boundary and checks

Records include a full 128-bit entity ID, a per-publisher revision and the marked fields in little-endian form. Receivers reject malformed data, nonfinite coordinates or ages, negative ages, unknown entities and stale revisions. Expired reports retain their watermarks. The 64-bit transport key is checked against the full ID for collisions. Field layout and the kinetic record format must agree; mixed schemas and restarted publisher epochs are not negotiated.

The normal build leaves transport external. make multi_agentvm builds the test-only loopback adapter and delayed gateway. Tests cover transit and sender-row age, cache aging, stale/malformed packets, constant velocity and abrupt stops. Seeded 2/4/16-peer runs compare compensation with deliberately omitted transit age. Four real PTY clients also exercise constant motion, directional input, loss/jitter and cleanup. These are controlled motion checks, not collision, MMO-scale or hostile-peer validation.

Current cost remains a scan of reports per entity with repeated decoding. Keep that limitation visible before increasing scene size; no indexing or scheduling framework was added in this pass.
