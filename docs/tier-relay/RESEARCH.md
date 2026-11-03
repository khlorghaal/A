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

Inspected todo, design docs and implementation. No external sources, builds or policy experiments. No policy decision or implementation made.


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

At the time of this scout, source and nimsuggest outlines only; no builds or diagnostics. The test run below came later. Decide whether estimated CCN scan justifies installing or building Nim AST metrics; review gateway/trustsync seams and tag findings before any refactor.

### Test code

- Tests deserve same maintainability review as production code, with different aim: cases should read as behavior contracts. Prefer clear setup/assertion over abstraction that hides expected behavior; reuse fixture mechanics when it guarantees isolation and cleanup.
- blastd has 42 named `unittest` cases across `deps/blastd/tests`; source scan found individual case CCN estimates at most ~3. `core_checks.nim` uses global fake hooks, reset in suite `setup` (`deps/blastd/tests/core_checks.nim:13-49,66-70`). This is understandable shared fixture state; future cases must keep reset complete.
- A test files mostly use top-level `doAssert` and named `block`s rather than `unittest` cases (`tests/trustdb_checks.nim`, `tests/gateway_checks.nim`). That makes per-case complexity comparison harder; sequential assertions still read directly, but failure stops at first point and some cleanup relies on reaching file end (`tests/trustdb_checks.nim:179-304`).
- Integration complexity looks purposeful where boundary is target: TLS checks use real async sockets plus OpenSSL-generated certs (`tests/gateway_tls_checks.nim:8-55,97-148`); multi-terminal checks launch clients under POSIX PTYs and clean child processes in `finally` (`tests/multi_terminal.nim:1-35,100-167`). These carry platform, binary, process and timing assumptions; keep prerequisites and cleanup explicit.
- `make test` and `make multi_agentvm` passed after the documentation pass described below. Added regression coverage checks stale reports cannot renew TTL and malformed boolean input cannot consume a revision (`tests/sync_checks.nim`). CCN figures above remain source-scan estimates, not test quality scores.

### Documentation audit

- `docs/network.txt:34` promises paragons are hidden, while `docs/gateway-database.txt:99-106` says visibility is unresolved. Gateway implementation keeps membership private, but the policy wording still needs one authoritative decision.
- `docs/network.txt:36-39` retains the older two-authority/one-auth topology; a later section explicitly supersedes it with auth and gateway on one server. Marking the earlier block historical would make the intended precedence clearer.
- `llm/p2p-research.txt:68` says owner bonus `+.5`; current `docs/architecture.txt:56` and `llm/synchronization.md:17` specify `0.3`. Research/history status at that line is unclear.
- `llm/blastd-handoff.txt:4-6` says A still uses its original core and needs a remote before submodule linkage; current `docs/build.txt:2-3` describes the blastd submodule. The handoff lacks an archival date/status label.
- `docs/architecture.txt:14-18` labels credibility evolution “proposed,” while the current implementation summary later in the same file says it is accepted/current. Clarify which formula is implemented and which remains proposal.
- `llm/README.txt` points to `/workspace/agent-state/reference/style.md` and `visual-references.md`; both files exist in this workspace. These are machine-local links, so the README should identify that dependency for other checkouts.

These are audit findings only; no policy or implementation decisions were made. Exact locations and current test outcomes are recorded here so Sol can resolve wording without reopening the source scan.

### General assessment

CCN, size and import counts prioritize inspection; never establish poor design alone. Trace state ownership, data/control flow, cohesion, invariants and failure cleanup before refactoring. Apply same correctness and readability bar to tests; judge test code by clear behavior contracts, deterministic isolation, useful failures and reliable cleanup, not by minimizing lines or branches.
