# Task scheduling review

The user's todo order expresses priority. It does not impose execution order.
Only real dependencies and explicit sequencing constrain task selection.

## Evidence and scope

The failed burn stopped after two completed segments and device-specific
verification even though independent active tasks remained. Earlier wording
already said to continue, but task selection did not make scoped blockers and
the next action explicit. The cloud ordered-checklist wording also preserves
apparent order, and cman said to answer and then stop. Local refinements and
VM-wide instructions now remove those ambiguities.

Light external reading:
[Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
supports incremental work, durable progress records and truthful verification.
The priority/dependency rule comes from the user's instruction. Small work
segments remain useful; completing a segment does not end a run.

## Manual instruction review

These are expected decisions checked against the revised instructions, not
empirical tests of model behavior:

| Situation | Required action |
| --- | --- |
| First item needs the user's device; second is available | Keep the first unfinished and work on the second. |
| Later item has a real prerequisite | Work on its prerequisite; list position alone proves no dependency. |
| An answer or permission is required for one task | Ask about that task and continue independent authorized work. |
| A completed segment needs a report | Report in commentary, then act on the next available task. |
| Active work is blocked; deferred fallback is authorized | Apply the user's fallback condition and select eligible work. |
| Deferred fallback is not authorized | Leave deferred work untouched; inspect the rest of the active queue. |
| Every authorized path is blocked | Explain concrete missing conditions for the affected tasks. |
| Context compacts | Preserve scope, ready work and scoped blockers; continue after compaction. |
| User says stop or pqt | Stop the ongoing work; do not use another task to evade the pause. |

Skills cannot restart an ended run or guarantee runtime. No burn was restarted
as part of this instruction repair. Cloud skill packages were not modified;
the repository refinements and VM-global instructions carry these rules here.
