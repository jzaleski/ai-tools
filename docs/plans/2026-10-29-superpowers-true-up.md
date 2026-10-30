# Superpowers v7.0.1 Toolkit True-Up Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Reconcile modern advancements from `obra/superpowers` (v7.0.1) into this repository's vendored `opencode` skills and agents per the approved design at `docs/specs/2026-10-29-superpowers-true-up-design.md`.

**Architecture:** Create two new standalone skills (`test-driven-development`, `verification-before-completion`) and update all existing skills (`researcher`, `planner`, `coder`, `debugging`, `reviewer`, `finisher`, `triage`, `scope`, `refine`, `handoff`, `ingest`, `analyze`, `report`) and agents (`engineer`, `product`, `data`) plus repository documentation (`AGENTS.md`, `README.md`, `docs/agents-and-skills.md`). All skills remain single self-contained `SKILL.md` files with strict trigger-conditions-only SDO frontmatter descriptions and hard tool execution gates.

**Tech Stack:** Markdown, YAML frontmatter, Shell verification.

---

### Task 1: Create standalone skills (`test-driven-development` and `verification-before-completion`)

**Files:**
- Create: `home/.config/opencode/skills/test-driven-development/SKILL.md`
- Create: `home/.config/opencode/skills/verification-before-completion/SKILL.md`

- [ ] **Step 1: Create skill directories**

Run: `mkdir -p home/.config/opencode/skills/test-driven-development home/.config/opencode/skills/verification-before-completion`

- [ ] **Step 2: Write `home/.config/opencode/skills/test-driven-development/SKILL.md`**

Write `home/.config/opencode/skills/test-driven-development/SKILL.md` containing:
- SDO frontmatter: `name: test-driven-development`, `description: "Use when implementing any feature or bugfix, before writing implementation code."`
- The Iron Law: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"
- Red-Green-Refactor cycle:
  - RED: Write failing test, verify it fails with expected reason (feature missing, not typo/error).
  - GREEN: Minimal code to pass; no YAGNI features. Verify it passes.
  - Suite-wide green requirement: "Other tests" means the project's entire test suite, not just the single test file. Any pre-existing failures must be reported by name.
  - REFACTOR: Clean up duplication and naming while keeping tests green.
- Embedded Good Tests guidelines (from `writing-good-tests`):
  - Name the production change that would make the test fail before writing it.
  - Assert on real behavior, never on mock behavior.
  - Keep test-only helpers out of production classes.
  - Understand dependencies before mocking.
- Red Flags and Common Rationalizations table.

- [ ] **Step 3: Write `home/.config/opencode/skills/verification-before-completion/SKILL.md`**

Write `home/.config/opencode/skills/verification-before-completion/SKILL.md` containing:
- SDO frontmatter: `name: verification-before-completion`, `description: "Use when about to claim work is complete, fixed, or passing, before committing or creating PRs."`
- The Iron Law: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"
- The Gate Function:
  1. IDENTIFY: What command proves this claim?
  2. RUN: Execute the FULL command (fresh, complete).
  3. READ: Full output, check exit code, count failures.
  4. VERIFY: Does output confirm the claim?
  5. ONLY THEN: Make the claim.
- Common Failures table (Tests pass, Linter clean, Build succeeds, Bug fixed, Regression test works, Agent completed, Requirements met).
- Red Flags and Rationalization Prevention table.

- [ ] **Step 4: Verify files and frontmatter**

Run: `head -4 home/.config/opencode/skills/test-driven-development/SKILL.md home/.config/opencode/skills/verification-before-completion/SKILL.md`

---

### Task 2: Modernize `researcher` and `planner` skills

**Files:**
- Modify: `home/.config/opencode/skills/researcher/SKILL.md`
- Modify: `home/.config/opencode/skills/planner/SKILL.md`

- [ ] **Step 1: Update `home/.config/opencode/skills/researcher/SKILL.md`**

Update `researcher` to reconcile Superpowers v7 brainstorming:
- Preserve SDO frontmatter: `name: researcher`, `description: "Use before writing any implementation plan or code — when requirements need clarifying, approaches need exploring, or a design needs approval."`
- Add "Look Before You Ask": Deeply explore project context, existing code, and referenced specs before first response. Never ask what the project already answers.
- Add "First Message" standard: ~200 words reflecting request back (what, who, why), project connections and constraints, inviting corrections, and concluding with ONE open question on the biggest unsettled requirement.
- Add "How it gets made": Probe early on platform, language, and library choices the user wants to own vs. delegate.
- Add "Size the Work": Differentiate small changes (short design doc) from projects (full written design doc).
- Add "Builder Check": Before presenting for approval, run an internal builder check sorting open questions into: Already Answered, Minor (settled as author's call), and Theirs (single user round).
- Add Red Flags table and Common Rationalizations.

- [ ] **Step 2: Update `home/.config/opencode/skills/planner/SKILL.md`**

Update `planner` to reconcile Superpowers v6.4.2+ writing-plans:
- Preserve SDO frontmatter: `name: planner`, `description: "Use when a design has been approved and needs to be broken down into executable implementation tasks."`
- Update "What a Step Contains" (Decisions, not transcripts): A plan records decisions (signatures, files, spec values, test names and assertions); code bodies only for algorithms not determined by signature and tests.
- Add `Global Constraints` and `Review Focus` sections to the Plan Document Header.
- Add `Interfaces` block (`Consumes:`, `Produces:`) to every task definition.
- Define task right-sizing: smallest unit carrying its own test cycle and reviewer gate.
- Add Proportion check to Self-Review: if plan is much longer than the spec, replace code transcripts with signatures and assertions.
- Preserve independence analysis and same-shape batching.

- [ ] **Step 3: Verify updates**

Run: `grep -E "Look Before You Ask|Builder Check|Global Constraints|Review Focus|Consumes:" home/.config/opencode/skills/{researcher,planner}/SKILL.md`

---

### Task 3: Modernize `coder` and `reviewer` skills

**Files:**
- Modify: `home/.config/opencode/skills/coder/SKILL.md`
- Modify: `home/.config/opencode/skills/reviewer/SKILL.md`

- [ ] **Step 1: Update `home/.config/opencode/skills/coder/SKILL.md`**

Update `coder`:
- Preserve SDO frontmatter: `name: coder`, `description: "Use when an orchestrator has an approved plan and needs an individual task implemented, tested, and reported back."`
- Reference standalone `skills/test-driven-development` and `skills/verification-before-completion`.
- Add suite-wide green verification: "other tests" means the project's entire test suite, not just the task's test file. Any pre-existing failures must be reported by name.
- Embed review reception discipline (from `receiving-code-review`): restate finding, verify against codebase reality before editing, technical reasoning if disagreeing, zero performative agreement ("You're absolutely right!"), YAGNI check on reviewer suggestions.

- [ ] **Step 2: Update `home/.config/opencode/skills/reviewer/SKILL.md`**

Update `reviewer`:
- Preserve SDO frontmatter: `name: reviewer`, `description: "Use after a coder task completes, or for a final cross-batch check, to verify spec compliance and code quality."`
- Add "The spec is a vision document": Spec silence is not permission for crashing or failing on reasonable user inputs; judge by reasonable user expectations.
- Add "Declined to judge": Explicitly list behaviors considered and set aside as outside the spec/plan, with rationale, before the verdict.
- Add Read-Only review rule: Review is strictly read-only; never mutate working tree, index, or HEAD.
- Add No-Subagents rule: Do not dispatch subagents to review part of the diff.
- Retain the 3-round review loop cap and calibration table (Critical / Important / Minor).

- [ ] **Step 3: Verify updates**

Run: `grep -E "suite|vision document|Declined to judge|Read-Only" home/.config/opencode/skills/{coder,reviewer}/SKILL.md`

---

### Task 4: Modernize `debugging` and `finisher` skills

**Files:**
- Modify: `home/.config/opencode/skills/debugging/SKILL.md`
- Modify: `home/.config/opencode/skills/finisher/SKILL.md`

- [ ] **Step 1: Update `home/.config/opencode/skills/debugging/SKILL.md`**

Update `debugging`:
- Preserve SDO frontmatter: `name: debugging`, `description: "Use when encountering a bug, test failure, or unexpected behavior, before proposing or applying any fix."`
- Add Multi-Component Boundary Diagnostic Instrumentation: step-by-step layer logging (inputs, outputs, environment) across component boundaries.
- Inline Root-Cause Tracing: backward call-stack tracing to identify original trigger.
- Inline Defense in Depth: multi-layer validation after fixing root cause.
- Inline Condition-Based Waiting: polling for observable state rather than arbitrary timeouts.
- Update Escalation Cap: if 3 fix attempts fail, explicitly question whether the architecture/pattern is fundamentally unsound.
- Add Red Flags and Rationalizations table.

- [ ] **Step 2: Update `home/.config/opencode/skills/finisher/SKILL.md`**

Update `finisher`:
- Preserve SDO frontmatter: `name: finisher`, `description: "Use when implementation is complete and every task has passed review, before deciding how to merge, publish, or otherwise integrate the work."`
- Update worktree removal refusal: if `git worktree remove` refuses due to untracked or uncommitted files, never `--force`. Present options to the user: (1) commit them to branch, (2) move them to main repo, or (3) delete.
- Add post-merge test verification: if tests fail after local merge into base branch, stop and investigate before deleting any branch or worktree.
- Add Common Rationalizations table.

- [ ] **Step 3: Verify updates**

Run: `grep -E "Multi-Component|Root-Cause Tracing|Condition-Based|refusal|Worktree removal refused" home/.config/opencode/skills/{debugging,finisher}/SKILL.md`

---

### Task 5: Modernize product agent and product skills

**Files:**
- Modify: `home/.config/opencode/agents/product.md`
- Modify: `home/.config/opencode/skills/triage/SKILL.md`
- Modify: `home/.config/opencode/skills/scope/SKILL.md`
- Modify: `home/.config/opencode/skills/refine/SKILL.md`
- Modify: `home/.config/opencode/skills/handoff/SKILL.md`

- [ ] **Step 1: Update `home/.config/opencode/agents/product.md`**

Update `product.md`:
- Tighten description and routing guidance.
- Reinforce verification before completion and anti-drift rules.

- [ ] **Step 2: Update `home/.config/opencode/skills/triage/SKILL.md`**

Update `triage`:
- Preserve SDO frontmatter: `name: triage`, `description: "Use when a raw, unsorted inbound request arrives and needs to be classified and routed before any other work begins."`
- Add Red Flags and Common Rationalizations table.
- Clarify explicit criteria for the 5 routing destinations (Product Shaping, Engineering Direct, Data Pipeline, Needs-Info, Not-Actionable).

- [ ] **Step 3: Update `home/.config/opencode/skills/scope/SKILL.md`**

Update `scope`:
- Preserve SDO frontmatter: `name: scope`, `description: "Use when a stakeholder or user has an idea or request — too vague or too broad — that needs to become a right-sized, refinable artifact."`
- Incorporate Socratic playback: echoing stakeholder intent back in plain words with guesses marked as guesses.
- Strictly enforce boundaries: capture *what* and *why* while keeping technical implementation details out.

- [ ] **Step 4: Update `home/.config/opencode/skills/refine/SKILL.md`**

Update `refine`:
- Preserve SDO frontmatter: `name: refine`, `description: "Use when an existing stakeholder scope artifact needs technical maturation before it is ready to hand off to engineering."`
- Add "Spec as vision document" perspective: proactively identify unstated edge cases, reasonable user expectations, and failure modes.
- Size ticket breakdowns as single checkable deliverables.

- [ ] **Step 5: Update `home/.config/opencode/skills/handoff/SKILL.md`**

Update `handoff`:
- Preserve SDO frontmatter: `name: handoff`, `description: "Use when a refined scope brief exists and is ready to be packaged for engineering, before any work reaches the engineer agent."`
- Add verification checklist before generating final liftable hand-off artifact (no TBDs, confirmed interfaces, explicit acceptance criteria, zero reliance on external memory).

- [ ] **Step 6: Verify updates**

Run: `head -4 home/.config/opencode/skills/{triage,scope,refine,handoff}/SKILL.md`

---

### Task 6: Modernize data agent and data skills

**Files:**
- Modify: `home/.config/opencode/agents/data.md`
- Modify: `home/.config/opencode/skills/ingest/SKILL.md`
- Modify: `home/.config/opencode/skills/analyze/SKILL.md`
- Modify: `home/.config/opencode/skills/report/SKILL.md`

- [ ] **Step 1: Update `home/.config/opencode/agents/data.md`**

Update `data.md`:
- Tighten description and stage handoffs.
- Add data normalization evidence gates and distribution anomaly checks.

- [ ] **Step 2: Update `home/.config/opencode/skills/ingest/SKILL.md`**

Update `ingest`:
- Preserve SDO frontmatter: `name: ingest`, `description: "Use when you have one or more raw files (PDF, XLSX, CSV/TSV, JSON, HTML, Markdown, plain text) that need extracting, cleaning, and normalizing into one dataset."`
- Add data normalization evidence gates: verify row counts, schema conformity, and column null rates against source files before claiming normalization is complete.
- Add Red Flags and Common Rationalizations table.

- [ ] **Step 3: Update `home/.config/opencode/skills/analyze/SKILL.md`**

Update `analyze`:
- Preserve SDO frontmatter: `name: analyze`, `description: "Use after data has been ingested and normalized, when you need aggregations, groupings, comparisons, trends, outliers, distributions, or joins — insight rather than just extraction."`
- Add convergence and distribution anomaly checks: sanity-check aggregations against raw totals and call out outliers or data skews.

- [ ] **Step 4: Update `home/.config/opencode/skills/report/SKILL.md`**

Update `report`:
- Preserve SDO frontmatter: `name: report`, `description: "Use when analysis findings exist and need to be delivered as a polished output in a specific format, once analysis is done."`
- Add output format and metric verification: enforce that all reported numbers tie back to analysis artifacts and formats match the requested deliverable.

- [ ] **Step 5: Verify updates**

Run: `head -4 home/.config/opencode/skills/{ingest,analyze,report}/SKILL.md`

---

### Task 7: Update `engineer.md`, `AGENTS.md`, `README.md`, and `docs/agents-and-skills.md`

**Files:**
- Modify: `home/.config/opencode/agents/engineer.md`
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `docs/agents-and-skills.md`

- [ ] **Step 1: Update `home/.config/opencode/agents/engineer.md`**

Update `engineer.md`:
- Core Principles: Reference standalone `skills/test-driven-development` and `skills/verification-before-completion`.
- Path C orchestration: Add "Rulings, not stalls" (decide non-catastrophic plan conflicts with recorded rationale rather than parking sessions) and continuous execution.

- [ ] **Step 2: Update `AGENTS.md`**

Update `AGENTS.md`:
- Update skills list in Project Structure tree and overview sentence to include `test-driven-development` and `verification-before-completion` (total 15 skills).

- [ ] **Step 3: Update `README.md`**

Update `README.md`:
- Update skills list in Directory Structure tree and overview descriptions to include `test-driven-development` and `verification-before-completion`.

- [ ] **Step 4: Update `docs/agents-and-skills.md`**

Update `docs/agents-and-skills.md`:
- Update skill counts (13 → 15 skills).
- Add sections for `test-driven-development` and `verification-before-completion`.
- Update descriptions of modernized skills (`researcher`, `planner`, `coder`, `debugging`, `reviewer`, `finisher`).

- [ ] **Step 5: Verification of cross-references**

Run: `rg "skills/" AGENTS.md README.md docs/agents-and-skills.md`

---

## Parallel Dispatch Analysis

### Batch 1 (Independent — dispatch together):
- Task 1 (Standalone skills: `test-driven-development`, `verification-before-completion`)
- Task 2 (Engineering skills: `researcher`, `planner`)
- Task 3 (Engineering skills: `coder`, `reviewer`)
- Task 4 (Engineering skills: `debugging`, `finisher`)
- Task 5 (Product agent & skills: `product.md`, `triage`, `scope`, `refine`, `handoff`)
- Task 6 (Data agent & skills: `data.md`, `ingest`, `analyze`, `report`)

*Rationale:* Each task touches a completely distinct set of files under `home/.config/opencode/`. There are no shared files or cross-file write conflicts among Tasks 1 through 6.

### Batch 2 (Depends on Batch 1):
- Task 7 (`engineer.md`, `AGENTS.md`, `README.md`, `docs/agents-and-skills.md`)

*Rationale:* Task 7 updates the top-level documentation and orchestrator contracts to reflect all 15 skills and modernized behaviors created in Batch 1.
