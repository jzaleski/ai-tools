---
name: refine
description: "Technical product-manager skill — matures a stakeholder scope artifact into a system-aware, ticket-ready brief in collaboration with engineering. Augments the same document in place with system considerations, authoritative scope, complexity, resolved open questions, and a ticket breakdown. Stand-alone; does not hand off to other agents."
---

# Refine Skill

Take a stakeholder-authored scope artifact and **mature it into a system-aware, ticket-ready brief** — the second stage of the product work-shaping funnel. This is the technical product manager's tool, used in collaboration with engineering.

**Always announce at start:** "I'm using the refine skill to mature this scope with engineering input."

**Audience:** the **technical product manager**, working with engineering. Unlike the `scope` skill, this stage *is* equipped to author system considerations, authoritative scope, and complexity.

## Input

An existing stakeholder scope artifact:
- In-repo: the file at `docs/scopes/YYYY-MM-DD-<topic>.md`.
- Otherwise: an inline scope brief pasted into the conversation.

If no scope artifact exists yet, say so and recommend running the `scope` skill first. Do not fabricate a stakeholder scope.

## Behavior

Collaborative and iterative — a working session between technical PM and engineering, not a solo dump. Apply the **same right-sizing discipline** as the `scope` skill: bounded, anti-bloat, split rather than balloon.

**Augment the SAME document in place.** Do not create a parallel artifact. The stakeholder's original sections remain (in-repo, git shows what changed); layer the technical maturation on top and resolve the open questions inline.

## What Refine Adds

Augment the scope artifact with these sections (authored with a technical basis):

| Section | Purpose |
|---|---|
| **System Considerations** | Real constraints/boundaries of the existing system the work must respect |
| **In Scope / Out of Scope (authoritative)** | The true scope boundaries — supersedes the stakeholder's soft "Boundaries (as understood)" |
| **Complexity / Shape** | Effort/size assessment with a technical basis; confirms or revises the stakeholder's shape intuition |
| **Resolved Open Questions** | Walk the stakeholder's Unknowns list and resolve each: answered / needs-spike / deferred |
| **Ticket Breakdown** | One or more ticket-ready items if shape/complexity warrant a split |

When you supersede the stakeholder's soft "Boundaries (as understood)", keep their original framing visible (it is their input) and add the authoritative determination — do not silently delete their contribution.

## Right-Sizing Self-Calibration Pass

After augmenting, review against these anti-patterns and trim or split before presenting:

1. **Ballooning** — the document has grown past what a reader can digest. Trim, or split into multiple tickets via the Ticket Breakdown.
2. **Unresolved unknowns** — an Open Question was left dangling instead of being marked answered / needs-spike / deferred. Resolve each explicitly.
3. **Scope drift** — new requirements crept in that were not in the stakeholder's need. Flag them; do not silently expand scope.
4. **Speculative detail** — complexity or considerations asserted without a basis. Mark as needs-spike rather than guessing.

## Refinement Loop

Present the matured document, iterate with the technical PM and engineering, and re-run the self-calibration pass after meaningful changes.

## Persistence (Environment-Adaptive)

**Inline rendering is the canonical output in every environment** — always render the full matured artifact in the conversation.

Then, **only if a repository working directory is available**:

- Edit the **same** `docs/scopes/YYYY-MM-DD-<topic>.md` file in place (do not create a new file).
- Commit it so **git history preserves the scope→refined maturation** as a sequence of commits to one document.
- If `docs/` is gitignored, keep the file as a local working artifact (still render inline).

**If no repository working directory is available** (e.g., a Claude organizational skill), inline is the sole output — the user copies it into their ticket/doc system.

## Next Step

Always end the matured document with this pointer (a pointer, not a handoff — this skill never invokes another agent):

> *Ready for engineering — hand to the `engineer` agent to begin design/planning.*

## Key Principles

- Mature, don't replace — augment the stakeholder's document in place
- Author system considerations, authoritative scope, and complexity with a real basis
- Resolve every open question explicitly (answered / needs-spike / deferred)
- Same right-sizing discipline — split rather than balloon
- Stand-alone — render inline always, persist in-repo when possible, never hand off
