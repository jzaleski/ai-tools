---
name: refine
description: "Use when an existing stakeholder scope artifact needs technical maturation before it is ready to hand off to engineering."
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

## Spec as Vision Document: Proactive Edge Cases & Resilience

The stakeholder's scope brief defines what the user wants to achieve under happy-path conditions. However, **the specification is a vision document**: it must define what software must do under all real-world conditions, not merely what the stakeholder explicitly asked for.

<HARD-GATE>
Spec silence is NOT permission for crashing, hanging, losing data, or presenting unhandled exceptions. If the stakeholder did not mention an edge case or failure mode, judge by what a reasonable user would expect.
</HARD-GATE>

During refinement, you must proactively discover and define:
- **Unstated edge cases:** Empty states (no records, new user, zero search results), zero-length or boundary inputs, special characters, unicode, high concurrency or race conditions, pagination boundaries, extreme volumes, and clock/timezone skews.
- **Reasonable user expectations:** What would any reasonable user expect to happen?
  - Immediate responsive feedback or loading indicators.
  - Informative, user-friendly error messages (never raw database exceptions or stack traces).
  - Idempotent actions where duplicate submissions or retries do not duplicate state or corrupt records.
  - Safe defaults when optional data is missing.
- **Failure modes & degradation:** How does the system behave when dependencies fail?
  - Downstream service, API, or database timeouts.
  - Network disconnection or partial socket drops.
  - Degraded mode / fallback behavior instead of total service outage.
- **Technical constraints & system boundaries:**
  - Database transaction boundaries and concurrency isolation.
  - Authentication, authorization, and tenant isolation rules.
  - Performance SLAs, payload size limits, and rate limits.
  - Backwards compatibility with existing clients and schemas.

## What Refine Adds

Augment the scope artifact with these sections (authored with a technical basis):

| Section | Purpose |
|---|---|
| **System Considerations & Constraints** | Real boundaries of the existing system, architecture, auth, and performance SLAs |
| **Edge Cases & Reasonable Expectations** | Unstated boundary scenarios, failure modes, error handling, and expected UX resilience |
| **In Scope / Out of Scope (authoritative)** | The true scope boundaries — supersedes the stakeholder's soft "Boundaries (as understood)" |
| **Complexity / Shape** | Effort/size assessment with a technical basis; confirms or revises the stakeholder's shape intuition |
| **Resolved Open Questions** | Walk the stakeholder's Unknowns list and resolve each: `answered` / `needs-spike` / `deferred` |
| **Ticket Breakdown** | Sized as single checkable deliverables ready for engineering |

When you supersede the stakeholder's soft "Boundaries (as understood)", keep their original framing visible (it is their input) and add the authoritative determination — do not silently delete their contribution.

## Sizing Ticket Breakdowns as Single Checkable Deliverables

When the work is non-trivial or spans multiple areas, decompose it in the **Ticket Breakdown** section. Every ticket must be sized as a **single checkable deliverable**:

- **The Goldilocks Size:** The smallest cohesive unit carrying its own verification cycle and observable value.
  - *Not a mega-ticket:* Avoid combining database migrations, core backend logic, public APIs, and complex UI forms into a single monolithic ticket that stalls implementation and review.
  - *Not micro-tasks:* Avoid fragmented, uncheckable tickets (e.g., "create schema file", "add helper function"). Every ticket must produce an observable, testable outcome.
- **Self-Contained Contract:** An engineer picking up the ticket can implement it, run tests proving it works, and get it reviewed without relying on half-finished state in flight.
- **Deliverable Format per Ticket:**
  - **Ticket Name:** Clear action and subject (e.g. `feat(auth): Add refresh token rotation endpoint`)
  - **Single Checkable Deliverable:** The exact observable behavior or interface contract delivered.
  - **Dependencies / Sequence:** Explicit prerequisite tickets.
  - **Verification Method:** How an engineer or reviewer verifies completion (e.g. unit/integration test, contract check, curl command).

## Right-Sizing Self-Calibration Pass

After augmenting, review against these anti-patterns and trim or split before presenting:

1. **Ballooning** — the document has grown past what a reader can digest. Trim, or split into multiple tickets via the Ticket Breakdown.
2. **Unresolved unknowns** — an Open Question was left dangling instead of being marked `answered`, `needs-spike`, or `deferred`. Resolve each explicitly.
3. **Scope drift** — new requirements crept in that were not in the stakeholder's need. Flag them; do not silently expand scope.
4. **Speculative detail** — complexity or considerations asserted without an empirical basis. Mark as `needs-spike` rather than guessing.
5. **Fragile deliverables** — a ticket in the Ticket Breakdown cannot be independently checked or leaves hanging, incomplete state. Reshape it as a single checkable deliverable.

## Red Flags & Common Rationalizations

Watch out for these anti-patterns and shortcuts during refinement:

**Never:**
- Leave an open question unresolved ("we'll figure this out during coding").
- Treat stakeholder silence on error states or edge cases as permission to skip error handling.
- Produce a single monolithic ticket for a complex, multi-component feature.
- Break work into non-functional fragments that cannot be independently checked.
- Fabricate technical constraints without verifying against codebase realities.

### Common Rationalizations

| Rationalization / Thought | Reality |
|---|---|
| "The stakeholder didn't mention error handling, so happy path is enough" | The spec is a vision document. Silence is not permission to crash. Unstated edge cases and failure modes must be explicitly addressed before engineering. |
| "We can leave this open question for the coder to decide" | Leaving product decisions or interface contracts to coders causes divergent implementations and expensive rework. Resolve every question as `answered`, `needs-spike`, or `deferred`. |
| "I'll create a new file for refined scope instead of editing the existing scope" | Refine augments the same `docs/scopes/` file in place so git history captures the complete maturation audit trail. |
| "One big ticket is fine, engineering will break it down anyway" | Sizing tickets as single checkable deliverables forces clarity on boundaries and prevents stalled implementations. |
| "Edge cases and timeouts are implementation details" | User-facing behavior during failure or edge cases is a core product requirement, not an afterthought. |

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

> *Next step: package for engineering (see the `handoff` skill) to produce a liftable hand-off artifact.*

## Key Principles

- Mature, don't replace — augment the stakeholder's document in place
- Author system considerations, authoritative scope, and complexity with a real basis
- Resolve every open question explicitly (answered / needs-spike / deferred)
- Same right-sizing discipline — split rather than balloon
- Stand-alone — render inline always, persist in-repo when possible, never hand off
