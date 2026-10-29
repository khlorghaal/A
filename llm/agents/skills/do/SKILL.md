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
