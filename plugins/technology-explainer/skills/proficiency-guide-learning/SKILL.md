---
name: proficiency-guide-learning
description: >
  Invoked automatically when explaining learning-level technologies.
  Provides rules for detailed theory-first responses with examples and step-by-step walkthroughs.
  Do NOT explain learning-level technologies without consulting this guide.
  Keywords: learning explanation, detailed theory, tutorial, step-by-step, teach.
---

# Learning-Level Explanation Guide

The user is **actively learning** this technology. Follow these rules for all terminal explanations.

## Rules

1. **Start with context.** Briefly explain what the concept is and why it matters before diving into specifics.
2. **Build understanding step by step.** Structure explanations from simple to complex. Don't assume prior knowledge of this technology.
3. **Provide concrete examples.** Show complete, runnable examples — not fragments. Annotate with inline comments.
4. **Explain terminology.** Define jargon and acronyms on first use.
5. **Show cause and effect.** When explaining a command or configuration, show what happens when you run it and why.
6. **Warn about common mistakes.** Proactively highlight what beginners typically get wrong and how to avoid it.
7. **Suggest next steps.** Point to relevant documentation, tutorials, or concepts to explore next.

## Using Preferred Sources

If the SessionStart output lists custom sources for this technology (under **Sources:**), prioritize those references:
- Cite them when recommending documentation
- Align coding style with referenced style guides
- Link to specific pages when suggesting further reading

## Examples

**Good** (learning user asking about Terraform state):
> **Terraform state** is a file (`terraform.tfstate`) that Terraform uses to track which real infrastructure resources correspond to your configuration. Think of it as a map: your `.tf` files describe what you *want*, and the state file records what *actually exists*.
>
> When you run `terraform plan`, Terraform compares your config against the state to figure out what needs to change. Without state, Terraform wouldn't know if a resource already exists or needs to be created.
>
> **Important:** Never edit the state file manually. If you need to move or remove resources, use `terraform state mv` or `terraform state rm`.
>
> For teams, store state remotely (S3 + DynamoDB locking) so everyone works from the same source of truth. See the [HashiCorp docs on remote state](https://developer.hashicorp.com/terraform/docs).

**Bad** (too terse for learning):
> State tracks resources. Use `terraform state mv` to move them. Store remotely for teams.

## Scope

These rules apply ONLY to conversational explanations in the terminal. Code comments, docstrings, and project documentation must follow project conventions regardless of proficiency level.
