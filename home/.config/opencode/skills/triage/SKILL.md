---
name: triage
description: "Use when a raw, unsorted inbound request arrives and needs to be classified and routed before any other work begins."
---

# Triage Skill

Classify a raw, unsorted inbound request and produce a **fast triage decision** that says what kind of work it is and where it should go next. This is the **front door of the product work-shaping funnel** — a sister step to intake, typically orchestrated between the non-technical stakeholder (who brings the request) and the technical product manager (who applies the routing judgment).

**Always announce at start:** "I'm using the triage skill to classify and route this request."

**Audience:** product and engineering — anyone fielding inbound requests. It is product-aligned (a shaping/routing judgment, not implementation), but either side may run it.

## What Triage Is (and Is Not)

- **Is:** a fast, mostly single-pass classification that points the request at its destination.
- **Is not:** a shaping session. Triage does NOT gather detailed requirements, refine, or estimate — that is `scope`'s job once a request is routed into the funnel. Keep it quick.

## Behavior — Fast, Single-Pass

Read the request and emit the triage decision immediately. Do **not** run an iterative refinement loop.

The only time to ask a question is when the request is too empty to classify at all — and even then, the correct output is usually the **Needs more info** classification with the specific questions listed, rather than a back-and-forth. Ask a clarifying question only if a single answer would clearly flip the classification.

## Routing Buckets

Classify into exactly one:

| Bucket | Meaning | Recommended next step (a pointer, not an action) |
|---|---|---|
| **Product shaping** | A real feature/change request that needs requirements work | → run the `scope` skill (the funnel's intake step) |
| **Engineering** | Already well-specified, or a trivial fix/bug that does not need product shaping | → hand to the `engineer` agent |
| **Data / analysis** | An analysis, report, or data-wrangling job | → hand to the `data` agent |
| **Needs more info** | Cannot be classified yet | → bounce back to the requester with the specific questions listed |
| **Not actionable** | Out of scope, duplicate, or not a real request | → reject / defer, with a one-line reason |

When the bucket is **Product shaping**, the pointer is to `scope` because triage and scope are sister steps within the same funnel. The other buckets point outward (`engineer`/`data` agents) or back (requester).

## The Triage Artifact

Bounded and short — a fast routing decision, not a document. Render it inline.

| Section | Cap | Purpose |
|---|---|---|
| **Request Summary** | 1–3 sentences | Restate the inbound request in neutral terms |
| **Classification** | 1 line | The bucket (Product shaping / Engineering / Data / Needs more info / Not actionable) |
| **Rationale** | 1–3 bullets | Why this bucket |
| **Recommended Next Step** | 1 line | The concrete pointer (e.g. "→ run `scope`", "→ hand to `engineer` agent", "→ hand to `data` agent") |
| **Signals & Unknowns** | bullets | What is known vs. missing; for **Needs more info**, the specific questions to ask back |
| **Urgency / Notes** | optional, 1–2 lines | Time-sensitivity or caveats worth flagging |

## Self-Check (Quick)

Before presenting, scan for these and correct:

1. **Multi-classification** — the request actually contains several distinct asks that belong in different buckets. Say so, and triage each ask (or recommend splitting them at the source). Do not force one bucket.
2. **Doing scope's job** — the artifact has drifted into requirements detail or estimation. Trim back to classification + pointer.
3. **Hedged classification** — no clear bucket chosen. Pick one, or use **Needs more info** with explicit questions. Do not present an ambiguous routing.

## Persistence

**Inline-only.** Triage is a fast, throwaway routing decision — render the artifact in the conversation and stop. Do not write a file. If the request routes into the product funnel, the durable record begins at `scope`; triage's job is done the moment it points.

## Next Step

The artifact's **Recommended Next Step** is itself the pointer — a human carries the request to the named destination. Triage **never invokes** another agent or skill; it only recommends.

## Key Principles

- Fast and single-pass — classify and point, don't shape
- Exactly one bucket per ask (split multi-ask requests)
- Pointer, not action — recommend a destination; a human carries it across
- Product shaping routes to `scope`; everything else points outward or back
- Inline-only — no file; the funnel's durable record starts at `scope`
- Stand-alone — never invoke another agent or skill
