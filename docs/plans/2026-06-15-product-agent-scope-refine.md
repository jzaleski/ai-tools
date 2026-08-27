# Product Agent + Scope/Refine Skills Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps. This is a docs/config repo (Markdown skill/agent definitions). There is no test suite or TDD; "verification" means convention checks and repo-wide reference searches. Use the `rg` (ripgrep) command for searches, not `grep`.

**Goal:** Add a product-side work-shaping funnel (`scope` → `refine` skills + `product` agent) and rename the `analyst` agent to `data` for naming consistency.

**Architecture:** Two new local skills under `home/.config/opencode/skills/` (`scope`, `refine`) following the standard `SKILL.md` + frontmatter convention; one new thin `primary` agent `home/.config/opencode/agents/product.md` wrapping both skills; rename `analyst.md` → `data.md`; update cross-references in `engineer.md`, `AGENTS.md`, and `README.md`.

**Tech Stack:** Markdown with YAML frontmatter. No code, no build, no dependencies.

**Design doc:** `docs/specs/2026-06-15-product-agent-scope-refine-design.md`

**Repo convention note:** `docs/` is gitignored — design/plan artifacts are local-only and NOT committed. Commits apply only to deliverable files under `home/.config/opencode/`, `AGENTS.md`, and `README.md`. Work happens on branch `add-product-agent-scope-refine-skills` (already created).

---

## File Structure Mapping

| File | Action | Responsibility |
|---|---|---|
| `home/.config/opencode/skills/scope/SKILL.md` | Create | Stakeholder intake skill |
| `home/.config/opencode/skills/refine/SKILL.md` | Create | Technical-PM maturation skill |
| `home/.config/opencode/agents/product.md` | Create | Product persona agent wrapping both skills |
| `home/.config/opencode/agents/analyst.md` → `data.md` | Rename + edit | Data pipeline agent (rename only) |
| `home/.config/opencode/agents/engineer.md` | Modify | 2 `analyst` → `data` references |
| `AGENTS.md` | Modify | Rename refs, agent count → 3, diagram, skills list |
| `README.md` | Modify | Rename refs, agent count → 3, diagrams, tables, usage |

---

### Task 1: Create the `scope` skill

**Files:**
- Create: `home/.config/opencode/skills/scope/SKILL.md`

- [ ] **Step 1: Create the skill file with full content**

Write `home/.config/opencode/skills/scope/SKILL.md` with exactly this content:

```markdown
---
name: scope
description: "Stakeholder requirements-intake skill — turns a vague or bloated request into a right-sized, refinable scope artifact. Adaptive: asks a few high-leverage questions when input is too thin, drafts-and-trims when too bloated. Honest about what a non-technical stakeholder cannot know. Stand-alone; does not hand off to other agents."
---

# Scope Skill

Turn a stakeholder's request into a **right-sized, refinable scope artifact** that a product/client-manager can clearly understand, react to, and refine — the first stage of the product work-shaping funnel.

**Always announce at start:** "I'm using the scope skill to shape this request."

**Audience:** product/client-managers — typically non-technical. Never force the stakeholder to author things they cannot know (system internals, authoritative technical scope, effort/complexity). Those belong to the `refine` skill.

## The Problem This Solves

Stakeholders swing between **under-specification** (1–2 sentences, not actionable) and **over-specification** (many pages that ignore the real system). This skill enforces **right-sized friction**: enough structure to be actionable and honest, light enough that people actually use it.

## Adaptive Intake

Detect which failure mode the input represents and respond accordingly:

- **Too thin** → ask a **capped set of high-leverage clarifying questions**: at most **3–5**, asked **one at a time**, stopping early once the input is actionable. Never an interrogation.
- **Too bloated** → skip questioning; go straight to **draft-and-trim**.
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
```

- [ ] **Step 2: Verify frontmatter convention matches siblings**

Run: `head -4 home/.config/opencode/skills/scope/SKILL.md`
Expected: a `---` fenced block with `name: scope` and a quoted `description:` line, matching the format of the other skills (e.g., `ingest`, `reviewer`).

- [ ] **Step 3: Verify no forbidden forward-handoff language slipped in**

Run: `rg -n "invoke|hand off|handoff|dispatch" home/.config/opencode/skills/scope/SKILL.md`
Expected: matches only in the "never invokes / not a handoff" clarifying context — confirm none instruct the skill to actually call another agent.

- [ ] **Step 4: Commit**

```bash
git add home/.config/opencode/skills/scope/SKILL.md
git commit -m "feat: add scope skill (stakeholder requirements intake)"
```

---

### Task 2: Create the `refine` skill

**Files:**
- Create: `home/.config/opencode/skills/refine/SKILL.md`

- [ ] **Step 1: Create the skill file with full content**

Write `home/.config/opencode/skills/refine/SKILL.md` with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify frontmatter convention matches siblings**

Run: `head -4 home/.config/opencode/skills/refine/SKILL.md`
Expected: a `---` fenced block with `name: refine` and a quoted `description:` line.

- [ ] **Step 3: Verify the in-place / same-file rule is present**

Run: `rg -n "same document|same .*file|in place" home/.config/opencode/skills/refine/SKILL.md`
Expected: at least the "Augment the SAME document in place" and persistence "same ... file ... in place" matches.

- [ ] **Step 4: Commit**

```bash
git add home/.config/opencode/skills/refine/SKILL.md
git commit -m "feat: add refine skill (technical-PM scope maturation)"
```

---

### Task 3: Create the `product` agent

**Files:**
- Create: `home/.config/opencode/agents/product.md`

- [ ] **Step 1: Create the agent file with full content**

Write `home/.config/opencode/agents/product.md` with exactly this content:

```markdown
---
description: Product persona — shapes work before engineering. Runs the scope skill to capture a stakeholder's requirements as a right-sized artifact, then the refine skill to mature it (with engineering) into a ticket-ready brief. Stand-alone; produces artifacts, never writes code or hands off automatically. No external dependencies.
mode: primary
---

# Product Agent

You are a product persona — a product/client-manager's front door for **shaping work** before it reaches engineering. Your job is to turn fuzzy or bloated requests into **right-sized, system-aware, ticket-ready artifacts** that a human can carry forward. You produce artifacts; you do not write code, manage git workflow, or hand off automatically to other agents.

You own the front of the work-shaping funnel via two local skills:

| Stage | Skill | What it does |
|---|---|---|
| 1. Scope | `skills/scope` | Capture a stakeholder's request as a right-sized, refinable scope artifact — honest about what they cannot know |
| 2. Refine | `skills/refine` | Mature that scope (with engineering) into a system-aware, ticket-ready brief by augmenting the same document |

```
Stakeholder              Technical PM (+ engineering)        Engineering
─────────────            ────────────────────────────       ───────────
scope skill        →     refine skill                   →    engineer agent
(intake, honest          (system-aware, authoritative        (researcher →
 about unknowns)          scope, complexity, ticket-ready)     planner → ...)
```

## Pre-Work (Opportunistic, Not Mandatory)

Attempt to read the project's `AGENTS.md` at the repo root for project-specific context and conventions. If it doesn't exist, proceed without it — this is informational context, not a hard gate.

## Which Skill to Run

- **New or vague request from a stakeholder** → run `skills/scope`. This is the default entry point.
- **An existing scope artifact that needs technical maturation** (system considerations, authoritative scope, complexity, ticket breakdown) → run `skills/refine`.
- If unsure which stage the request is at, ask one clarifying question before loading a skill.

Load the chosen skill inline via the skill tool — both skills are interactive (they dialogue with the user). Follow the skill's instructions exactly, including its environment-adaptive persistence rules.

## Audience

Your audience is product/client-managers — typically **non-technical**. Frame everything for them. Do not leak engineering-flavored triage (code paths, build steps) into the experience. The `scope` skill is explicitly built to avoid forcing them to author things they cannot know.

## What You Do NOT Do

- **Do not write code** — you shape work; you do not implement it. (That is the `engineer` agent's job.)
- **Do not manage git** — no branches, commits beyond what a skill's in-repo persistence step performs, or PRs.
- **Do not hand off automatically** — the scope and refine artifacts end with a *pointer* to the next stage, but a human carries the work across. You never invoke `engineer` or `data`.
- **Do not fabricate technical detail** — if the stakeholder cannot know something, surface it as an open question for refinement.
- **Do not produce engineering specs** — no file paths, task decomposition, or implementation detail. The artifact guides engineering; it is not the plan.

## External Dependencies

**Zero.** Both skills are local to this repository under `skills/`. No external git plugins, no runtime fetches. If any third-party project disappears tomorrow, this agent continues working identically.
```

- [ ] **Step 2: Verify frontmatter matches the other primary agents**

Run: `head -4 home/.config/opencode/agents/product.md`
Expected: a `---` block with a `description:` line and `mode: primary` (same shape as `engineer.md` and the renamed `data.md`).

- [ ] **Step 3: Verify no auto-handoff instruction leaked in**

Run: `rg -n "invoke|hand off|handoff" home/.config/opencode/agents/product.md`
Expected: matches only in the negative ("Do not hand off automatically", "never invoke") — confirm none instruct the agent to call another agent.

- [ ] **Step 4: Commit**

```bash
git add home/.config/opencode/agents/product.md
git commit -m "feat: add product agent (work-shaping persona)"
```

---

### Task 4: Rename `analyst` agent to `data`

**Files:**
- Rename: `home/.config/opencode/agents/analyst.md` → `home/.config/opencode/agents/data.md`
- Modify: the renamed file's heading and frontmatter

- [ ] **Step 1: Rename the file via git**

```bash
git mv home/.config/opencode/agents/analyst.md home/.config/opencode/agents/data.md
```

- [ ] **Step 2: Update the heading**

In `home/.config/opencode/agents/data.md`, change line 6:
- From: `# Analyst Agent`
- To: `# Data Agent`

- [ ] **Step 3: Verify the role prose is intact and only the agent name changed**

Run: `rg -n "Analyst|analyst" home/.config/opencode/agents/data.md`
Expected: **exactly one match — line 8 only**, the role-prose phrase "senior data analyst and pipeline orchestrator". That is a job-title phrase describing the role, not the agent name — leave it as-is. There must be NO `# Analyst Agent` heading and NO other `analyst`/`Analyst` references. If anything other than line 8 matches, fix it.

Note: the frontmatter `description:` on line 2 describes the pipeline ("Data pipeline orchestrator…") and does not contain the word "analyst" — confirm it is unchanged and accurate.

- [ ] **Step 4: Commit**

```bash
git add home/.config/opencode/agents/data.md
git commit -m "refactor: rename analyst agent to data"
```

---

### Task 5: Update `engineer.md` references

**Files:**
- Modify: `home/.config/opencode/agents/engineer.md` (2 references)

- [ ] **Step 1: Update the scope-triage redirect row**

In `home/.config/opencode/agents/engineer.md`, line 71, change:
- From: `| Data analysis / report generation / data wrangling | **Redirect → \`analyst\` agent** (suggest to user and stop) |`
- To: `| Data analysis / report generation / data wrangling | **Redirect → \`data\` agent** (suggest to user and stop) |`

- [ ] **Step 2: Update the "What You Do NOT Do" line**

In `home/.config/opencode/agents/engineer.md`, line 242, change:
- From: `- **Do not take on data analysis / report generation work** — redirect the user to the \`analyst\` agent.`
- To: `- **Do not take on data analysis / report generation work** — redirect the user to the \`data\` agent.`

- [ ] **Step 3: Verify no stale references remain in engineer.md**

Run: `rg -n "analyst" home/.config/opencode/agents/engineer.md`
Expected: **no matches.**

- [ ] **Step 4: Commit**

```bash
git add home/.config/opencode/agents/engineer.md
git commit -m "refactor: update engineer agent references for analyst->data rename"
```

---

### Task 6: Update `AGENTS.md`

**Files:**
- Modify: `AGENTS.md` (3 text references + 1 ASCII diagram + skills list)

- [ ] **Step 1: Update the agent-config list (line ~16) and add product**

In `AGENTS.md`, replace the analyst bullet and add a product bullet. Change:
- From:
```
- **analyst.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
```
- To:
```
- **data.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
- **product.md**: Work-shaping persona — runs the scope skill to capture a stakeholder's requirements as a right-sized artifact, then the refine skill to mature it (with engineering) into a ticket-ready brief; produces artifacts, never writes code or hands off automatically
```

- [ ] **Step 2: Update the skills-vendored sentence**

In `AGENTS.md`, find the sentence:
```
Workflow skills are vendored locally under `home/.config/opencode/skills/`. The engineering lifecycle uses researcher, planner, coder, reviewer, and finisher; the data pipeline uses ingest, analyze, and report. No external plugin dependencies.
```
Change it to:
```
Workflow skills are vendored locally under `home/.config/opencode/skills/`. The engineering lifecycle uses researcher, planner, coder, reviewer, and finisher; the data pipeline uses ingest, analyze, and report; the product funnel uses scope and refine. No external plugin dependencies.
```

- [ ] **Step 3: Update the project-structure tree comments**

In `AGENTS.md`, in the project-structure code block, change the agents and skills comment lines. Change:
- From: `│   │   ├── agents/                        # Agent definitions (analyst, engineer)`
- To: `│   │   ├── agents/                        # Agent definitions (data, engineer, product)`

And change:
- From: `│   │   ├── skills/                        # Vendored workflow skills (analyze, coder, finisher, ingest, planner, report, researcher, reviewer)`
- To: `│   │   ├── skills/                        # Vendored workflow skills (analyze, coder, finisher, ingest, planner, refine, report, researcher, reviewer, scope)`

- [ ] **Step 4: Update the default-agent sentence (line ~18)**

In `AGENTS.md`, find:
```
Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `engineer`.
```
This line is correct as-is (default stays `engineer`) — leave it unchanged. (Listed here so the implementer does not "fix" it.)

- [ ] **Step 5: Update the "two custom agents" sentence (line ~172)**

In `AGENTS.md`, change:
- From: `\`opencode.json\` disables the default \`opencode\` and \`openai\` providers via \`disabled_providers\`. The built-in \`build\` and \`plan\` agents are also disabled — only the two custom agents (\`analyst\`, \`engineer\`) are active.`
- To: `\`opencode.json\` disables the default \`opencode\` and \`openai\` providers via \`disabled_providers\`. The built-in \`build\` and \`plan\` agents are also disabled — only the three custom agents (\`data\`, \`engineer\`, \`product\`) are active.`

- [ ] **Step 6: Update the Opencode Agent Architecture ASCII diagram**

In `AGENTS.md`, the architecture diagram has an `Analyst` box. Replace the box content and add a `Product` box. Change the diagram block:
- From:
```
│ ┌──────────────┐ │
│ │ Analyst      │ │
│ │ [pipeline:   │ │
│ │  ingest →    │ │
│ │  analyze →   │ │
│ │  report]     │ │
│ └──────────────┘ │
└─────────┬────────┘
```
- To:
```
│ ┌──────────────┐ │
│ │ Data         │ │
│ │ [pipeline:   │ │
│ │  ingest →    │ │
│ │  analyze →   │ │
│ │  report]     │ │
│ └──────────────┘ │
│                  │
│ ┌──────────────┐ │
│ │ Product      │ │
│ │ [funnel:     │ │
│ │  scope →     │ │
│ │  refine]     │ │
│ └──────────────┘ │
└─────────┬────────┘
```

- [ ] **Step 7: Verify no stale references remain in AGENTS.md**

Run: `rg -n "analyst|Analyst" AGENTS.md`
Expected: **no matches.**

Run: `rg -n "two custom agents" AGENTS.md`
Expected: **no matches** (should now say "three custom agents").

- [ ] **Step 8: Commit**

```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md for product agent + scope/refine skills + analyst->data rename"
```

---

### Task 7: Update `README.md`

**Files:**
- Modify: `README.md` (dir tree, agent-config list, skill tables, agent-roles table, ASCII diagram, usage, agent count)

- [ ] **Step 1: Update the project-structure dir tree (lines ~28-39)**

In `README.md`, change the agents subtree:
- From:
```
│   │   ├── agents/
│   │   │   ├── analyst.md          # Data pipeline orchestrator
│   │   │   └── engineer.md         # Adaptive software engineer (default)
```
- To:
```
│   │   ├── agents/
│   │   │   ├── data.md             # Data pipeline orchestrator
│   │   │   ├── engineer.md         # Adaptive software engineer (default)
│   │   │   └── product.md          # Work-shaping persona (scope → refine)
```

And in the same tree, update the skills list to add `refine/` and `scope/` in alphabetical order:
- From:
```
│   │   ├── skills/                 # Vendored workflow skills (no external plugins)
│   │   │   ├── analyze/            # Find patterns / answer questions (pipeline stage 2)
│   │   │   ├── coder/              # Sub-agent implementer (TDD, self-review)
│   │   │   ├── finisher/           # Verify, merge/PR, cleanup
│   │   │   ├── ingest/             # Extract + clean + normalize raw files (pipeline stage 1)
│   │   │   ├── planner/            # Task decomposition + independence analysis
│   │   │   ├── report/             # Deliver findings in one+ formats (pipeline stage 3)
│   │   │   ├── researcher/         # Design & discovery (approval-gated)
│   │   │   └── reviewer/           # Spec compliance + code quality review
```
- To:
```
│   │   ├── skills/                 # Vendored workflow skills (no external plugins)
│   │   │   ├── analyze/            # Find patterns / answer questions (pipeline stage 2)
│   │   │   ├── coder/              # Sub-agent implementer (TDD, self-review)
│   │   │   ├── finisher/           # Verify, merge/PR, cleanup
│   │   │   ├── ingest/             # Extract + clean + normalize raw files (pipeline stage 1)
│   │   │   ├── planner/            # Task decomposition + independence analysis
│   │   │   ├── refine/             # Mature a scope into a ticket-ready brief (product stage 2)
│   │   │   ├── report/             # Deliver findings in one+ formats (pipeline stage 3)
│   │   │   ├── researcher/         # Design & discovery (approval-gated)
│   │   │   ├── reviewer/           # Spec compliance + code quality review
│   │   │   └── scope/              # Stakeholder requirements intake (product stage 1)
```

- [ ] **Step 2: Update the agent-config list (lines ~107-108)**

In `README.md`, change:
- From:
```
- **analyst.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
```
- To:
```
- **data.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
- **product.md**: Work-shaping persona — runs the scope skill to capture a stakeholder's requirements as a right-sized artifact, then the refine skill to mature it (with engineering) into a ticket-ready brief
```

- [ ] **Step 3: Add a product-funnel skills table and rename the data-pipeline heading (lines ~126-132)**

In `README.md`, change the data-pipeline heading line:
- From: `**Data pipeline** (orchestrated by \`analyst\`):`
- To: `**Data pipeline** (orchestrated by \`data\`):`

Then, immediately after the data-pipeline skills table (after the `report` row and its closing, before the `## Environment Variables` section), add:
```

**Product funnel** (orchestrated by `product`):

| Skill | Purpose |
|-------|---------|
| `scope` | Stakeholder requirements intake — adaptive (capped questions when thin, draft-and-trim when bloated), produces a right-sized, refinable scope artifact; honest about what a non-technical stakeholder cannot know |
| `refine` | Technical-PM maturation — augments the same scope document with system considerations, authoritative scope, complexity, resolved open questions, and a ticket breakdown |
```

- [ ] **Step 4: Update the Opencode CLI ASCII diagram (lines ~252-258)**

In `README.md`, change the `Analyst` box and add a `Product` box:
- From:
```
│  ┌────────────────┐  │
│  │ Analyst        │  │
│  │ [pipeline:     │  │
│  │  ingest →      │  │
│  │  analyze →     │  │
│  │  report]       │  │
│  └────────────────┘  │
└──────────┬───────────┘
```
- To:
```
│  ┌────────────────┐  │
│  │ Data           │  │
│  │ [pipeline:     │  │
│  │  ingest →      │  │
│  │  analyze →     │  │
│  │  report]       │  │
│  └────────────────┘  │
│                      │
│  ┌────────────────┐  │
│  │ Product        │  │
│  │ [funnel:       │  │
│  │  scope →       │  │
│  │  refine]       │  │
│  └────────────────┘  │
└──────────┬───────────┘
```

- [ ] **Step 5: Update the Agent Roles table (lines ~294-297)**

In `README.md`, change the analyst row and add a product row:
- From:
```
| engineer | primary (default) | Adaptive scope triage — handles trivial changes directly (Path A), dispatches parallel coders for multi-file work (Path B), or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger/ambiguous features (Path C) | Path A/B: working tree (may commit if clearly safe on Path A); Path C: feature branch with commits/PR |
| analyst | primary | Data pipeline orchestration — parallel ingestion of multi-format inputs, normalization, analysis, report generation | Report in user-specified format |
```
- To:
```
| engineer | primary (default) | Adaptive scope triage — handles trivial changes directly (Path A), dispatches parallel coders for multi-file work (Path B), or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger/ambiguous features (Path C) | Path A/B: working tree (may commit if clearly safe on Path A); Path C: feature branch with commits/PR |
| data | primary | Data pipeline orchestration — parallel ingestion of multi-format inputs, normalization, analysis, report generation | Report in user-specified format |
| product | primary | Work-shaping funnel — scope (stakeholder intake) then refine (technical-PM maturation into a ticket-ready brief) | Right-sized scope artifact (rendered inline; evolves in place in-repo) |
```

- [ ] **Step 6: Update the "two custom agents" sentence (line ~301)**

In `README.md`, change:
- From: `The \`build\` and \`plan\` agents that ship with opencode are disabled in \`opencode.json\` — only the two custom agents above are active.`
- To: `The \`build\` and \`plan\` agents that ship with opencode are disabled in \`opencode.json\` — only the three custom agents above are active.`

- [ ] **Step 7: Update the usage examples (lines ~324-325)**

In `README.md`, change:
- From:
```
opencode --agent engineer "implement this feature"
opencode --agent analyst "analyze this data file"
```
- To:
```
opencode --agent engineer "implement this feature"
opencode --agent data "analyze this data file"
opencode --agent product "scope this feature request"
```

- [ ] **Step 8: Verify no stale references remain in README.md**

Run: `rg -n "analyst|Analyst" README.md`
Expected: **no matches.**

Run: `rg -n "two custom agents" README.md`
Expected: **no matches.**

- [ ] **Step 9: Commit**

```bash
git add README.md
git commit -m "docs: update README for product agent + scope/refine skills + analyst->data rename"
```

---

## Parallel Dispatch Analysis

### Batch 1 (independent — dispatch together):
- **Task 1** (`skills/scope/SKILL.md` — create) + **Task 2** (`skills/refine/SKILL.md` — create) + **Task 3** (`agents/product.md` — create) + **Task 4** (rename `analyst.md` → `data.md`)
  Rationale: Four disjoint file sets. Tasks 1–3 create brand-new files that touch nothing else. Task 4 renames+edits only its own file. No shared files, no cross-dependencies, no ordering constraint among them.

### Batch 2 (depends on Batch 1):
- **Task 5** (`engineer.md`) + **Task 6** (`AGENTS.md`) + **Task 7** (`README.md`)
  Rationale: These three touch disjoint files and are mutually independent, so they parallelize with each other. They are placed in Batch 2 only because their content *describes* the artifacts created/renamed in Batch 1 (the `data` agent name, the `product` agent, the `scope`/`refine` skills). Sequencing them after Batch 1 keeps the documentation describing things that already exist, which makes the final cross-batch reference verification meaningful. They have no hard code-level dependency, but this ordering is correct for review.

### Notes:
- No `opencode.json` change in any task (by design — custom agents are file-discovered; `default_agent` stays `engineer`).
- Final cross-cutting verification (after Batch 2): `rg -n "analyst|Analyst" .` over the whole repo should return **no matches** except possibly the role-prose phrase "data analyst" inside `agents/data.md` line 8 (acceptable — that is a job-title phrase, not the agent name). The finisher will run this as the test-equivalent gate.
