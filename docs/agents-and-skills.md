# Agents & Skills Reference

Comprehensive reference for the opencode agents and workflow skills vendored in
this repository under `home/.config/opencode/`. Everything here is **local** —
there are no external plugin dependencies. If any third-party project disappears
tomorrow, these agents and skills continue working identically.

- **Agents** live in `home/.config/opencode/agents/` and are selected with
  `opencode --agent <name>`. They are *orchestrators*: they triage an incoming
  request, decide how much ceremony it deserves, and drive a sequence of skills
  (and, where appropriate, parallel sub-agents) to completion.
- **Skills** live in `home/.config/opencode/skills/` and are loaded on demand via
  the `skill` tool. Each skill is a focused, single-responsibility unit of work
  with its own process, hard gates, and reporting format. Skills are either run
  *inline* (interactive, needs user dialogue) or dispatched as *sub-agents* (via
  the `task` tool with `subagent_type: general`).

There are **3 agents** and **13 skills**, organized into three workflows:

| Workflow | Agent | Skills |
|---|---|---|
| Engineering lifecycle | `engineer` | `researcher`, `planner`, `coder`, `debugging`, `reviewer`, `finisher` |
| Data pipeline | `data` | `ingest`, `analyze`, `report` |
| Product funnel | `product` | `triage`, `scope`, `refine`, `handoff` |

---

## Table of Contents

- [Agents](#agents)
  - [engineer](#agent-engineer)
  - [data](#agent-data)
  - [product](#agent-product)
- [Engineering Lifecycle Skills](#engineering-lifecycle-skills)
  - [researcher](#skill-researcher)
  - [planner](#skill-planner)
  - [coder](#skill-coder)
  - [debugging](#skill-debugging)
  - [reviewer](#skill-reviewer)
  - [finisher](#skill-finisher)
- [Data Pipeline Skills](#data-pipeline-skills)
  - [ingest](#skill-ingest)
  - [analyze](#skill-analyze)
  - [report](#skill-report)
- [Product Funnel Skills](#product-funnel-skills)
  - [triage](#skill-triage)
  - [scope](#skill-scope)
  - [refine](#skill-refine)
  - [handoff](#skill-handoff)
- [How Agents and Skills Fit Together](#how-agents-and-skills-fit-together)

---

## Agents

Agents are primary orchestrators. Each one owns a distinct workflow and never
does the other workflows' jobs: the engineer doesn't wrangle data, the data agent
doesn't touch application source, and the product agent doesn't write code or
manage git.

<a id="agent-engineer"></a>
### `engineer` — Adaptive Software Engineer (default agent)

**File:** `home/.config/opencode/agents/engineer.md` · **Mode:** primary (default)

An adaptive software engineer whose guiding principle is **match ceremony to
scope**. Rather than forcing every change through the same heavyweight process,
it triages each request up front and picks exactly one of three paths, promoting
to a heavier path only if scope grows mid-task.

**Pre-work checklist (mandatory):** read `AGENTS.md` at the repo root; bootstrap
one if it's missing and the work is non-trivial; assess scope to pick a path; and
for the full-lifecycle path, create a feature branch if currently on
`main`/`master`.

**Three paths:**

| Path | When | What happens | Output |
|---|---|---|---|
| **A — Direct** | Single file or same-subsystem trivial change (typo, small bugfix, config tweak) | Edits inline; runs `debugging` first if it's a bugfix; verifies with a fresh test/typecheck run | Working tree (may commit if clearly safe) |
| **B — Parallel Dispatch** | Multiple disconnected files/subsystems, clear requirements | Groups files by independence, dispatches parallel `coder` sub-agents, then verifies all changes inline | Working tree (no commit) |
| **C — Full Lifecycle** | Ambiguous, design-required, or large interdependent features | `researcher` → `planner` → parallel `coder` batches → `reviewer` ×2 → `finisher` | Feature branch with commits/PR |

**Core principles (all paths):** correctness over cleverness, strict typing
always, minimal dependency footprint, consistency with existing code, no silent
TODOs, and — critically — **verification before completion**: never claim
something passes without running the actual check in the current turn.

**Commit discipline:** Path A may commit low-risk self-contained changes; Path B
always leaves the multi-file diff in the working tree for review; Path C commits
on a feature branch via the `finisher` skill. Never pushes without an explicit
request; never force-pushes to `main`/`master`.

**Redirects:** data analysis / report generation work is redirected to the `data`
agent rather than handled directly.

<a id="agent-data"></a>
### `data` — Data Pipeline Orchestrator

**File:** `home/.config/opencode/agents/data.md` · **Mode:** primary

A senior data analyst that runs a clean, staged pipeline from raw input to
delivered output: **ingest → analyze → report**. It thinks in stages but
parallelizes *within* a stage whenever it pays off — especially ingestion, where
many input files can be extracted at once.

**The three stages:**

| Stage | Skill | What it does |
|---|---|---|
| 1. Ingest | `ingest` | Extract data from raw files, clean each, converge into one normalized dataset |
| 2. Analyze | `analyze` | Answer the question / find patterns in the clean dataset (convergence-gated, single-pass) |
| 3. Report | `report` | Deliver the findings in one or more user-specified formats |

**Parallelism (ingest stage only):** the agent matches the mechanism to the
scale using an escalation ladder — inline for a single file, an in-process pool
for a handful of same-format files, shell fan-out for mixed formats, and
sub-agent fan-out (one `task` worker per file) only for genuinely numerous or
heavy inputs. It owns the convergence: all ingest workers must finish before
normalization and analysis begin.

**Hard constraints:** never modifies application source code, never mutates raw
inputs (read-only), always asks for the output format if unspecified, never
silently installs packages, and documents everything it creates via the report's
mandatory Artifacts & Scripts section. It does **not** commit or create branches
— lifecycle management is the engineer's job.

<a id="agent-product"></a>
### `product` — Work-Shaping Persona

**File:** `home/.config/opencode/agents/product.md` · **Mode:** primary

A product/client-manager's front door for **shaping work before it reaches
engineering**. It turns vague or overly broad ideas into right-sized,
system-aware, ticket-ready artifacts that a human carries forward. It produces
artifacts; it never writes code, manages git, or hands off automatically to
another agent.

**The funnel — a triage front door plus three shaping stages:**

| Stage | Skill | What it does |
|---|---|---|
| 0. Triage | `triage` | Classify an inbound request and route it (product shaping / engineering / data / needs-info / not-actionable) |
| 1. Scope | `scope` | Capture a stakeholder's request as a right-sized, refinable scope artifact — honest about what they cannot know |
| 2. Refine | `refine` | Mature that scope (with engineering) into a system-aware, ticket-ready brief |
| 3. Handoff | `handoff` | Package the refined brief into a self-contained, liftable engineering hand-off artifact |

**Audience:** typically non-technical product/client-managers. The agent frames
everything for them and never forces them to author things they cannot know
(system internals, authoritative scope, complexity) — those are surfaced as open
questions for the refine stage instead.

**What it never does:** write code, manage git branches/PRs, hand off
automatically (each stage ends with a *pointer* to the next stage; a human
carries the work across), fabricate technical detail, or produce engineering
specs (file paths, task decomposition, implementation detail).

---

## Engineering Lifecycle Skills

These six skills implement the `engineer` agent's full lifecycle (Path C) plus
its bugfix support (Path A/B). Three are **interactive** and loaded inline
(`researcher`, `planner`, `finisher`); two are **non-interactive** sub-agents
(`coder`, `reviewer`); and `debugging` runs inline within whichever context is
fixing a bug.

<a id="skill-researcher"></a>
### `researcher` — Design & Discovery

**File:** `skills/researcher/SKILL.md` · **Execution:** inline (interactive)

Turns vague ideas into approved designs through structured dialogue. This is the
**mandatory first phase** of the full engineering lifecycle — before any planning
or code.

- **Hard gate:** does not write code, scaffold, or take any implementation action
  until it has presented a design and the user has explicitly approved it —
  regardless of perceived simplicity.
- **Scope detection:** if the request spans multiple independent subsystems, it
  flags this and helps decompose before refining details; each sub-project gets
  its own design → plan → implement cycle.
- **Process:** explore project context → ask clarifying questions **one at a
  time** → propose 2–3 approaches with trade-offs and a recommendation → present
  the design in complexity-scaled sections with per-section approval → write the
  design doc to `docs/specs/YYYY-MM-DD-<topic>-design.md` → self-review for
  placeholders/contradictions/ambiguity → user review gate → transition to the
  `planner` skill (the only skill it hands off to).
- **Principles:** one question at a time, multiple-choice preferred, YAGNI
  ruthlessly, always explore alternatives, incremental validation.

<a id="skill-planner"></a>
### `planner` — Task Decomposition

**File:** `skills/planner/SKILL.md` · **Execution:** inline (interactive)

Writes detailed, executable implementation plans that a coder sub-agent can
follow with **zero prior familiarity with the codebase**. Runs only after a
design has been approved by the researcher stage.

- **Output:** saved to `docs/plans/YYYY-MM-DD-<feature-name>.md` with a mandatory
  header (goal, architecture, tech stack).
- **Bite-sized granularity:** each step is one 2–5 minute action (write the
  failing test → run it to confirm failure → implement minimal code → run to
  confirm pass → commit), following TDD.
- **No placeholders (enforced):** every step contains the actual code, exact file
  paths, exact commands, and expected output. "TBD", "add error handling", "write
  tests for the above" without real code, and references to undefined
  types/functions are treated as **plan failures**.
- **Independence analysis (critical):** at the end, groups tasks into parallel
  dispatch batches — independent tasks that can run together, dependent tasks
  that must be sequential, and same-shape mechanical work that should be batched
  into a single coder rather than one-per-file. This is what enables the
  engineer's parallel dispatch.
- **Self-review:** checks spec coverage, scans for placeholders, and verifies type
  consistency across tasks before handing back to the orchestrator.

<a id="skill-coder"></a>
### `coder` — Implementation Sub-Agent

**File:** `skills/coder/SKILL.md` · **Execution:** dispatched sub-agent (`task`)

An implementation sub-agent that executes a **single task** from an approved
plan: writes tests first (TDD), implements to pass them, verifies, commits, and
reports back with structured status.

- **Before starting:** raises any questions about requirements, approach, or
  assumptions rather than guessing.
- **Bugfix hard gate:** if the task is a bugfix, it must invoke the `debugging`
  skill and state the root cause with evidence before editing — even when the fix
  looks obvious.
- **Never dispatches its own sub-agents:** review comes from the orchestrator
  after the report, never from a helper the coder spawns.
- **Formats changed files before committing** (per `AGENTS.md`), never bypasses
  pre-commit hooks.
- **Escalation:** stops and reports `BLOCKED` / `NEEDS_CONTEXT` when it hits
  architectural ambiguity, needs context it can't find, or is uncertain — "bad
  work is worse than no work."
- **Self-review checklist** covers completeness, quality, discipline (YAGNI,
  existing patterns, formatting), and testing (tests run *this turn*, not
  remembered).
- **Responding to review feedback:** restates each finding, verifies it against
  the actual code, pushes back with evidence if a finding is wrong, and makes no
  performative agreement.
- **Report statuses:** `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT`.

<a id="skill-debugging"></a>
### `debugging` — Root Cause Analysis

**File:** `skills/debugging/SKILL.md` · **Execution:** inline (within whichever agent/sub-agent is fixing the bug)

Finds the **root cause before touching any code**. A fix that addresses a symptom
instead of its cause tends to resurface later in a harder-to-diagnose form.

- **Hard gate:** no fix proposed or applied until the root cause can be stated
  with evidence (an error message, a reproduction, a traced data flow). "It's
  probably X" is not evidence.
- **Process:** reproduce the failure (or explicitly state you couldn't) → check
  recent changes (`git diff`/`git log -p`) → trace to the source (fix where the
  problem originates, not where it surfaced) → form one hypothesis and test it
  with the smallest possible change → fix the root cause with a regression test →
  run the verification check fresh before calling it fixed.
- **Escalation cap:** after **3 failed fix attempts**, stop — three misses at the
  same target signal the *approach* is wrong. Inline, it tells the user; as a
  dispatched sub-agent (via `coder`), it reports `BLOCKED`.
- Includes a red-flags list and a common-rationalizations table to head off the
  usual shortcuts ("quick fix for now", "no time to reproduce", etc.).

<a id="skill-reviewer"></a>
### `reviewer` — Spec Compliance + Code Quality Review

**File:** `skills/reviewer/SKILL.md` · **Execution:** dispatched sub-agent (`task`)

A review sub-agent that validates implementation against two criteria **in
sequence**, in one of two modes the orchestrator selects:

1. **spec-compliance** — did the implementer build exactly what was requested,
   nothing more, nothing less?
2. **code-quality** — is the implementation well-built, clean, and maintainable?
   (**Hard gate:** only runs *after* spec compliance passes.)

- **Does not trust the implementer's report:** reads the actual code, compares to
  requirements line by line, checks for missing pieces and unrequested extras,
  and re-runs any cited test command rather than trusting its stated result.
- **Spec-compliance** looks for missing requirements, over-engineering, and
  misunderstandings. Reports `✅ PASS` / `❌ FAIL`.
- **Code-quality** checks structure, unit decomposition, consistency with the
  plan, naming, strict typing, unnecessary dependencies, real (non-mock) tests,
  leftover TODOs, and file sizes — categorizing issues as Critical / Important /
  Minor. Reports `✅ APPROVED` / `❌ NEEDS FIXES`.
- **Review loop protocol:** the same implementer fixes findings, the same
  reviewer re-runs with identical inputs, repeat until approved — **capped at 3
  rounds**. Re-reviews are never skipped even if the implementer says "I fixed
  it." If round 3 still has open issues, the findings go to the user rather than a
  4th round.

<a id="skill-finisher"></a>
### `finisher` — Completion & Integration

**File:** `skills/finisher/SKILL.md` · **Execution:** inline (interactive) · **Mode:** required

Guides completion of development work once implementation is done and every task
has passed review, by presenting clear options and handling the chosen workflow.

- **Step 1 — verify tests fresh:** re-runs the project's test suite *right now*; a
  passing run from earlier in the session doesn't count. Stops if tests fail.
- **Step 2 — detect environment:** captures `GIT_DIR`, `GIT_COMMON`, and
  `WORKTREE_PATH` **before any `cd`** to decide which menu to show and how cleanup
  works (normal repo, named-branch worktree, or detached HEAD).
- **Step 3 — determine base branch** (`main`/`master`, asking if ambiguous).
- **Step 4 — present options:** exactly 3 for a normal repo/named-branch worktree
  (merge locally / push and open a PR / keep as-is), or 2 for detached HEAD.
  **Discarding work is never a listed option** — it happens only on an explicit,
  unambiguous request, and requires typed confirmation.
- **Step 5–6 — execute & clean up:** merges/pushes/keeps per the choice; cleans up
  only for a local merge or a confirmed discard, and only for worktrees it
  created (provenance check). Never force-pushes without an explicit request,
  never removes a workspace before confirming merge success.

---

## Data Pipeline Skills

These three skills implement the `data` agent's pipeline. Each stage produces
artifacts the next consumes; nothing is reprocessed within a session. All three
adapt persistence to the environment — the canonical output (manifest / findings
/ report) is always rendered inline, while intermediate artifacts land in
`.pipeline-cache/` when a durable filesystem is available.

<a id="skill-ingest"></a>
### `ingest` — Extract, Clean, Normalize

**File:** `skills/ingest/SKILL.md` · **Execution:** inline or dispatched sub-agent (parallel fan-out)

Turns a pile of raw, messy files into one clean, consistent dataset — the first
pipeline stage: **extract → clean → converge (normalize)**.

- **Supported formats:** PDF (`pdfplumber`/`pypdf`), XLSX/XLS (`openpyxl`/
  `pandas`), CSV/TSV (`pandas`), JSON, HTML tables (`BeautifulSoup`/
  `pandas.read_html`), Markdown tables, and plain text.
- **Outputs:** per-file extracted artifacts in `.pipeline-cache/extracted/`, one
  or a few normalized artifacts in `.pipeline-cache/normalized/`, and a short
  manifest of what came in, what came out, and any warnings.
- **Parallelism escalation ladder:** inline (single file) → in-process pool (2–5
  same-format) → shell fan-out (2–5 mixed formats) → sub-agent fan-out (many/heavy
  files). Whoever fans out owns waiting for all units before the convergence step.
- **Convergence & normalize:** aligns inconsistent column names, normalizes mixed
  date/number formats, flattens multi-header rows, and handles missing values
  explicitly — documenting every judgment call.
- **Non-negotiable rules:** never mutate source files, no silent installs,
  document judgment calls, and cache rather than reprocess.
- **Report statuses:** `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`.

<a id="skill-analyze"></a>
### `analyze` — Findings from the Clean Dataset

**File:** `skills/analyze/SKILL.md` · **Execution:** inline (single-pass, convergence-gated)

Answers the question being asked of a clean dataset — the middle pipeline stage
that turns normalized data into findings. Single-pass; no parallelism.

- **Before starting:** gets clear on *what question is being answered*. If the
  goal is vague ("look at this data"), it asks what decision the analysis informs
  before producing numbers.
- **Analysis types:** matches technique to question shape — aggregation/group-by,
  comparison/ratios, trend detection, outlier/anomaly identification, frequency
  distributions, and joins/correlation across datasets.
- **How it works:** loads the normalized dataset, writes analysis in reproducible
  code (`scripts/`, not ad-hoc mental math), matches depth to the task, and
  **surfaces the unexpected** (data quality issues, surprising outliers) rather
  than burying it.
- **Hard constraints:** no application logic changes; never mutates source or
  normalized inputs.
- **Stops honestly** when the data can't answer the question, a domain decision is
  needed, or results look implausible (flagging an upstream data problem).
- **Report statuses:** `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`.

<a id="skill-report"></a>
### `report` — Deliver the Findings

**File:** `skills/report/SKILL.md` · **Execution:** inline (terminal stage)

Delivers the findings the way the user actually wants to consume them — the final
pipeline stage.

- **Step 1 — confirm format:** if the user hasn't specified one, it **asks before
  producing anything**. Supports Markdown, CSV, XLSX, JSON, plain text, and inline
  (terminal), and one or more outputs at once (e.g. a Markdown narrative plus a
  CSV of the numbers).
- **Step 2 — write the report:** leads with the answer, matches length to the
  question, includes supporting numbers/tables, surfaces caveats honestly, and
  saves deliverable files to a sensible location (not buried in
  `.pipeline-cache/`).
- **Step 3 — Artifacts & Scripts section (mandatory):** every report ends with a
  section documenting outputs delivered, pipeline-cache artifacts, scripts, and
  decisions worth knowing — so the work is reproducible and nothing is a mystery.
- **Hard constraints:** ask before reporting if the format is unspecified, never
  produce an unrequested format, always include the Artifacts & Scripts section,
  no application logic changes.
- **Report statuses:** `DONE`, `DONE_WITH_CONCERNS`.

---

## Product Funnel Skills

These four skills implement the `product` agent's work-shaping funnel — a triage
front door plus three shaping stages. Triage is inline-only; scope and refine
evolve a single `docs/scopes/` document in place (git history is the audit
trail); handoff produces a separate liftable package. None of them ever writes
code or invokes another agent — each ends with a *pointer* to the next stage.

<a id="skill-triage"></a>
### `triage` — Classify & Route

**File:** `skills/triage/SKILL.md` · **Execution:** inline (fast, single-pass)

Classifies a raw, unsorted inbound request and produces a **fast triage
decision** — the front door of the product funnel. It classifies and points; it
does **not** gather requirements or estimate (that's `scope`'s job).

- **Routing buckets (exactly one per ask):** Product shaping (→ `scope`),
  Engineering (→ `engineer` agent), Data/analysis (→ `data` agent), Needs more
  info (→ bounce back with specific questions), Not actionable (→ reject/defer
  with a one-line reason).
- **Artifact:** a short, inline routing decision — Request Summary,
  Classification, Rationale, Recommended Next Step, Signals & Unknowns, and
  optional Urgency/Notes.
- **Self-check:** splits multi-classification requests, trims any drift into
  scope's territory, and never presents a hedged/ambiguous classification.
- **Inline-only:** writes no file; the durable record begins at `scope`. Triage
  **never invokes** another agent or skill — it only recommends.

<a id="skill-scope"></a>
### `scope` — Stakeholder Requirements Intake

**File:** `skills/scope/SKILL.md` · **Execution:** inline (interactive)

Helps a (typically non-technical) stakeholder turn a too-vague or too-broad
request into a **right-sized, refinable scope artifact** — the first shaping
stage. Provides "right-sized friction": enough structure to be actionable and
honest, light enough that people actually use it.

- **Adaptive intake:** if the request is too thin, it asks a capped set of 3–5
  high-leverage questions, one at a time; if too broad, it skips straight to
  draft-and-trim.
- **Bounded template (≈ one page):** Problem/Need, Desired Outcome, Boundaries (as
  understood), Success Criteria, Open Questions & Unknowns, and Shape.
- **Honest about unknowns:** "Open Questions & Unknowns" is first-class — it is
  safe and normal to say "I don't know X, this needs technical input." It never
  forces or fabricates technical detail (system considerations, authoritative
  scope, complexity) — those are **deliberately excluded** and belong to `refine`.
- **Right-sizing self-calibration:** trims prose that's too vague/too detailed,
  strips fabricated technical detail, and recommends *splitting into multiple
  tickets* rather than ballooning a single document.
- **Persistence:** always renders inline; when a repo is available, persists to
  `docs/scopes/YYYY-MM-DD-<topic>.md` and commits it. Ends with a pointer to
  `refine`.

<a id="skill-refine"></a>
### `refine` — Technical Maturation

**File:** `skills/refine/SKILL.md` · **Execution:** inline (interactive)

Takes a stakeholder scope artifact and **matures it into a system-aware,
ticket-ready brief** — the second shaping stage, the technical product manager's
tool used in collaboration with engineering.

- **Input:** the existing `docs/scopes/YYYY-MM-DD-<topic>.md` (or an inline scope
  brief). If none exists, it recommends running `scope` first rather than
  fabricating a stakeholder scope.
- **Augments the same document in place** — it does not create a parallel
  artifact; git shows the scope → refined maturation as commits to one file.
- **What it adds** (authored with a real technical basis): System Considerations,
  authoritative In Scope / Out of Scope (superseding the stakeholder's soft
  boundaries while keeping their framing visible), Complexity/Shape, Resolved Open
  Questions (each marked answered / needs-spike / deferred), and a Ticket
  Breakdown if a split is warranted.
- **Self-calibration:** guards against ballooning, unresolved unknowns, scope
  drift, and speculative detail asserted without basis (marked needs-spike
  instead). Ends with a pointer to `handoff`.

<a id="skill-handoff"></a>
### `handoff` — Engineering Hand-Off Packaging

**File:** `skills/handoff/SKILL.md` · **Execution:** inline (interactive)

Packages a refined scope brief into a **self-contained, liftable engineering
hand-off** — the bridge between the product funnel and the engineering lifecycle.
A human lifts this package and pastes it into the `engineer` agent to seed its
design/research phase.

- **Input:** the refined `docs/scopes/YYYY-MM-DD-<topic>.md` (or an inline refined
  brief). If the input hasn't been refined yet, it recommends running `refine`
  first.
- **Produces a separate, self-contained artifact** — distinct from the
  scope/refine document so a human can lift just this package without carrying the
  stakeholder-scope history.
- **Sections:** Summary, Goal/Outcome, Authoritative Scope, Key Constraints &
  System Considerations, Acceptance Criteria, Open Risks/Spikes, and Suggested
  Ticket(s).
- **Repackages, does not expand:** everything traces back to the refined brief. It
  contains **no implementation detail** (no code, file paths, or task
  decomposition) — that is the engineer lifecycle's job; the hand-off *seeds* it.
- **Self-calibration:** guards against scope invention, implementation leakage,
  ballooning, and unresolved risks.
- **Persistence:** always renders inline; when a repo is available, writes a **new**
  file at `docs/handoffs/YYYY-MM-DD-<topic>.md` and commits it. Ends with a
  pointer to paste the package into the `engineer` agent.

---

## How Agents and Skills Fit Together

The three workflows connect end to end. The product funnel shapes work and hands
a package to the engineer; the engineer builds it; the data agent runs an
independent analysis pipeline.

```
PRODUCT FUNNEL                     ENGINEERING LIFECYCLE
──────────────                     ─────────────────────
triage ─┬─→ scope → refine → handoff ──(human lifts)──→ engineer (Path C)
        │                                                   │
        ├─→ engineer agent (already-specified / trivial)    ├─ researcher (design, approval-gated)
        ├─→ data agent (analysis / report)                  ├─ planner (task decomposition)
        └─→ back to requester (needs more info)             ├─ coder ×N (parallel, TDD)   ← debugging (bugfixes)
                                                            ├─ reviewer ×2 (spec, then quality)
DATA PIPELINE                                               └─ finisher (verify, merge/PR)
─────────────
ingest (parallel fan-out) → analyze (single-pass) → report (chosen format)
```

**Execution patterns at a glance:**

| Skill | Workflow | Interactive / Sub-agent | Persists to |
|---|---|---|---|
| `researcher` | Engineering | Interactive (inline) | `docs/specs/` |
| `planner` | Engineering | Interactive (inline) | `docs/plans/` |
| `coder` | Engineering | Sub-agent (`task`) | commits on branch |
| `debugging` | Engineering | Inline (in the fixing context) | — |
| `reviewer` | Engineering | Sub-agent (`task`) | — |
| `finisher` | Engineering | Interactive (inline) | merges / PR |
| `ingest` | Data | Inline or sub-agent fan-out | `.pipeline-cache/` |
| `analyze` | Data | Inline (single-pass) | `.pipeline-cache/analysis/` |
| `report` | Data | Inline (terminal) | deliverable files |
| `triage` | Product | Inline (single-pass) | inline-only |
| `scope` | Product | Interactive (inline) | `docs/scopes/` |
| `refine` | Product | Interactive (inline) | `docs/scopes/` (same file) |
| `handoff` | Product | Interactive (inline) | `docs/handoffs/` |

**Zero external dependencies.** All agents and skills are vendored locally under
`home/.config/opencode/`. There are no external git plugins and no runtime
fetches.
