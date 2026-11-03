# Research scouts

## Paragon visibility and reporter weights

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


## Nim complexity and coupling scout

Question: locate high branch, dependency and responsibility complexity for Sol.

### Method and limits

- Nim 2.4.0 `nimsuggest outline` queried `gateway`, `trustdb`, `trustsync`, `a` and blastd. Confirmed procedure boundaries/signatures; outline does not emit cyclomatic metrics.
- No installed Nim-aware CCN analyzer found. Lizard's documented language list omits Nim: https://github.com/terryyin/lizard .
- CCN estimates below use source scan: baseline 1 + `if/elif/for/while/when/except`, each `case of` arm, and boolean `and/or`. Not AST-derived; treat rankings and decision locations as leads, not authoritative CCN. No production code changed.

### Highest estimated branch complexity

- `src/gateway.nim:153-198` `loadGateway`: CCN ~39. JSON schema/version migration, role and report validation, quota, ID normalization, revisions in one loader.
- `src/gateway.nim:86-126` `dispatch`: CCN ~30. Authenticated principal checks, request validation, snapshot/report/delete routing and payload parsing.
- `src/trustsync.nim:41-74` `receive`: CCN ~25. Queue cleanup, source identity, JSON decoding, key/revision/quota checks, database mutation.
- `src/a.nim:116-188` `main`: CCN ~22. Game loop owns timing, network tick, player bootstrap, trust step, terminal events and rendering.
- `src/trustdb.nim:115-145` `readDb`: CCN ~22. Legacy/unified schema acceptance, nested TOML validation and error conversion.
- Other raised points: `src/trustdb.nim:43-78` `refresh` ~14; `deps/blastd/src/blastd.nim:142-159` `receive` ~13; `src/gateway.nim:215-253` `serveConnection` ~12; `src/gateway.nim:297-332` `run` ~12.

### Coupling

First-party import graph across A and blastd has no cycles. Module fan-out: `a` 5; `gateway` 4; `trustsync` 4. Fan-in: `trustdb` 4; `identity` 4; `p2p` 3. These are static import counts, not severity scores.

- `gateway` joins role/report state, request codec/dispatch, persistence and optional TLS/async listener in one module (`src/gateway.nim:1-5,86-198,199-332`). `dispatchStored` infers persistence need by parsing `dispatch`'s serialized JSON reply (`:142-151`); internal commit behavior depends on response shape.
- `trustdb` combines credibility state/calculation, TOML migration, POSIX ownership lock and atomic file writer (`src/trustdb.nim:1-8,43-77,115-219`). Gateway imports it only for `writeAtomic` (`src/gateway.nim:4`), coupling gateway storage to trust-domain module.
- `trustsync.receive` adapts network queue to JSON schema, authenticated peer identity and trust DB writes (`src/trustsync.nim:41-74`). Integration may be intentional; function complexity makes assumptions hard to review together.
- `a.main` is expected integration hub, but combines simulation, UI, network and trust lifecycle (`src/a.nim:116-188`).
- `blastd` depends only on its `units` module within first-party graph (`deps/blastd/src/blastd.nim:3-4`); P2P wrapper isolates unit adaptation.

### Other review leads

- `src/sync.nim:4,44` has `#fixme` for beta semantics and `#todo` for one-line equation lambdas.
- Deferred markers remain in `src/client.nim:97` (D-pad artwork) and `src/identity.nim:18` (auth integration); leave deferred. No `#!!` or `#?` tags found in scanned source.
- Possible review seam: separate shared atomic-write utility from `trustdb`; return structured dispatch result instead of reparsing JSON; split gateway schema decoding from role/report policy. These are proposals only. Sol should assess against intentional simplicity before refactor.

### Verification limits and questions for Sol

Static source and nimsuggest outlines only; no builds, diagnostics or tests. Prior instruction still prohibits tests/debug. Decide whether estimated CCN scan justifies installing or building Nim AST metrics; review gateway/trustsync seams and tag findings before any refactor.
