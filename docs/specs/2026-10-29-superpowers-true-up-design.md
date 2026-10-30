# Toolkit True-Up: Reconciling Modern Advancements from `obra/superpowers` (v7.0.1) — Design

**Status:** Draft (Pending User Review)  
**Author:** engineer agent (with jzaleski)  
**Date:** 2026-10-29  

---

## 1. Background & Context

The agents and skills in `home/.config/opencode/` were originally derived from `obra/superpowers`, vendored directly into this repository (`7c0ef24 feat: Remove reliance on superpowers`, May 2026), and evolved independently. A previous true-up occurred on 2026-08-17 (`docs/specs/2026-08-17-agents-skills-superpowers-review-design.md`).

Since that time, upstream Superpowers has undergone extensive restructuring and battle-testing across releases v6.2 through v7.0.1 (October 2026):
- **Brainstorming rebuilt (v7.0.0/v7.0.1):** Shifted away from formulaic questions to "look before you ask" context reading, intent playback, early technical ownership probing, right-sizing ceremony (small change vs. project), and builder checks.
- **Writing Plans lean overhaul (v6.4.2):** Shifted from transcript-heavy code dumps to recording decisions (signatures, exact files, spec values, test assertions); introduced explicit `Global Constraints`, `Review Focus` (edge-case discovery), task `Interfaces` blocks (`Consumes`/`Produces`), and proportion self-reviews.
- **Systematic Debugging deep-dives:** Multi-layer boundary instrumentation, backward call-stack tracing, defense-in-depth, condition-based waiting, and architectural pause rules after 3 failed fix attempts.
- **Reviewer calibrations:** Framing the spec as a vision document (spec silence is not permission for crashing on reasonable inputs), explicit "Declined to judge" accounting, read-only review, and anti-performative review reception.
- **Test-Driven Development & Verification:** Strict suite-wide green requirements ("other tests" means the whole project suite) and explicit evidence-before-assertions gate functions.
- **Finishing branches:** Safe worktree cleanup preventing `--force` destruction of untracked files and pre-deletion verification of merged test suites.

### Repository Invariants & Core Constraints
- **Source of Truth:** All files live in `home/.config/opencode/` in this git repository. The bootstrap system symlinks/installs them.
- **Self-Contained Skills:** Skills must be self-contained single `SKILL.md` files without fragile relative filesystem trees (`references/`), ensuring zero-dependency loading in OpenCode.
- **Literal Tool Execution (Gemini & Multi-Model Reliability):** Hard `CRITICAL` tool-calling directives for `skill` and `task` remain in all agents and prompts to prevent inline simulation.
- **Feature Branch Shared Filesystem:** Sub-agents share the feature branch filesystem; we deliberately do not use git worktrees for parallel sub-agents.
- **SDO Frontmatter Hygiene:** All skill frontmatter `description` fields must remain trigger-conditions-only (no workflow summaries that leak into decision logic).

---

## 2. Goals & Non-Goals

### Goals
1. Reconcile Superpowers v7 patterns into the 6 core engineering skills: `researcher`, `planner`, `coder`, `debugging`, `reviewer`, and `finisher`.
2. Vendor two new standalone self-contained skills into `home/.config/opencode/skills/`:
   - `test-driven-development` (TDD iron law, Red-Green-Refactor, inlined good test guidelines).
   - `verification-before-completion` (strict evidence-before-assertions gate function and rationalization prevention).
3. Inline key supporting techniques directly into parent skills:
   - `root-cause-tracing`, `defense-in-depth`, and `condition-based-waiting` inside `debugging`.
   - `writing-good-tests` inside `test-driven-development`.
   - `receiving-code-review` inside `reviewer`.
4. Cross-pollinate verification discipline and anti-rationalization tables into Product (`triage`, `scope`, `refine`, `handoff`) and Data (`ingest`, `analyze`, `report`) skills and agents.
5. Update `engineer.md` to reference the new standalone skills and incorporate continuous execution / "rulings, not stalls" principles for Path C orchestration.
6. Update `AGENTS.md` and `README.md` to reflect the updated skills inventory and structure.

### Non-Goals
- **Git Worktrees for Sub-Agents:** Rejected. OpenCode sub-agents share the working tree on a feature branch.
- **Dynamic Model-Tier Routing in Config:** Rejected. Sub-agents inherit session models to maintain portability across Anthropic, Vertex Gemini, and local llama.cpp providers.
- **Multi-File Skill Directories (`references/`):** Rejected. Per user decision (Structure A), all techniques are self-contained in single `SKILL.md` files.
- **External Web/Plugin Dependencies:** Zero external dependencies. All skills and agents remain completely local.

---

## 3. Detailed Component Specifications

### 3.1 Engineering Lifecycle Skills

#### `researcher` (`home/.config/opencode/skills/researcher/SKILL.md`)
- **Look Before You Ask:** Mandate deep context reading (files, docs, recent commits, existing patterns) before the first message. Never ask questions the project or context already answers.
- **First Message Structure (~200 words):**
  - Echo request back in own words (what, who, why).
  - State project connections and constraints discovered.
  - End with one line inviting corrections, then **one open question** on the biggest unsettled requirement.
- **Technical Ownership Probing ("How it gets made"):** Discover early which medium, platform, language, and library choices the user wants to own vs. delegate to sensible defaults.
- **Size the Work:**
  - *Small change:* Short design doc covering intent, constraints, approach in a few lines.
  - *Project:* Full written design doc.
- **Builder Check:** Before presenting for final approval, run an internal builder perspective check sorting open items into:
  - *Already Answered* (add to doc).
  - *Minor / Settled* (settle directly and mark as author's call).
  - *Theirs* (single round of essential questions for the user).
- **Hard Gate & Anti-Rationalization:** Strict gate against code/scaffolding before design doc approval; Red Flags and Rationalizations table.

#### `planner` (`home/.config/opencode/skills/planner/SKILL.md`)
- **Decisions, Not Transcripts:** Move away from writing full code implementations into plan steps. A plan records decisions: signatures, exact files, spec values, test names, and assertions. Code bodies appear only for non-obvious algorithms.
- **Global Constraints Block:** Copied verbatim from spec (dependency floors, naming conventions, platform requirements).
- **Review Focus Block:** Up to 5 input classes or edge cases the spec implies but no task tests exercise; each pinned to an explicit test in its owning task.
- **Task Interfaces Block:** Every task declares `Consumes:` and `Produces:` (exact function signatures, parameter and return types) so sub-agents know neighbor contracts without reading surrounding tasks.
- **Task Right-Sizing:** The smallest unit carrying its own test cycle and reviewer gate.
- **Proportion Self-Review:** If plan length is several times longer than the spec, replace code transcripts with signatures and assertions.

#### `coder` (`home/.config/opencode/skills/coder/SKILL.md`)
- **Suite-Wide Green Verification:** Clarify that "tests pass" requires running the project's full test command (e.g. `pytest`, `npm test`, `cargo test`), not just the task's single test file. Any pre-existing failures must be reported explicitly by name.
- **TDD & Verification Binding:** Explicitly reference and link to `skills/test-driven-development` and `skills/verification-before-completion`.
- **Review Reception Discipline:** Inlined rules from `receiving-code-review`: restate finding, verify against codebase reality before editing, technical reasoning if disagreeing, zero performative agreement ("You're absolutely right!").

#### `debugging` (`home/.config/opencode/skills/debugging/SKILL.md`)
- **The Iron Law:** No fixes without root-cause investigation first.
- **Multi-Component Boundary Diagnostic Instrumentation:** Detailed pattern for multi-layer bugs (CI/build/signing, API/service/DB) logging inputs and outputs across boundaries.
- **Inlined Supporting Techniques:**
  - *Root-Cause Tracing:* Backward call-stack tracing to find original trigger.
  - *Defense in Depth:* Multi-layer validation after fixing root cause.
  - *Condition-Based Waiting:* Polling for observable conditions rather than arbitrary sleep timeouts.
- **Architectural Escalation:** If 3 fix attempts fail, explicitly diagnose whether the architecture/pattern is fundamentally unsound rather than blindly attempting fix #4.

#### `reviewer` (`home/.config/opencode/skills/reviewer/SKILL.md`)
- **Spec as Vision Document:** The spec defines what software must do, not everything it will meet. For silent behaviors, judge by what a reasonable user would expect; silence is not permission for a crash or data loss.
- **Declined to Judge Section:** Reviewer must explicitly list behaviors considered but set aside as outside the plan/spec with rationale, so nothing is silently dropped.
- **Read-Only Review & No Nested Subagents:** Strict prohibition on mutating the working tree or spawning nested reviewer subagents.
- **Calibration & Fix Loop Cap:** Clear Critical / Important / Minor categorizations with the 3-round fix loop cap preserved.

#### `finisher` (`home/.config/opencode/skills/finisher/SKILL.md`)
- **Safe Worktree Cleanup Refusal:** If `git worktree remove` refuses due to untracked or uncommitted files, never `--force`. Present options to the user: (1) commit them to branch, (2) move them to main repo, or (3) delete.
- **Merged Result Verification:** Explicit verification that if tests fail after local merge into base branch, the merge is rolled back/investigated before deleting any branch or worktree.

---

### 3.2 New Standalone Skills

#### `test-driven-development` (`home/.config/opencode/skills/test-driven-development/SKILL.md`)
- **Iron Law:** "No production code without a failing test first."
- **Red-Green-Refactor Cycle:** Step-by-step verification at each phase.
- **Suite-Wide Verification:** Green means the project suite, not just the single file.
- **Inlined Good Test Guidelines:** Name production change that breaks test, assert on behavior rather than mocks, keep test-only helpers out of production classes.

#### `verification-before-completion` (`home/.config/opencode/skills/verification-before-completion/SKILL.md`)
- **Iron Law:** "No completion claims without fresh verification evidence."
- **Gate Function:** (1) Identify command, (2) Run full command, (3) Read output, (4) Verify evidence, (5) Only then make claim.
- **Rationalization Prevention Table:** Explicit counters to common shortcuts ("should work", "linter passed", "tired", "agent said success").

---

### 3.3 Product Agent & Skills

#### `product.md` (`home/.config/opencode/agents/product.md`)
- Update description and skills table to include tightened verification discipline and SDO descriptions.

#### `triage` (`home/.config/opencode/skills/triage/SKILL.md`)
- Add anti-rationalization table ("Red Flags" & "Common Rationalizations") preventing premature routing without sufficient evidence.
- Clearly demarcate 5 routing destinations with explicit criteria.

#### `scope` (`home/.config/opencode/skills/scope/SKILL.md`)
- Incorporate Socratic playback—echoing stakeholder intent back in plain words with guesses clearly flagged.
- Strictly enforce boundaries: capture the *what* and *why* while keeping technical implementation details out of the stakeholder scope artifact.

#### `refine` (`home/.config/opencode/skills/refine/SKILL.md`)
- Incorporate the "Spec as vision document" perspective: proactively identify unstated edge cases, reasonable user expectations, failure modes, and technical constraints before handing off.
- Sizing ticket breakdowns as single checkable deliverables.

#### `handoff` (`home/.config/opencode/skills/handoff/SKILL.md`)
- Add explicit verification checklist before generating the final liftable hand-off artifact (no TBDs, confirmed interfaces, explicit acceptance criteria, zero reliance on external memory).

---

### 3.4 Data Agent & Skills

#### `data.md` (`home/.config/opencode/agents/data.md`)
- Update description and stage guidance with normalization evidence gates and distribution anomaly checks.

#### `ingest` (`home/.config/opencode/skills/ingest/SKILL.md`)
- Add data normalization evidence gates: never claim a dataset is ingested or normalized without verifying row counts, schema conformity, and column null rates against source files.

#### `analyze` (`home/.config/opencode/skills/analyze/SKILL.md`)
- Add convergence and distribution anomaly checks: single-pass analysis explicitly sanity-checks aggregations against raw totals and calls out outliers or data skews rather than blindly reporting summaries.

#### `report` (`home/.config/opencode/skills/report/SKILL.md`)
- Add output format and metric verification: enforce that all reported numbers tie back to analysis artifacts, formats match the user's requested deliverable, and narrative conclusions strictly reflect empirical findings.

---

### 3.5 Engineer Agent (`home/.config/opencode/agents/engineer.md`)

- **Core Principles:** Integrate references to the standalone `test-driven-development` and `verification-before-completion` skills.
- **Orchestration Discipline:** Add "Rulings, not stalls" (decide non-catastrophic plan conflicts with recorded rationale rather than parking sessions) and continuous execution rules.
- **Pre-Work Checklist:** Keep mandatory branch checks and `AGENTS.md` reading.

---

## 4. Verification Plan

1. **Syntax & Formatting Check:** Verify all Markdown and YAML frontmatter across modified and new files under `home/.config/opencode/`.
2. **SDO Description Hygiene Check:** Ensure all frontmatter `description` fields in all 15 skills follow trigger-conditions-only format (e.g., "Use when...").
3. **No External Broken Links:** Verify that all skill references link correctly within the self-contained skills library.
4. **Git Status & Diff Inspection:** Ensure clean staging and commit of the design document and subsequent implementation tasks.
