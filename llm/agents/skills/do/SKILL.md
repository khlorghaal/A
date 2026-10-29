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
An explicit user instruction can promote a specific deferred task; otherwise
do not implement, research, plan or otherwise work on it. Explicitly deferred
items above the boundary are also excluded.

1. Briefly skim the active work and identify genuinely blocking questions. Ask
   only for material blockers; record real blockers without inventing policy.
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
6. For complex work, move between tasks when useful and return to unfinished items.
   Coarse passes followed by refinement are acceptable. Keep going while authorized
   work remains and resources permit; do not stop merely because one segment is done.
7. Preserve outstanding work and state using ../session-handoff/SKILL.md. Distinguish
   intentions, assumptions and verified results; leave concrete next actions.

## `do burn` / `burn`

Apply all `do` rules, with these stronger continuation rules:

- **Termination invariant:** Do not voluntarily stop while feasible, authorized, productive work remains. Continue across todo items, commits, failures, and promising tangents. Use available execution budget; never claim that a model can override runtime limits.
- When uncertainty, failure, or a dead end arises: **checkpoint first**, then attempt redesign. Make a descriptive Git commit recording the current work/state before risky changes, if a repository exists and a commit is safe. If the worktree contains unrelated changes, secrets, or unsuitable files, stage only owned safe changes; otherwise preserve a recoverable diff or note rather than creating a harmful commit. Mark incomplete/broken checkpoints explicitly; do not misrepresent tests.
- Diagnose cause; revise assumptions, architecture, experiment, or task decomposition. Attempt an alternative and test it. If blocked on one task, switch to other useful tasks; return when new information or ideas permit.
- If implementation is blocked, use remaining capacity on relevant tests, refactoring, visual/code beauty, research, design exploration, or precise handoff notes. Do not generate unrelated work merely to consume tokens.
- Halt voluntarily **only when further effort would be wasteful**: no feasible productive path remains, necessary external authorization/input is missing for every path, or the todo is complete and no authorized improvement remains. State the blocker or completion criterion and unfinished items. Explicit `pqt`, a stop request, safety boundaries, and hard execution limits always take precedence.

State and commits must be truthful. Never invent tool use, completed tests, available tokens, or future autonomous continuation.
