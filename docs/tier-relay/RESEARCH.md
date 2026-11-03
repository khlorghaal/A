# Paragon visibility and reporter weights

Question: resolve active todo `settle paragon visibility and gateway reporter-weight inputs` (`docs/todo.txt:3`).

## Evidence

- Policy conflict: `docs/network.txt:34` says players never see paragons. `docs/gateway-database.txt:99-106` calls visibility unresolved; recommends private aggregation, lists public membership as alternative. No final decision recorded.
- Current code favors private roles: `src/gateway.nim:13,22-33` keeps membership internal; demotion removes role session and reports. Report/delete require current role (`:101-106`); authenticated snapshot does not (`:86-104`).
- Snapshot rows contain subject and aggregate value, no reporter IDs (`src/gateway_snapshot.nim:19-41`). Manual codec exists; gateway transport/auth remain external (`docs/gateway-database.txt:34-39`).
- Host injects reporter-weight callback (`src/gateway.nim:63-80`). One immutable prior-score view drives aggregation; weights must be finite `[0,1]`. Production source and account mapping remain undefined (`docs/gateway-database.txt:26-39,83-85`). Gateway has no gameplay evidence to create firsthand witness scores.
- Aggregation computes `sum(priorCombined[reporter] * report) / reporterCount`, not division by sum of weights (`src/gateway.nim:65-80`; peer analogue `src/trustdb.nim:43-77`; design `docs/gateway-database.txt:87-97`). Low weights reduce category magnitude; rule matches current implementation and documented intent.
- Provenance remains open: gateway aggregate or direct paragon reports. Same opinion may also enter swarm, creating correlated influence (`docs/gateway-database.txt:95-97,118-120`).

## Arrangements

- Private membership + gateway aggregate: matches `network.txt:34` and snapshot schema. Smaller client state; gateway owns classification/weighting. Behavior may reveal roles; manual snapshots may stale (`docs/gateway-database.txt:108-123`).
- Public membership + direct reports: client can inspect attribution and reweight locally. Exposes role holders; adds membership distribution, freshness, provenance and reclassification work (`docs/gateway-database.txt:108-120`).

## Decisions for Sol

1. Treat `network.txt:34` as binding privacy policy, or historical intent? Resolve doc conflict.
2. Define reporter-weight source and authenticated-ID mapping. Preserve frozen prior snapshot; do not invent firsthand witness evidence.
3. Confirm count denominator. Current behavior matches peer aggregation, but differs from normalized weighted mean; change would alter score semantics.
4. Choose paragon provenance and overlap policy. Prevent unintended double influence across paragon/swarm components.

## Limits

Inspected todo, design docs and implementation. No external sources, builds, tests or experiments. Prior instruction prohibits tests/debug. No policy decision or implementation made.
