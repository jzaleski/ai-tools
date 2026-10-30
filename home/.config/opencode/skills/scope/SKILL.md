---
name: scope
description: "Use when a stakeholder or user has an idea or request — too vague or too broad — that needs to become a right-sized, refinable artifact."
---

# Scope Skill

Help a stakeholder or user, through a series of structured prompts, turn their ideas or requests into a **right-sized, refinable scope artifact** that a product/client-manager can clearly understand, react to, and refine — the first stage of the product work-shaping funnel.

**Always announce at start:** "I'm using the scope skill to shape this request."

**Audience:** product/client-managers — typically non-technical. Never force the stakeholder to author things they cannot know (system internals, authoritative technical scope, effort/complexity). Those belong to the `refine` skill.

## What This Helps With

A request can land anywhere on a spectrum — sometimes **not specific enough** (1–2 sentences, not yet actionable), sometimes **too broad** (many pages spanning several distinct asks). This skill provides **right-sized friction**: enough structure to be actionable and honest, light enough that people actually use it.

## Socratic Playback — Echoing Intent First

Before asking clarifying questions or drafting the artifact, immediately perform **Socratic playback** of the stakeholder's request:

1. **State the core problem and purpose in plain words (~2–3 sentences):**
   - What problem is the user or stakeholder experiencing?
   - What is the intended outcome, and why does it matter?
2. **Explicitly mark inferences and guesses:**
   - Any assumption about context, users, workflows, or boundaries that the stakeholder did not explicitly state must be flagged as a guess: `[Inferred / Guess: ...]`.
   - Never present inferences as established facts. Marking them as guesses builds trust and invites early course correction.
3. **Invite instant verification:**
   - Conclude playback with: *"Did I capture your core intent accurately, and are these guesses correct?"*

## Strict Boundary Enforcement: Capture What and Why, Keep Technical Details Out

<HARD-GATE>
The scope artifact captures WHAT problem needs solving and WHY it matters. It NEVER prescribes HOW to implement it.
</HARD-GATE>

### What Stays IN:
- **The user/business problem:** Who is experiencing friction, what that friction is, and why it matters.
- **Desired outcomes:** What observable success looks like from the stakeholder's perspective.
- **User expectations & constraints:** Business rules, timelines, user roles, non-technical constraints.
- **Honest unknowns:** Gaps in stakeholder knowledge explicitly surfaced and preserved.

### What Stays OUT (Strictly Excluded):
- **No implementation code or scripts:** Zero code snippets, pseudo-code, SQL queries, or file paths.
- **No system architecture or tech choices:** No database tables/schemas, caching strategies (Redis), message queues, or infrastructure decisions.
- **No API contracts or payloads:** No HTTP verbs, endpoints, request/response headers, or JSON schema definitions.
- **No complexity or effort estimation:** Stakeholders lack the technical basis to size effort. Sizing belongs strictly to `refine`.
- **No authoritative in/out scope:** Stakeholders express their *understanding* of boundaries ("Boundaries (as understood)"); technical PM and engineering establish authoritative scope in `refine`.

### Handling Stakeholder Technical Prescriptions:
Stakeholders frequently express needs disguised as technical solutions (e.g., *"We need a Postgres table and a Redis cache for user tags"*).
When this happens:
1. **Strip the implementation prescription:** Do not copy the technical solution into the scope artifact.
2. **Extract the underlying need:** Identify the actual functional requirement (e.g., *"Users need to tag items and retrieve tagged items instantly without noticeable lag"*).
3. **Capture technical suggestions as open questions:** Record the stakeholder's suggestion under **Open Questions & Unknowns** as a candidate for evaluation during refinement:
   - `[Needs technical input: evaluate data store and caching options for tag retrieval]`

## Adaptive Intake

Detect where the request sits on the spectrum and respond accordingly:

- **Not specific enough** → ask a **capped set of high-leverage clarifying questions**: at most **3–5**, asked **one at a time**, stopping early once the request is actionable. Never an interrogation.
- **Too broad** → skip questioning; go straight to **draft-and-trim**.
- **In between** → ask only what is genuinely missing (still capped at 3–5), then draft.

Prefer multiple-choice questions where possible; open-ended is fine. Focus questions on what the stakeholder *can* answer: the need, the desired outcome, how they'd know it worked.

## The Artifact — Bounded, Stakeholder-Honest Template

Bias short. Fill each section only as far as needed. The artifact should comfortably fit roughly **one page**.

| Section | Cap | Purpose |
|---|---|---|
| **Problem / Need** | 2–4 sentences | What is needed and why, in plain language |
| **Desired Outcome** | 2–4 bullets | What "good" looks like from the stakeholder's POV — the goal, not the implementation |
| **Boundaries (as understood)** | bullets, optional | What they *believe* is in/out — explicitly framed as their understanding, NOT authoritative scope |
| **Success Criteria** | bullets | How they will know it is working / what they would check |
| **Open Questions & Unknowns** | bullets | Things they do not know, including explicit "needs technical input" flags |
| **Shape** | 1–2 lines + optional split note | Does this feel like one cohesive need or several distinct asks, and where does it sit relative to what already exists? (NO complexity/effort — that requires a technical basis the stakeholder lacks.) |

**Encourage honesty about unknowns.** "Open Questions & Unknowns" is a first-class section. Make it safe and normal to say "I don't know X — this needs technical input." A surfaced unknown is a *success*, not a gap to fill.

**Deliberately excluded** (these belong to the `refine` skill, authored by someone equipped to judge):
- System Considerations / technical constraints
- Authoritative In Scope / Out of Scope
- Complexity / effort estimation

## Right-Sizing Self-Calibration Pass

After drafting, review the artifact against these anti-patterns and trim or flag before presenting:

1. **Too vague** — a section is so thin it is not actionable. Ask one more targeted question (within the 3–5 budget) or mark it an Open Question.
2. **Too detailed** — prose has ballooned past one page, or contains implementation detail. Trim aggressively.
3. **Forced technical detail** — the stakeholder (or you) fabricated system considerations, authoritative scope, or complexity. **Strip it** and convert to an Open Question flagged for technical input. Do not fabricate.
4. **Not actionable** — no clear outcome or success criteria. Resolve before presenting.
5. **Too big** — does not fit one page even after trimming, or "Shape" reveals several distinct asks. Recommend **splitting into multiple tickets** rather than growing the document. Reserve splitting for genuinely-too-big, not hair-splitting.

## Red Flags & Common Rationalizations

Watch out for these anti-patterns and shortcuts during scoping:

**Never:**
- Allow code, SQL, schemas, or file paths into the scope artifact.
- Accept a technical solution as the problem statement without uncovering the underlying need.
- Skip Socratic playback to jump straight into questioning or drafting.
- Present an unconfirmed assumption as a fact instead of marking it `[Inferred / Guess: ...]`.
- Estimate hours, story points, or technical complexity in this stage.

### Common Rationalizations

| Rationalization / Thought | Reality |
|---|---|
| "The stakeholder explicitly said 'Postgres', so I should specify a Postgres table" | Stakeholders often talk in solutions. Extract the data durability and query needs; let engineering decide the technology in `refine`. |
| "I know the codebase well, so I'll suggest the file paths now to be helpful" | Technical specifics in scope confuse non-technical stakeholders and constrain engineering exploration prematurely. |
| "Socratic playback feels redundant if the request was straightforward" | Playback confirms alignment before investing effort in drafting. It routinely catches hidden misunderstandings in simple-looking requests. |
| "I don't need to label guesses if they seem obvious" | Unlabeled inferences get codified into specifications as false requirements. Always label guesses explicitly. |
| "I'll estimate complexity so the stakeholder knows if it's feasible" | Sizing without engineering analysis is guesswork that misleads stakeholders. Sizing belongs strictly to `refine`. |

## Refinement Loop

Present the artifact, invite the stakeholder to react and refine, and iterate until they are satisfied. Re-run the self-calibration pass after meaningful changes.

## Persistence (Environment-Adaptive)

**Inline rendering is the canonical output in every environment** — always render the full artifact in the conversation. That is the deliverable.

Then, **only if a repository working directory is available** (e.g., running in opencode), also persist it as a single evolving file:

- Write/update `docs/scopes/YYYY-MM-DD-<topic>.md` (note the plural `scopes`, for consistency with `docs/specs/` and `docs/plans/`).
- Commit it so **git history is the audit trail**. The later `refine` stage edits this *same* file in place, so the scope→refined maturation shows up as commits to one document.
- If `docs/` is gitignored in the repo, keep the file as a local working artifact (still render inline).

**If no repository working directory is available** (e.g., a Claude organizational skill), inline is the sole output — the user copies it into their ticket/doc system. Do not attempt file mechanics.

## Ticket Orientation & Next Step

The artifact is framed so it can become one ticket (or N, if split). It guides eventual implementation but is **not** an engineering spec — no code, no file paths, no task decomposition.

Always end the artifact with this pointer (it is a pointer, not a handoff — this skill never invokes another agent):

> *Next step: technical refinement with engineering (see the `refine` skill).*

## Key Principles

- Right-sized friction — actionable and honest, but not onerous
- Cap clarifying questions at 3–5, one at a time
- Bias short; one page is the ceiling
- Never force or fabricate technical detail — surface it as an unknown
- Split when genuinely too big; do not balloon
- Stand-alone — render inline always, persist in-repo when possible, never hand off
