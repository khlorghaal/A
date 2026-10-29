---
name: todo
description: Maintain active and deferred project todos in docs/todo.txt.
---

Use docs/todo.txt as the authoritative project queue. Preserve its plain text,
indentation and the author's wording unless revising it is authorized.

A standalone defer>>> or Deferred>>> line (case-insensitive, whitespace trimmed)
starts the deferred remainder of the file. Everything after it is deferred,
including unindented items and later headings. No heading reactivates work.
Items explicitly marked deferred before the boundary are deferred too.

Use concise task or outcome phrases. Do not prefix entries with redundant verbs
such as "implement"; membership in the todo already expresses work to be done.

Remove completed, verified tasks instead of marking them done in the todo.
Transcribe enduring behavior or decisions into the appropriate docs topic when
warranted. Keep unfinished portions, and distinguish evidence from proposals.
