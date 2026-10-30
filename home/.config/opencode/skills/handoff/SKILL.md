---
name: handoff
description: "Use when a refined scope brief exists and is ready to be packaged for engineering, before any work reaches the engineer agent."
---

# Handoff Skill

Package a refined scope brief into a **self-contained, liftable engineering hand-off** — the bridge artifact between the product work-shaping funnel and the engineering lifecycle. This is the third and final stage of the product funnel: a human lifts this artifact and pastes it into the `engineer` agent to seed its design/research phase.

**Always announce at start:** "I'm using the handoff skill to package this for engineering."

**Audience:** the technical product manager (or whoever owns the hand-off), preparing work for engineering pickup.

## Input

A refined scope brief (the output of the `refine` skill):
- In-repo: the matured file at `docs/scopes/YYYY-MM-DD-<topic>.md`.
- Otherwise: an inline refined brief pasted into the conversation.

If the input has not been refined yet (no system considerations, no authoritative scope, no resolved open questions), say so and recommend running the `refine` skill first. Do not fabricate engineering detail — a hand-off is a repackaging of refined material, not a place to invent new scope.

## Behavior

Produce a **separate, self-contained artifact** — distinct from the scope/refine document so a human can lift just this package into the `engineer` agent or a ticket without carrying the stakeholder-scope history. Pull from the refined brief; do not re-derive or expand scope.

Apply the **same right-sizing discipline** as the rest of the funnel: bounded, anti-bloat, no implementation detail (no code, no file paths, no task decomposition — those are the engineer lifecycle's job). The hand-off *seeds* engineering; it is not the plan.

## Pre-Handoff Verification Checklist (Hard Gate)

<HARD-GATE>
Do NOT generate or commit the engineering hand-off package until every item in this checklist is verified. A defective handoff forces engineering to stall or guess.
</HARD-GATE>

Before generating the artifact, audit the refined brief against these criteria:

1. **No TBDs or Placeholders:**
   - Scan for "TBD", "TODO", "to be determined", "pending", or placeholder markers.
   - Every requirement, boundary, and constraint must be resolved or explicitly classified as an Open Risk / Research Spike.
2. **Confirmed Interfaces & Boundaries:**
   - External dependencies, system boundaries, and integration points are explicitly identified and named.
   - Authoritative In Scope vs. Out of Scope boundaries are unambiguous and agreed upon.
3. **Explicit Acceptance Criteria:**
   - Every requirement has concrete, testable/observable criteria that determine pass/fail.
   - Criteria define observable behavior (e.g. status codes, responses, UI feedback, state transitions), not vague statements like "works well".
4. **Zero Reliance on External Memory:**
   - The hand-off package must be completely self-contained.
   - An engineer agent starting in a fresh session with zero prior conversational context must be able to understand the full context, constraints, and requirements without asking "what did you mean by this?"
5. **Zero Implementation Leakage:**
   - The package defines *what* is required and *how completion is verified*, NOT internal code implementations, file paths, or task execution plans. (Those belong to the `engineer` agent's `planner` and `coder` skills.)
6. **Strict Scope Traceability:**
   - Every item traces directly back to the refined brief. No new requirements or speculative scope invented during packaging.

## The Hand-Off Artifact

A bounded, engineering-seed-shaped package. Bias short — it should read as a clean statement of work that the `engineer` agent's researcher phase can pick up directly.

| Section | Purpose |
|---|---|
| **Summary** | 2–4 sentences — what this work is, in engineering-relevant terms |
| **Goal / Outcome** | The outcome engineering is being asked to achieve |
| **Authoritative Scope** | In scope / out of scope, carried from the refined brief (the authoritative determination) |
| **Key Constraints & System Considerations** | System boundaries, dependencies, and constraints engineering must respect |
| **Edge Cases & Expected Behaviors** | Expected behavior for unstated scenarios, error states, and degradation |
| **Acceptance Criteria** | Concrete, observable verification checks judging completion |
| **Open Risks / Spikes** | Anything still flagged needs-spike or deferred, surfaced up front |
| **Suggested Ticket(s)** | Sized as single checkable deliverables matching the refined breakdown |

If the refined brief was broken into multiple tickets, the hand-off may produce one package per ticket, or one package listing the ticket set — match the refined breakdown; do not introduce a new decomposition.

## Self-Calibration Pass

After drafting, review against these anti-patterns and trim or flag before presenting:

1. **Scope invention** — the hand-off contains scope, constraints, or criteria not present in (or derivable from) the refined brief. Strip it; a hand-off repackages, it does not expand.
2. **Implementation leakage** — the package prescribes *how* to build (code, file paths, task steps). Remove it; that is the engineer lifecycle's job.
3. **Ballooning** — the package has grown past a clean, digestible statement of work. Trim.
4. **Unresolved hand-off** — risks/spikes left implicit. Surface every known unknown explicitly under Open Risks / Spikes.
5. **Memory dependence** — the package relies on context that was discussed in conversation but not explicitly written down. Rewrite so it is 100% self-contained.

## Red Flags & Common Rationalizations

Watch out for these anti-patterns and shortcuts during hand-off packaging:

**Never:**
- Hand off a document containing "TBD" or unaddressed questions.
- Assume the engineer agent will remember context from previous turns or conversations.
- Dictate implementation file paths, code snippets, or sub-task steps.
- Hand off unrefined stakeholder notes directly without refinement.
- Add "nice-to-have" features during packaging that were never refined.

### Common Rationalizations

| Rationalization / Thought | Reality |
|---|---|
| "I can leave a few TBDs for engineering to figure out" | Placeholders in handoffs force engineering to guess or stall. Resolve all unknowns or explicitly flag as a research spike. |
| "The engineer was in the conversation, so they know the context" | The engineer agent starts fresh with zero conversational memory. The handoff must be completely self-contained. |
| "I'll suggest which files to edit to be helpful" | File paths and code edits belong to the engineering lifecycle (`planner`/`coder`). Hand-offs specify requirements, boundaries, and acceptance criteria. |
| "We can skip acceptance criteria if the goal is clear" | Without explicit, testable acceptance criteria, neither engineering nor review can determine when the task is truly done. |
| "I'll expand the scope with some good ideas I just had" | Handoff repackages refined material; it never invents or expands scope. New ideas must go through refinement. |

## Persistence (Environment-Adaptive)

**Inline rendering is the canonical output in every environment** — always render the full hand-off artifact in the conversation.

Then, **only if a repository working directory is available**:

- Write a **new, separate** file at `docs/handoffs/YYYY-MM-DD-<topic>.md` (note the plural `handoffs`, consistent with `docs/scopes/`, `docs/specs/`, and `docs/plans/`). Unlike `refine`, this is a distinct artifact — the whole point is a liftable package, so it does NOT edit the scope document in place.
- Commit it so the hand-off is captured in git history alongside the scope/refine document it derives from.
- If `docs/` is gitignored, keep the file as a local working artifact (still render inline).

**If no repository working directory is available** (e.g., a Claude organizational skill), inline is the sole output — the user copies the package into their ticket system or the `engineer` agent.

## Next Step

Always end the hand-off artifact with this pointer (a pointer, not a handoff — this skill never invokes another agent):

> *Ready for engineering — paste this package into the `engineer` agent to begin design/planning.*

## Key Principles

- Repackage, don't expand — everything traces back to the refined brief
- Self-contained and liftable — no dependency on the scope document's history
- No implementation detail — seed the engineer lifecycle, don't pre-empt it
- Same right-sizing discipline — a clean statement of work, not a dump
- Stand-alone — render inline always, write a separate file in-repo when possible, never invoke another agent
