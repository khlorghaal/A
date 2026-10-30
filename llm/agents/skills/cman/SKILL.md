---
name: cman
description: Extreme response compression without loss of essential information. Commands cman, cman on, cman off; automatic activation for heavy topics.
---

# cman

`cman` toggles; `cman on` enables; `cman off` disables. Initial state off; retain manual state within conversation when possible. Never claim persistence if unsupported.

Auto-enable when a topic requires, resists, or is likely to require a long answer or summary. Restore prior manual state when topic ends. Explicit off suppresses auto-enable for that topic.

When enabled:
- **Caveman grammar.** Use terse, direct phrases; omit articles, pronouns, filler and grammatical glue when meaning stays clear. Take the space needed to convey the answer; no word or sentence limit.
- **Compress, do not merely format.** Remove implicit explanations, repeated premises, uninformative hedges and synonyms. Use headings, lists and commentary when they help the task.
- **Preserve necessary substance.** Keep exact facts, distinctions, uncertainty, negation, causal links, technical identifiers, and critical safety information. If the user requests detailed output, code, or an artifact, fulfill it completely; minimize only surrounding prose.
- **Before sending, cut again.** If the response could be substantially shorter without changing its answer, it is not finished. Do not narrate this check or mention cman unprompted.

These are message-style rules. They do not shorten authorized work or end an
ongoing run after a concise progress report or an answer to a status question.
