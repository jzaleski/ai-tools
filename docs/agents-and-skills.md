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

There are **3 agents** and **15 skills**, organized into three workflows:

| Workflow | Agent | Skills |
|---|---|---|
| Engineering lifecycle | `engineer` | `researcher`, `planner`, `coder`, `debugging`, `reviewer`, `finisher`, `test-driven-development`, `verification-before-completion` |
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
  - [test-driven-development](#skill-test-driven-development)
  - [verification-before-completion](#skill-verification-before-completion)
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
| **C — Full Lifecycle** | Ambiguous, design-required, or large interdependent features | `researcher` → `planner` → parallel `coder` batches → `reviewer` ×2 → `finisher` (continuous execution without intermediate stalls; rulings, not stalls for minor conflicts) | Feature branch with commits/PR |

**Core principles (all paths):** correctness over cleverness, strict typing
always, minimal dependency footprint, consistency with existing code, no silent
TODOs, **test-driven development** (`skills/test-driven-development`) for all code
and bugfixes, and — critically — **verification before completion**
(`skills/verification-before-completion`): never claim something passes without
running the actual check in the current turn.

**Orchestration discipline (Path C):**
- **Continuous execution:** Does not pause to check in with the user between tasks; executes all tasks from the plan without stopping unless hitting irreversible/security boundaries or encountering a broken plan.
- **Rulings, not stalls:** A running plan does not wait on a human for minor conflicts or ambiguities. The spec is binding authority, the plan is its argument, and engineer's judgment settles what neither answers. Every decision is recorded as `Ruling: <what decided> — <why> — <what it costs if wrong>` while work continues.

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

These eight skills implement the `engineer` agent's full lifecycle (Path C), its
bugfix support (Path A/B), and project-wide engineering discipline. Three are
**interactive** and loaded inline (`researcher`, `planner`, `finisher`); two are
**non-interactive** sub-agents (`coder`, `reviewer`); `debugging` runs inline
within whichever context is fixing a bug; and two are **standalone discipline
skills** (`test-driven-development`, `verification-before-completion`) that govern
code creation and completion claims across all paths.

<a id="skill-researcher"></a>
### `researcher` — Design & Discovery

**File:** `skills/researcher/SKILL.md` · **Execution:** inline (interactive)

Turns vague ideas into approved designs through structured dialogue. This is the
**mandatory first phase** of the full engineering lifecycle — before any planning
or code.

- **Hard gate:** does not write code, scaffold, or take any implementation action
  until it has presented a design and the user has explicitly approved it —
  regardless of perceived simplicity. Includes explicit anti-rationalization tables.
- **Scope detection:** if the request spans multiple independent subsystems, it
  flags this immediately and decomposes into sub-projects with distinct build order;
  each sub-project gets its own design → plan → implement cycle.
- **Look Before You Ask:** reads referenced files, documentation, recent commits,
  and surrounding codebase patterns before sending the first message; never asks
  what the project or context already answers.
- **First message structure (~200 words):** echoes the request back in own words
  (what, who, why), highlights project connections and constraints discovered,
  surfaces non-obvious factors, and closes with **one open question** on the biggest
  unsettled requirement.
- **Technical ownership probing ("How it gets made"):** probes early to discover
  which platform, language, and library choices the user wants to own vs. delegate
  to sensible defaults (recorded as author's calls).
- **Size the work:** small change (short design doc: intent, constraints, approach)
  vs. project (full written design doc validated with the builder check).
- **Builder check (for projects):** reads the draft spec as an independent builder
  and sorts open items into *Already Answered* (added to doc), *Minor* (settled as
  author's call), and *Theirs* (single focused round of questions for the user).
- **Spec self-review:** scans for placeholders (TODO/TBD), verifies internal
  consistency, and checks scope before presenting for final approval. Transitions
  only to `planner`.

<a id="skill-planner"></a>
### `planner` — Task Decomposition

**File:** `skills/planner/SKILL.md` · **Execution:** inline (interactive)

Writes detailed, executable implementation plans that a coder sub-agent can
follow with **zero prior familiarity with the codebase**. Runs only after a
design has been approved by the researcher stage.

- **Output:** saved to `docs/plans/YYYY-MM-DD-<feature-name>.md` with a mandatory
  header (goal, architecture, tech stack).
- **Decisions, not transcripts:** records decisions (signatures, exact file paths,
  spec values, test names, assertions) rather than verbatim code implementations.
  Code bodies appear only for non-obvious algorithms.
- **Global constraints block:** copied verbatim from spec (dependency floors,
  naming conventions, platform requirements).
- **Review focus block:** up to 5 input classes or edge cases the spec implies but
  no task tests exercise; each pinned to an explicit test in its owning task.
- **Task interfaces block:** every task declares `Consumes:` and `Produces:`
  (exact function signatures, parameter and return types) so sub-agents know neighbor
  contracts without reading surrounding tasks.
- **Bite-sized granularity:** each step is one 2–5 minute action (write failing
  test → confirm failure → implement minimal code → confirm pass → commit),
  following TDD.
- **No placeholders (enforced):** every step contains the actual code, exact file
  paths, exact commands, and expected output. "TBD", "add error handling", or
  references to undefined types/functions are treated as plan failures.
- **Independence analysis (critical):** groups tasks into parallel dispatch batches
  — independent tasks that run together, dependent tasks that run sequentially,
  and mechanical batches. Enables the engineer's parallel dispatch.
- **Proportion self-review:** if plan length is several times longer than the spec,
  replaces code transcripts with signatures and assertions.

<a id="skill-coder"></a>
### `coder` — Implementation Sub-Agent

**File:** `skills/coder/SKILL.md` · **Execution:** dispatched sub-agent (`task`)

An implementation sub-agent that executes a **single task** from an approved
plan: writes tests first (TDD), implements to pass them, verifies, commits, and
reports back with structured status.

- **Before starting:** raises any questions about requirements, approach, or
  assumptions rather than guessing.
- **Bugfix hard gate:** if the task is a bugfix, it must invoke `skills/debugging`
  and state the root cause with evidence before editing — even when the fix
  looks obvious.
- **TDD & verification binding:** explicitly binds to `skills/test-driven-development`
  (failing test first) and `skills/verification-before-completion` (fresh evidence
  before reporting).
- **Suite-wide green verification:** running tests means executing the project's
  entire test suite (`pytest`, `npm test`, `cargo test`), not just the task's local
  test file. Pre-existing failures must be reported explicitly by name.
- **Review reception discipline:** inlined from `receiving-code-review` — restate
  each finding in own words, verify against actual code before editing, state
  technical reasoning with evidence if disagreeing, and make zero performative
  agreement ("You're absolutely right!").
- **Never dispatches its own sub-agents:** review comes from the orchestrator
  after the report, never from a helper the coder spawns.
- **Formats changed files before committing** (per `AGENTS.md`), never bypasses
  pre-commit hooks.
- **Escalation:** stops and reports `BLOCKED` / `NEEDS_CONTEXT` when it hits
  architectural ambiguity, needs context it can't find, or is uncertain.
- **Self-review checklist** covers completeness, quality, discipline (YAGNI,
  existing patterns, formatting), and testing (tests run *this turn*, not
  remembered).
- **Report statuses:** `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT`.

<a id="skill-debugging"></a>
### `debugging` — Root Cause Analysis

**File:** `skills/debugging/SKILL.md` · **Execution:** inline (within whichever agent/sub-agent is fixing the bug)

Finds the **root cause before touching any code**. A fix that addresses a symptom
instead of its cause tends to resurface later in a harder-to-diagnose form.

- **The Iron Law:** no fix proposed or applied until the root cause can be stated
  with evidence (an error message, a reproduction, a traced data flow). "It's
  probably X" is not evidence.
- **Multi-boundary diagnostic instrumentation:** systematic pattern for multi-layer
  bugs (CI/build/signing, API/service/DB) logging inputs and outputs across system
  boundaries.
- **Inlined supporting techniques:**
  - *Root-Cause Tracing:* backward call-stack tracing to identify the original trigger.
  - *Defense in Depth:* multi-layer validation after fixing the root cause.
  - *Condition-Based Waiting:* polling for observable conditions rather than arbitrary sleep timeouts.
- **Process:** reproduce failure → check recent changes (`git diff`/`git log -p`)
  → trace to source across boundaries → test hypothesis with minimal change →
  fix root cause with regression test → verify fresh.
- **Architectural escalation cap:** after **3 failed fix attempts**, stop and
  diagnose whether the architecture/pattern is fundamentally unsound rather than
  blindly attempting fix #4. Inline, alerts user; as a dispatched sub-agent,
  reports `BLOCKED`.
- Includes red-flags list and common-rationalizations table.

<a id="skill-reviewer"></a>
### `reviewer` — Spec Compliance + Code Quality Review

**File:** `skills/reviewer/SKILL.md` · **Execution:** dispatched sub-agent (`task`)

A review sub-agent that validates implementation against two criteria **in
sequence**, in one of two modes the orchestrator selects:

1. **spec-compliance** — did the implementer build exactly what was requested,
   nothing more, nothing less?
2. **code-quality** — is the implementation well-built, clean, and maintainable?
   (**Hard gate:** only runs *after* spec compliance passes.)

- **Spec as vision document:** the spec defines what software must do, not everything
  it will meet. For unstated behaviors, judges by what a reasonable user would expect;
  silence is not permission for crashing or data loss.
- **Declined to judge section:** explicitly lists behaviors considered but set aside
  as outside the plan/spec with rationale, so nothing is silently dropped.
- **Read-only review:** strictly prohibited from mutating the working tree or spawning
  nested reviewer subagents.
- **Does not trust implementer report:** reads actual code, compares to requirements
  line by line, checks for missing pieces or unrequested extras, and re-runs cited
  test commands.
- **Spec-compliance** reports `✅ PASS` / `❌ FAIL`.
- **Code-quality** checks structure, unit decomposition, plan consistency, naming,
  strict typing, minimal dependencies, real tests, leftover TODOs, and file sizes —
  categorizing issues as Critical / Important / Minor. Reports `✅ APPROVED` / `❌ NEEDS FIXES`.
- **Review loop protocol:** implementer fixes, same reviewer re-runs with identical
  inputs, repeat until approved — **capped at 3 rounds**. Round 3 open issues go to
  user.

<a id="skill-finisher"></a>
### `finisher` — Completion & Integration

**File:** `skills/finisher/SKILL.md` · **Execution:** inline (interactive) · **Mode:** required

Guides completion of development work once implementation is done and every task
has passed review, by presenting clear options and handling the chosen workflow.

- **Step 1 — verify tests fresh:** re-runs the project's test suite *right now*;
  stops if tests fail.
- **Step 2 — detect environment:** captures `GIT_DIR`, `GIT_COMMON`, and
  `WORKTREE_PATH` **before any `cd`** to determine menu and cleanup behavior.
- **Step 3 — determine base branch** (`main`/`master`, asking if ambiguous).
- **Step 4 — present options:** exactly 3 for normal repo/named worktree (merge
  locally / push and open PR / keep as-is), or 2 for detached HEAD. Discarding is
  never a listed default option.
- **Safe worktree cleanup refusal:** if `git worktree remove` refuses due to
  untracked or uncommitted files, never `--force`. Presents options to user:
  (1) commit to branch, (2) move to main repo, or (3) delete.
- **Merged result verification:** verifies that project tests pass after local merge
  into base branch before deleting any feature branch or worktree; rolls back on failure.

<a id="skill-test-driven-development"></a>
### `test-driven-development` — Test-First Discipline & Good Tests

**File:** `skills/test-driven-development/SKILL.md` · **Execution:** inline or sub-agent guide

Enforces strict test-first development and high-quality test design for all new
features, bugfixes, refactoring, and behavioral changes across all paths.

- **The Iron Law:**
  ```
  NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
  ```
  If code was written before the test, delete it. Implement fresh from tests.
- **Red-Green-Refactor cycle:**
  - *RED:* Write one minimal test showing what should happen.
  - *Verify RED (mandatory):* Run test and watch it fail for the expected reason
    (feature missing, not syntax errors or typos).
  - *GREEN:* Write the simplest minimal code to pass the test (YAGNI).
  - *Verify GREEN (mandatory):* Run test and confirm pass. Enforce the
    **Suite-Wide Green Rule**: run the project's entire test suite (`pytest`, `npm test`,
    `cargo test`), not just the local test file. Report any failures by name.
  - *REFACTOR:* Clean up duplication, improve names, extract helpers while tests stay green.
- **Inlined Good Test Guidelines:**
  - *Principle 1 — Name the break:* every test names the specific bug/break it catches;
    derive expectations independently using hand-checked fixtures or literals (no mirror
    assertions); avoid change detectors (test behavior, not constant values or wording);
    test behavior, not source text; test your boundary contract, not framework internals.
  - *Principle 2 — Exercise the real thing:* the mock earns no assertions (test real
    behavior); understand dependencies and mock at the right level below real side effects;
    make doubles specific; mirror real data structures completely; keep test-only helpers
    out of production classes; prefer real components over complex mocks.
  - *The Mutation Check:* mentally mutate production code to verify at least one test fails
    for each realistic mutation.
- Includes comprehensive Red Flags and Common Rationalizations tables.

<a id="skill-verification-before-completion"></a>
### `verification-before-completion` — Evidence Before Claims

**File:** `skills/verification-before-completion/SKILL.md` · **Execution:** inline or sub-agent gate

Enforces strict verification evidence before any claim that work is complete, fixed,
passing, or ready to integrate.

- **The Iron Law:**
  ```
  NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
  ```
  If you haven't run the verification command in this turn, you cannot claim it passes.
- **The Gate Function:**
  1. *IDENTIFY:* What command proves this claim?
  2. *RUN:* Execute the FULL command fresh and complete.
  3. *READ:* Read full output, check exit code, count failures.
  4. *VERIFY:* Does output confirm the claim? (If NO, state actual status with evidence;
     if YES, state claim WITH evidence).
  5. *ONLY THEN:* Make the claim.
- **Common failure modes:** test claims require 0 failures (not previous runs); linter
  clean requires 0 errors; build requires exit 0; bug fixed requires original symptom
  passes; regression test requires red-green cycle; agent delegation requires checking
  VCS diff.
- **Rationalization prevention table:** counters excuses like "should work now",
  "I'm confident", "linter passed", "agent said success", "I'm tired", or "partial check is enough".
- Universal gate applied before committing, opening PRs, reporting task completion,
  or expressing satisfaction.

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
- **Normalization evidence gates:** never claims a dataset is ingested or normalized
  without verifying row counts, schema conformity, and column null rates against
  source files.
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
- **Convergence & distribution anomaly checks:** sanity-checks aggregations against
  raw totals and actively detects and surfaces outliers, data skews, or quality
  anomalies rather than blindly reporting summaries.
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
- **Metric & format verification:** strictly enforces that all reported numbers
  tie back to analysis artifacts, formats match the user's requested deliverable,
  and narrative conclusions strictly reflect empirical findings.
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
- **Anti-rationalization discipline:** includes a Red Flags and Common
  Rationalizations table preventing premature routing without sufficient evidence
  or dodging clarification.
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

- **Socratic playback:** echoes stakeholder intent back in plain words with guesses
  clearly flagged so misunderstandings are caught immediately.
- **Strict boundary enforcement:** captures the *what* and *why* while keeping
  technical implementation details out of the stakeholder scope artifact.
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
- **Spec as vision document:** proactively identifies unstated edge cases,
  reasonable user expectations, failure modes, and technical constraints before
  handing off.
- **What it adds** (authored with a real technical basis): System Considerations,
  authoritative In Scope / Out of Scope (superseding the stakeholder's soft
  boundaries while keeping their framing visible), Complexity/Shape, Resolved Open
  Questions (each marked answered / needs-spike / deferred), and a Ticket
  Breakdown sized into single checkable deliverables if a split is warranted.
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
- **Explicit verification checklist:** verifies no TBDs, confirmed interfaces,
  explicit acceptance criteria, and zero reliance on external memory before
  generating the hand-off artifact.
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
        └─→ back to requester (needs more info)             ├─ coder ×N (parallel, TDD)   ← test-driven-development
                                                            ├─ reviewer ×2 (spec, quality) ← verification-before-completion
                                                            └─ finisher (verify, merge/PR) ← debugging (bugfixes)
DATA PIPELINE
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
| `test-driven-development` | Engineering | Inline or sub-agent guide | code & tests |
| `verification-before-completion` | Engineering | Inline or sub-agent gate | verifier command output |
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
