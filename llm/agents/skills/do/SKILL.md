---
name: do
description: Execute authorized active tasks autonomously with visual review, meaningful commits, tests and durable handoffs.
---

# Do

When the user says `do`, execute the previously specified work rather than just
planning it. Explicit task constraints override this skill. Never infer permission
to implement from a request merely to discuss or estimate.

Read ../todo/SKILL.md first. For project todo work, docs/todo.txt is authoritative;
read it through the active-task view from the project root:
  nim r llm/todo.nim docs/todo.txt

Never select or execute a deferred task. A defer>>> or Deferred>>> boundary
applies to every subsequent line regardless of indentation or headings.
An explicit user instruction can promote deferred tasks or open them as a
fallback under a stated condition; apply that authorization as described in
../todo/SKILL.md. Otherwise do not implement, research, plan or otherwise work
on deferred items, including explicitly deferred items above the boundary.

Scan project comments with `rg '#!!|#\?+|#todo|#fixme'` for the markers
defined in AGENTS.md. Treat them as leads for active work, and leave deferred
work untouched. Explain lines marked with questions when their meaning is clear.
Inspect only a small surrounding section (about 10 lines either side) unless
more context is needed; use other resource-saving methods when useful.

1. Select useful work using ../todo/SKILL.md: list order is priority, not a
   dependency chain. Resolve routine choices yourself. Record an item's missing
   input or verification and continue with independent work. Ask necessary
   questions without suspending work that does not depend on the answer.
2. Divide work into independently meaningful Git commits. Commit a coherent,
   reviewed checkpoint before risky changes or large refactors. Preserve unrelated
   edits; avoid destructive Git operations without authorization.
3. Iterate edit → compile/test → inspect → revise. Use
   ../visual-annealing/SKILL.md for difficult regions and at commit checkpoints.
   Inspect each revised rendering; iterate or widen the scope until the composition
   settles, then review the whole change and full diff. Record actual outcomes;
   never claim unrun tests passed. Honor explicit build/test restrictions.
4. Commit completed segments after relevant checks. Remove completed todos and
   document enduring details as warranted, following ../todo/SKILL.md.
5. After each commit explicitly invoke ../vacation/SKILL.md for a brief checkpoint,
   then resume the remaining active work. Keep the detour proportionate.
6. After each segment, select the next available task and act on it in the same
   run. Prefer higher priorities but move freely when another item can progress.
   Coarse passes followed by refinement are acceptable. Updates, reports, commits
   and handoff notes do not end the run. Keep going while authorized work remains.
7. Preserve outstanding work and state using ../session-handoff/SKILL.md. Distinguish
   intentions, assumptions and verified results; leave concrete next actions.

## `do burn` / `burn`

Apply all `do` rules, with these stronger continuation rules:

Finishing a burn means continuing productive, authorized work until the token
cutoff or a blocker affecting all remaining work; it does not mean completing
every todo. A completed checkpoint, a passing build, or verification that needs
the user's device does not block independent tasks. Record the limitation and
continue immediately with another authorized task; do not yield to the user.
Only describe a runtime or token cutoff when it actually occurs; do not claim
one based on a guess or use it as a reason to stop early.

- **Termination invariant:** Do not voluntarily stop while feasible, authorized, productive work remains. Continue across todo items, commits, failures, and promising tangents. Use available execution budget; never claim that a model can override runtime limits.
- When uncertainty, failure, or a dead end arises: **checkpoint first**, then attempt redesign. Make a descriptive Git commit recording the current work/state before risky changes, if a repository exists and a commit is safe. If the worktree contains unrelated changes, secrets, or unsuitable files, stage only owned safe changes; otherwise preserve a recoverable diff or note rather than creating a harmful commit. Mark incomplete/broken checkpoints explicitly; do not misrepresent tests.
- Diagnose cause; revise assumptions, architecture, experiment, or task decomposition. Attempt an alternative and test it. If blocked on one task, switch to other useful tasks; return when new information or ideas permit.
- Before a voluntary stop, inspect all remaining authorized work, including any
  fallback scope the user opened. If any task or useful part can progress,
  select it and continue. A blocker applies only to tasks that actually depend
  on it. State concrete missing conditions if every path is blocked; do not
  replace this check with a summary of the completed work.
- If implementation is blocked, use remaining capacity on relevant tests, refactoring, visual/code beauty, research, design exploration, or precise handoff notes. Do not generate unrelated work merely to consume tokens.
- Halt voluntarily **only when further effort would be wasteful**: no feasible productive path remains, necessary external authorization/input is missing for every path, or the todo is complete and no authorized improvement remains. State the blocker or completion criterion and unfinished items. Explicit `pqt`, a stop request, safety boundaries, and hard execution limits always take precedence.

State and commits must be truthful. Never invent tool use, completed tests, available tokens, or future autonomous continuation.
Context compaction is not a stop: preserve scope, ready work and blocked items
in a compact handoff, then continue after compaction. Skill instructions cannot
restart an ended run or guarantee unattended runtime; do not claim otherwise.
