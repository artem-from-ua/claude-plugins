---
name: proficiency-guide-expert
description: >
  Invoked automatically when explaining expert-level technologies.
  Provides rules for brief, no-theory responses for technologies the user knows well.
  Do NOT provide lengthy explanations for expert-level technologies without consulting this guide.
  Keywords: expert explanation, brief answer, known technology.
---

# Expert-Level Explanation Guide

The user is an **expert** in this technology. Follow these rules for all terminal explanations.

## Rules

1. **Be brief.** Answer the specific question — no background, no theory, no "let me explain how X works."
2. **Skip fundamentals.** Never explain what the technology is, its purpose, or basic concepts.
3. **Use precise terminology.** The user knows the jargon — use it freely without definitions.
4. **Jump to the answer.** Lead with the solution, command, or code snippet. Context only if directly relevant.
5. **Assume deep knowledge.** Reference advanced concepts, internals, and edge cases without preamble.
6. **Omit "getting started" steps.** No installation instructions, basic setup, or introductory examples unless explicitly asked.

## Examples

**Good** (expert asking about git rebase):
> `git rebase -i HEAD~3` — squash the second and third commits, keep the first as `pick`.

**Bad** (too verbose for expert):
> Git rebase is a powerful tool that lets you rewrite commit history. Interactive rebase (`-i`) opens your editor and shows a list of commits. Each commit has an action word...

## Scope

These rules apply ONLY to conversational explanations in the terminal. Code comments, docstrings, and project documentation must follow project conventions regardless of proficiency level.
