# Product Agent + Scope/Refine Skills — Design

**Date:** 2026-06-15
**Status:** Approved-pending
**Author:** researcher (engineer agent, Path C)

## 1. Overview & Goals

This effort extends the opencode agent/skill toolset with a **product-side
work-shaping funnel** and aligns the agent naming taxonomy.

We are delivering three things:

1. A new **`scope` skill** — a stand-alone, adaptive requirements-intake/triage
   skill authored by a (typically non-technical) stakeholder. It produces a
   right-sized, refinable scope artifact and is honest about what the
   stakeholder cannot know. It does **not** route or hand off to other agents.
2. A new **`refine` skill** — the technical product manager's tool. It takes a
   stakeholder scope artifact and matures it (in collaboration with engineering)
   into a system-aware, ticket-ready brief by augmenting the *same* document.
3. A new **`product` agent** — a thin product-persona primary agent (peer to
   `engineer` and the renamed `data`) that wraps both the `scope` and `refine`
   skills.

Alongside these additions, we **rename the `analyst` agent to `data`** so the
three primary agents form a consistent discipline-named persona trio:
`engineer` / `product` / `data`.

### Problem Being Solved

Stakeholders oscillate between **under-specification** (1–2 sentence scopes that
are not actionable) and **over-specification** (15-page dumps that ignore the
boundaries of the real system). Neither is usable by engineering. The funnel
enforces **right-sized friction**: enough structure to be actionable and honest,
light enough that people actually use it.

### The Funnel

```
Stakeholder              Technical PM (+ engineering)        Engineering
─────────────            ────────────────────────────       ───────────
scope skill        →     refine skill                   →    researcher → planner → ...
(intake, honest          (system-aware, authoritative        (engineer agent
 about unknowns)          scope, complexity, ticket-ready)     lifecycle)
```

Neither `scope` nor `refine` writes code or auto-invokes another agent. A human
carries the work across each boundary. Each skill ends with a *pointer* to the
next stage, not a handoff.

## 2. The `scope` Skill

**Location:** `home/.config/opencode/skills/scope/SKILL.md`
(standard `SKILL.md` + frontmatter convention; portable as a Claude org skill).

**Audience:** product/client-managers — typically non-technical. The skill must
never force them to author things they cannot know (system internals, true
technical scope boundaries, effort/complexity).

### Behavior — Adaptive Intake

The skill detects which failure mode the input represents and responds
accordingly:

- **Too thin** → ask a **capped set of high-leverage clarifying questions**:
  at most **3–5**, asked **one at a time**, stopping early once the input is
  actionable. Never an interrogation.
- **Too bloated** → skip questioning; go straight to **draft-and-trim**.

After drafting, run a **right-sizing self-calibration pass** against explicit
anti-patterns (too vague / too detailed / not actionable / too big → should
split / forces details the stakeholder cannot know). Trim or flag, then present.

**Refinement loop:** present the digestible artifact, invite the stakeholder to
react and refine, iterate until they are satisfied.

### The Artifact — Bounded, Stakeholder-Honest Template

Biased short. Right-sizing rule: if the filled template does not comfortably fit
roughly **one page**, the scope is too big → recommend splitting into multiple
tickets rather than growing the document. Splitting is reserved for
genuinely-too-big, not hair-splitting.

| Section | Cap | Purpose |
|---|---|---|
| **Problem / Need** | 2–4 sentences | What is needed and why, in plain language |
| **Desired Outcome** | 2–4 bullets | What "good" looks like from the stakeholder's POV — the goal, not the implementation |
| **Boundaries (as understood)** | bullets, optional | What they *believe* is in/out — explicitly framed as their understanding, NOT authoritative scope |
| **Success Criteria** | bullets | How they will know it is working / what they would check |
| **Open Questions & Unknowns** | bullets | Things they do not know, including explicit "needs technical input" flags |
| **Shape** | 1–2 lines + optional split note | Does this feel like one cohesive need or several distinct asks, and where does it sit relative to what already exists? (NO complexity/effort — that requires a technical basis the stakeholder lacks.) |

**Deliberately excluded** (these belong to `refine`, authored by someone
equipped to judge):
- System Considerations / technical constraints
- Authoritative In Scope / Out of Scope
- Complexity / effort estimation

**Honesty principle:** "Open Questions & Unknowns" is a first-class, *encouraged*
section. The skill makes it safe and normal to say "I don't know X — this needs
technical input." Unanswerable-by-stakeholder details are a **signal to flag for
technical refinement**, never something to force or fabricate. The right-sizing
self-calibration pass treats forced/fabricated technical detail as an
anti-pattern to strip, not a gap to fill.

**Ticket orientation:** the artifact is framed so it can become one ticket (or N,
if split). It guides eventual implementation but is **not** an engineering spec —
no code, no file paths, no task decomposition.

**Forward pointer (no handoff):** the artifact ends with a one-liner:
> *Next step: technical refinement with engineering (see the `refine` skill).*

## 3. The `refine` Skill

**Location:** `home/.config/opencode/skills/refine/SKILL.md`
(standard `SKILL.md` + frontmatter convention; portable as a Claude org skill).

**Audience:** the **technical product manager**, working in collaboration with
engineering.

**Input:** an existing stakeholder scope artifact — the in-repo file at
`docs/scopes/YYYY-MM-DD-<topic>.md`, or an inline scope brief pasted in.

### Behavior

Collaborative and iterative — a working session between technical PM and
engineering, not a solo dump. Applies the **same right-sizing discipline** as
`scope` (bounded, anti-bloat, split rather than balloon) and runs its own
self-calibration pass.

**It augments the SAME document in place** (see §5 Persistence). It does not
create a parallel artifact. The stakeholder's original sections remain (git shows
what changed); `refine` layers technical maturation on top and resolves the open
questions inline.

### What `refine` Adds — The Pieces Kept Out of `scope`

- **System Considerations** — real constraints/boundaries of the existing system
  the work must respect.
- **Authoritative In Scope / Out of Scope** — now authored by someone equipped to
  judge; supersedes the stakeholder's soft "Boundaries (as understood)".
- **Complexity / Shape** — effort/size assessment with a technical basis;
  confirms or revises the stakeholder's shape intuition.
- **Resolved Open Questions** — walks the stakeholder's Unknowns list and
  resolves each: answered / needs-spike / deferred.
- **Ticket Breakdown** — splits into one or more ticket-ready items if
  shape/complexity warrant it.

**Forward pointer (no handoff):** the matured document ends with:
> *Ready for engineering — hand to the `engineer` agent to begin design/planning.*

## 4. The `product` Agent

**Location:** `home/.config/opencode/agents/product.md`
**Mode:** `primary` (peer to `engineer` and `data`).

**Scope (deliberately thin today):** two capabilities — run `scope` (intake) or
`refine` (maturation), depending on where the request sits in the funnel.
Structured so future capabilities slot in without a rewrite.

- **Audience framing:** product/client-managers — non-engineers. No code-path
  triage (unlike `engineer`).
- **Pre-work:** opportunistically read `AGENTS.md` if present (like `data`); not
  a hard gate.
- **Does NOT:** write code, manage git/branches/commits, or auto-invoke/hand off
  to `engineer`/`data`. It produces (and, in-repo, persists) the artifact and
  stops. A human decides what happens next.
- **`opencode.json`:** **no change required.** Custom agents are file-discovered;
  `default_agent` remains `engineer`. The `agent` block in `opencode.json` only
  disables the built-in `build`/`plan` agents and is left untouched.

## 5. Persistence (Environment-Adaptive)

**Inline rendering is the canonical output in every environment.** The artifact
is always rendered in-conversation — that is the deliverable.

| Environment | Mechanism |
|---|---|
| **In-repo (opencode)** | The artifact is a **single evolving file** at `docs/scopes/YYYY-MM-DD-<topic>.md`. `scope` creates/edits it; `refine` continues editing **the same file in place**. **Git history is the audit trail** — the scope→refined maturation appears as commits to one document. |
| **No repo (Claude org skill)** | **Inline only.** No file mechanics — the rendered artifact is what the user copies into their ticket/doc system. |

**Directory name:** `docs/scopes/` (plural) for consistency with the existing
`docs/specs/` and `docs/plans/` directories.

Each skill's instructions describe persistence as: always render inline; **if** a
repository working directory is available, also write/update the single
`docs/scopes/` file and commit; otherwise inline is the sole output.

## 6. The `analyst` → `data` Rename

Renames the data-pipeline agent for taxonomy consistency
(`engineer` / `product` / `data`). The agent's *role description* ("data
analyst / pipeline orchestrator") may remain in prose; only the **agent name**
becomes `data`.

**Files and references to change** (from full-repo survey — 11 `analyst` + 3
`Analyst` matches, plus new `product`/`scope`/`refine` additions):

1. **Rename** `home/.config/opencode/agents/analyst.md` → `data.md`:
   - Update the `# Analyst Agent` heading → `# Data Agent`.
   - Update the `description:` frontmatter (agent name reference).
   - Body self-references: the "senior data analyst and pipeline orchestrator"
     role phrasing may stay; ensure no stale *agent-name* references to
     `analyst`.

2. **`home/.config/opencode/agents/engineer.md`** — 2 references:
   - The redirect-table row: `Redirect → 'analyst' agent` → `'data' agent`.
   - The "What You Do NOT Do" line referencing the `analyst` agent → `data`.

3. **`AGENTS.md`** — 3 references + diagram + additions:
   - Agent list line (`analyst.md`) → `data.md`; add `product.md`.
   - Dir-tree comment `(analyst, engineer)` → `(data, engineer, product)`.
   - "two custom agents (`analyst`, `engineer`)" → **three**
     (`data`, `engineer`, `product`).
   - Architecture ASCII box `Analyst` → `Data`; add a `Product` box.
   - Skills list: add `scope` and `refine`.

4. **`README.md`** — multiple references + diagrams + additions:
   - Dir tree: `analyst.md` → `data.md`; add `product.md`; add `scope/` and
     `refine/` skill entries.
   - Agent-config list: `analyst.md` → `data.md`; add `product.md`.
   - "Data pipeline (orchestrated by `analyst`)" → `data`.
   - New skill grouping for the product funnel (`scope`, `refine`).
   - Agent-roles table: rename `analyst` row → `data`; add `product` row.
   - ASCII diagram: `Analyst` box → `Data`; add `Product` box.
   - Usage example: `opencode --agent analyst ...` → `data`; add a `product`
     example.
   - "two custom agents" phrasing → three.

## 7. Claude Org-Skill Portability

Both `scope` and `refine` use the standard `SKILL.md` + frontmatter (`name`,
`description`) convention used by all existing skills, so they import as Claude
organizational skills with no special handling. Persistence is
environment-adaptive (§5): the file-writing step is conditional on a repo working
directory, so the same skill behaves sensibly in opencode (file + git) and in
Claude (inline only). The `product` agent is opencode-specific (agents are not an
org-skill concept), but the reusable units — the two skills — travel cleanly.

## 8. Non-Goals

- No `opencode.json` changes; `default_agent` stays `engineer`.
- No auto-handoff or agent-to-agent invocation from `scope`/`refine`/`product`.
- No code, file paths, or task decomposition in the `scope`/`refine` artifacts
  (that is the engineer lifecycle's job).
- No change to the `analyst`/`data` agent's *behavior* — this is a rename only.
- No model/provider/tier changes.

## 9. Acceptance Criteria

1. `home/.config/opencode/skills/scope/SKILL.md` exists, follows the established
   skill conventions, implements adaptive intake (capped 3–5 questions / draft-
   and-trim), the bounded stakeholder-honest template (§2), the right-sizing
   self-calibration pass, environment-adaptive persistence (§5), and the
   forward pointer to `refine`.
2. `home/.config/opencode/skills/refine/SKILL.md` exists, follows conventions,
   takes a scope artifact, augments the same document in place with the §3
   sections, runs its self-calibration pass, and ends with the forward pointer to
   the `engineer` agent.
3. `home/.config/opencode/agents/product.md` exists as a thin `primary` agent
   wrapping both skills, with the constraints in §4.
4. `home/.config/opencode/agents/analyst.md` is renamed to `data.md` with all
   internal references updated.
5. `engineer.md`, `AGENTS.md`, and `README.md` reflect the rename and the new
   `product` agent + `scope`/`refine` skills, with agent counts updated to three
   and diagrams updated.
6. No `opencode.json` changes. `default_agent` remains `engineer`.
7. No stale `analyst` *agent-name* references remain anywhere in the repo
   (verified by repo-wide search).
