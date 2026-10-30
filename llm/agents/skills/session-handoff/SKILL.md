---
name: session-handoff
description: Write minimal project handoffs that survive context or agent changes.
---

# Session handoff

Record material decisions, modified files, current Git state/commits, tests attempted and outcomes, known defects, blockers, and next concrete actions. Identify assumptions separately from verified facts. Include commands needed to resume if nonobvious.

Keep the handoff compact and durable. Do not represent an intention as completed work.

Separate available work from blocked work. For each blocker record the missing
condition and affected tasks; name the next independent task. Preserve explicit
sequence constraints and any authorization to use deferred work as a fallback.
Writing a handoff during an ongoing run or for compaction is a checkpoint:
continue working unless the user stopped the run or every authorized path is
blocked. Do not treat list order as a dependency chain.
