---
name: do
description: Execute active project todos with review and sensible commit checkpoints.
---

Read ../todo/SKILL.md first. Read docs/todo.txt through the active-task view:
  nim r llm/todo.nim docs/todo.txt

Never select or execute a deferred task. A defer>>> or Deferred>>> boundary
applies to every subsequent line regardless of indentation or headings.
An explicit user instruction can promote a specific deferred task; otherwise
leave it deferred. Explicitly deferred items above the boundary are also excluded.

Plan practical commit segments. Commit a coherent, reviewed checkpoint before
large refactors or changes, and commit completed segments after relevant checks.
Preserve unrelated edits. Review difficult regions visually and the full diff at
checkpoints. Remove completed todos and document enduring details as needed.

After each commit follow the vacation skill briefly, then resume active work.
Continue eligible work in order; record real blockers without inventing policy.
