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

## Routing Destinations & Explicit Criteria

Classify the inbound request into **exactly one** of these 5 destinations based on explicit criteria:

### 1. Product Shaping (`scope`)
- **Explicit Criteria:**
  - New user-facing capabilities, feature additions, or product workflow changes.
  - Problem statements where functional requirements, boundaries, or user experiences are not yet settled.
  - High ambiguity on the *what* or *why*, requiring stakeholder dialogue to establish needs and outcomes.
- **Recommended Next Step:** → run the `scope` skill (the product work-shaping funnel's intake step).

### 2. Engineering Direct (`engineer`)
- **Explicit Criteria:**
  - Already well-specified technical tasks with defined scopes and interfaces.
  - Bug reports with reproducible steps, observed vs. expected behavior, where the "what" and "why" are clear and undisputed.
  - Trivial fixes, dependency updates, typo corrections, or direct code refactorings that require zero product discovery.
- **Recommended Next Step:** → hand to the `engineer` agent (Path A trivial change, Path B parallel tasks, or Path C full lifecycle).

### 3. Data Pipeline (`data`)
- **Explicit Criteria:**
  - Extracting, cleaning, and normalizing raw datasets from files (PDF, XLSX, CSV, JSON, HTML).
  - Quantitative analysis, metrics calculations, trend identification, cohort comparisons, or distribution anomaly checks.
  - Generating structured reports, summaries, charts, or export tables from data sources.
- **Recommended Next Step:** → hand to the `data` agent (ingest → analyze → report pipeline).

### 4. Needs-Info (`requester`)
- **Explicit Criteria:**
  - The request is too vague, fragmented, or empty to evaluate actionability or determine destination.
  - Missing essential context (e.g. system name, user role, environment) without which any classification is pure speculation.
  - Critical questions must be explicitly listed so the requester knows exactly what information is required.
- **Recommended Next Step:** → bounce back to the requester with the specific questions listed.

### 5. Not-Actionable (`reject / defer`)
- **Explicit Criteria:**
  - Completely out of scope for the product or organization.
  - Exact duplicate of an already active or recently completed work item.
  - Contradictory, infeasible, or obsolete proposals.
- **Recommended Next Step:** → reject or defer with a concise, one-line technical or policy rationale.

| Bucket | Destination | Explicit Trigger Criteria | Recommended Next Step |
|---|---|---|---|
| **Product shaping** | `skills/scope` | Feature/workflow change needing requirements discovery; unsettled boundaries | → run the `scope` skill |
| **Engineering Direct** | `engineer` agent | Well-specified task, clear bug fix, or trivial refactor; zero product discovery | → hand to the `engineer` agent |
| **Data Pipeline** | `data` agent | File ingestion, normalization, quantitative analysis, or reporting | → hand to the `data` agent |
| **Needs-Info** | Requester | Missing critical context needed to classify; request too fragmented or vague | → bounce back with specific questions |
| **Not-Actionable** | Reject / Defer | Out of scope, duplicate request, obsolete, or fundamentally contradictory | → reject/defer with one-line reason |

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

## Red Flags & Common Rationalizations

Watch out for these anti-patterns and shortcuts during triage:

**Never:**
- Route to Engineering when requirements or user experience boundaries are still unresolved.
- Run `scope` on a trivial 1-line bug or typo that has clear reproduction and fix.
- Start gathering deep requirements, designing solutions, or estimating effort in triage.
- Emit a hedged classification ("it could be engineering or product shaping").
- Guess what a vague request meant instead of routing to Needs-Info.
- Fabricate a hybrid bucket for a request with multiple asks instead of splitting it.

### Common Rationalizations

| Rationalization / Thought | Reality |
|---|---|
| "I can just quickly sketch out requirements while triaging" | Triage is a fast front door, not a shaping session. Shaping without proper scope structure leads to premature commitments and bloat. |
| "It sounds technical, so send it straight to engineering" | Technical-sounding asks often conceal unresolved UX, permissions, or scope boundaries. If requirements are unsettled, route to Product Shaping. |
| "The request is short, so it must be a simple engineering task" | Brevity does not equal simplicity. "Add OAuth support" is 3 words but massive product and architectural work. Route by clarity and settled requirements, not word count. |
| "I'll guess what they meant instead of asking for more info" | Guessing routes requests to the wrong agents or triggers wasted work. If critical context is missing, route to Needs-Info with targeted questions. |
| "This request touches multiple domains, so I'll invent a hybrid route" | Split multi-ask requests into distinct items and triage each individually to its appropriate destination. |

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
