---
name: todo
description: Maintain active and deferred project todos in docs/todo.txt.
---

Use docs/todo.txt as the authoritative project queue. Preserve its plain text,
indentation and the author's wording unless revising it is authorized.

Order expresses priority, not a required execution sequence. Prefer the
highest-priority task that can make useful progress now; tasks may be done in
any order. Infer dependencies from what the work actually requires, never from
list position or indentation alone. Honor explicit sequencing and pause points.

If an item needs unavailable input, authorization, hardware or verification,
record the specific missing condition and continue with independent work. A
partially verified item stays unfinished, but unrelated tasks remain available.
Reconsider blocked items when their missing condition changes. Before declaring
the run blocked, inspect the remaining authorized queue; give a concrete reason
for each remaining task or group that truly shares the same blocker.

A standalone defer>>> or Deferred>>> line (case-insensitive, whitespace trimmed)
starts the deferred remainder of the file. Everything after it is deferred,
including unindented items and later headings. No heading reactivates work.
Items explicitly marked deferred before the boundary are deferred too.
If the user explicitly authorizes deferred work as a fallback, apply that
condition when selecting tasks; do not stop at the marker after it is met.
Record the scope and condition so they survive compaction. Without such
authorization, leave deferred items untouched.

Use concise task or outcome phrases. Do not prefix entries with redundant verbs
such as "implement"; membership in the todo already expresses work to be done.

Remove completed, verified tasks instead of marking them done in the todo.
Transcribe enduring behavior or decisions into the appropriate docs topic when
warranted. Keep unfinished portions, and distinguish evidence from proposals.
