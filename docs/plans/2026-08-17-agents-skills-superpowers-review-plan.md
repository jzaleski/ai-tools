# Agents & Skills Review (vs. superpowers) Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Close the gaps and fix the bug identified when comparing this repo's local `opencode` agents/skills against upstream `obra/superpowers`, per the approved design at `docs/specs/2026-08-17-agents-skills-superpowers-review-design.md`.

**Architecture:** Pure prompt/documentation edits across `home/.config/opencode/{agents,skills}/` and the repo-root `AGENTS.md`. One new skill file (`debugging`); everything else is targeted edits to existing Markdown files. No executable code, no test suite — "verification" per task is a `grep`/`read` check that the exact text landed, plus a full consistency read-through as the final task.

**Tech Stack:** Markdown, YAML frontmatter (opencode skill/agent format).

---

### Task 1: Create the `debugging` skill

**Files:**
- Create: `home/.config/opencode/skills/debugging/SKILL.md`

- [ ] **Step 1: Create the directory and file**

Run: `mkdir -p home/.config/opencode/skills/debugging`

- [ ] **Step 2: Write the full skill file**

```markdown
---
name: debugging
description: "Use when encountering a bug, test failure, or unexpected behavior, before proposing or applying any fix."
---

# Debugging Skill

Find the root cause before touching any code. A fix that addresses a symptom instead of its cause tends to resurface later, often in a harder-to-diagnose form.

<HARD-GATE>
Do NOT propose or apply a fix until you can state the root cause and point to evidence for it (an error message, a reproduction, a traced data flow). "It's probably X" is not evidence — reproduce it or trace it first.
</HARD-GATE>

**Always announce at start:** "I'm using the debugging skill to investigate this before fixing anything."

## The Process

### 1. Reproduce

- Trigger the failure yourself if at all possible. If you can't reproduce it reliably, say so explicitly and gather more evidence (logs, error output, exact steps) before guessing — do not skip straight to a fix because reproduction is inconvenient.
- Read the full error message and stack trace. Note exact file paths, line numbers, and error codes — they usually point directly at the cause.

### 2. Check Recent Changes

- `git diff`, `git log -p` on the affected files/area. What changed that could explain this?
- New dependency versions, config changes, environment differences.

### 3. Trace to the Source

- If the bad value or behavior surfaces deep in a call stack, trace backward: what called this with the bad input? Keep going until you find where it actually originates — fix there, not where the symptom appeared.
- Find a working example of the same pattern elsewhere in the codebase and diff it against the broken case, line by line. Don't assume a difference "can't matter" — list every one.

### 4. Form One Hypothesis, Test It Minimally

- State it explicitly: "I think X is the root cause because Y evidence."
- Make the smallest possible change that would prove or disprove it. Change one variable at a time — never stack multiple speculative fixes and re-run to see what sticks.
- Hypothesis wrong? Form a new one from what you just learned. Don't layer a second fix on top of the first without understanding why the first didn't work.

### 5. Fix the Root Cause

- Address the cause you found, not the symptom. No unrelated "while I'm here" changes bundled into the same fix.
- Write or update a test that reproduces the original bug and fails without the fix, if the codebase has a test setup (see `AGENTS.md` for the project's test command). A fix with no regression test is unverified.
- Run the **verification-before-completion** check before calling it fixed: run the actual test/repro command in this turn and read its output. Do not report "fixed" from memory of an earlier run or because the diff "looks right."

## Escalation Cap

After **3 failed fix attempts** on the same issue, stop attempting a 4th variation. Three failures aiming at the same target and missing is a signal that the *approach* — not just the fix — is wrong, or that Steps 1-3 investigation was incomplete.

- **If invoked inline (Path A):** stop and tell the user directly what you tried, what you learned from each attempt, and that you believe the approach needs reconsidering before a 4th attempt.
- **If invoked as a dispatched sub-agent (via `coder`):** report back with status `BLOCKED`, using `coder`'s escalation format — describe what you tried, what you ruled out, and what kind of help would unblock you (more context, a different approach, a smaller/different task).

## Red Flags — Stop and Return to Step 1

- "Quick fix for now, I'll investigate properly later"
- "It's probably X" without having reproduced or traced anything
- Changing more than one thing at once "to save a round trip"
- About to report a fix as done without having just run the check that proves it
- Reaching for fix attempt #4 on the same issue without questioning the approach

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The bug is obvious, no need to trace it" | Obvious-looking bugs have root causes elsewhere often enough that tracing takes less time than a wrong fix plus rework. |
| "I don't have time to reproduce it, I'll just patch the symptom" | An unreproduced "fix" is a guess. Guesses that miss cost more time than the reproduction would have. |
| "Third fix attempt, but this one will work" | That's exactly the pattern the escalation cap exists for — stop and reconsider the approach instead. |
| "Tests passed before, they'll still pass" | Re-run them now. See the verification-before-completion principle. |

## Related

- **`coder`** — dispatched sub-agents invoke this skill first when a task is a bugfix, then report using `coder`'s status/report format.
- **Verification before completion** (principle in `engineer.md`'s Core Principles) — applies at Step 5 before any "fixed" claim.
```

- [ ] **Step 3: Verify frontmatter and structure**

Run: `sed -n '1,4p' home/.config/opencode/skills/debugging/SKILL.md`
Expected:
```
---
name: debugging
description: "Use when encountering a bug, test failure, or unexpected behavior, before proposing or applying any fix."
---
```

- [ ] **Step 4: Commit**

```bash
git add home/.config/opencode/skills/debugging/SKILL.md
git commit -m "feat: add debugging skill (root-cause-first discipline)"
```

---

### Task 2: Fix `finisher` worktree-cleanup bug, remove Discard from menu, add verification reinforcement, rewrite description

**Files:**
- Modify: `home/.config/opencode/skills/finisher/SKILL.md`

- [ ] **Step 1: Rewrite the frontmatter description**

Old:
```markdown
---
name: finisher
description: "Complete development work — verify tests pass, detect environment state, present structured merge/PR options to user, execute choice with proper cleanup."
mode: required
---
```

New:
```markdown
---
name: finisher
description: "Use when implementation is complete and every task has passed review, before deciding how to merge, publish, or otherwise integrate the work."
mode: required
---
```

- [ ] **Step 2: Reinforce fresh-verification wording in Step 1**

Old:
```markdown
### Step 1: Verify Tests

Before presenting options, run the project's test suite:

```bash
npm test    # JavaScript/TypeScript
cargo test  # Rust
pytest      # Python
go test ./...  # Go
```
```

New:
```markdown
### Step 1: Verify Tests

Before presenting options, run the project's test suite **fresh, right now**
— a passing run from earlier in the session doesn't count; a later commit
may have broken something since:

```bash
npm test    # JavaScript/TypeScript
cargo test  # Rust
pytest      # Python
go test ./...  # Go
```
```

- [ ] **Step 3: Fix the capture-timing bug in Step 2 (Detect Environment)**

Old:
```markdown
### Step 2: Detect Environment

Determine workspace state before presenting options:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | No cleanup (externally managed) |
```

New:
```markdown
### Step 2: Detect Environment

Determine workspace state before presenting options. **Capture all three
values now, before any `cd`** — Step 5 changes directory for Option 1 and
for a confirmed discard, and Step 6's cleanup needs the pre-`cd` values to
correctly detect a worktree:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 3 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 3 options | Provenance-based (Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 2 options (no merge) | Externally managed — leave in place |
```

- [ ] **Step 4: Drop "Discard" from the presented menu (Step 4: Present Options)**

Old:
```markdown
### Step 4: Present Options

**Normal repo and named-branch worktree — present exactly these 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Detached HEAD — present exactly these 3 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Which option?
```

Don't add explanation — keep options concise.
```

New:
```markdown
### Step 4: Present Options

**Normal repo and named-branch worktree — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?
```

**Detached HEAD — present exactly these 2 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

Don't add explanation — keep options concise. Discarding the work is never a
listed option — it happens only in response to an explicit, unambiguous
request (see "If the User Asks to Discard the Work" after Option 3 below).
```

- [ ] **Step 5: Add a fresh-verification comment to Option 1 (Merge Locally)**

Old:
```markdown
#### Option 1: Merge Locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>

# Only after merge succeeds: cleanup (Step 6), then delete branch
```
```

New:
```markdown
#### Option 1: Merge Locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result — run fresh now, don't reuse Step 1's result
<test command>

# Only after merge succeeds: cleanup (Step 6), then delete branch
```
```

- [ ] **Step 6: Rename "Option 4: Discard" to an explicit-request-only section**

Old:
```markdown
#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Work preserved at current working directory."

Don't cleanup. Don't delete anything.

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list, last 5 SHAs>

Type 'discard' to confirm.
```

Wait for exact typed confirmation. If confirmed:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Proceed to Step 6, then force-delete branch:
```bash
git branch -D <feature-branch>
```
```

New:
```markdown
#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Work preserved at current working directory."

Don't cleanup. Don't delete anything.

#### If the User Asks to Discard the Work

This path is reachable only when the user explicitly asks to discard the
work, in so many words — never inferred from "yeah get rid of it" or a
guess that they're done with the branch. It is not one of the numbered
options in Step 4.

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list, last 5 SHAs>

Type 'discard' to confirm.
```

Wait for exact typed confirmation. If confirmed:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Proceed to Step 6, then force-delete branch:
```bash
git branch -D <feature-branch>
```
```

- [ ] **Step 7: Fix Step 6 (Cleanup Workspace) to reuse captured values instead of recomputing**

Old:
```markdown
### Step 6: Cleanup Workspace

**Only runs for Options 1 and 4.** Options 2 and 3 always preserve the workspace.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If the current path is under `.worktrees/` or `worktrees/`:** We created this — we own cleanup.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment owns this workspace. Do NOT remove it. If the platform provides a workspace-exit tool, use it. Otherwise leave the workspace in place and report: "Workspace preserved (externally managed)."
```

New:
```markdown
### Step 6: Cleanup Workspace

**Only runs for Option 1 and a confirmed discard.** Options 2 and 3 always
preserve the workspace.

Use the `GIT_DIR`, `GIT_COMMON`, and `WORKTREE_PATH` values captured in
**Step 2** — do not recompute them here. Both callers (Option 1 and the
confirmed-discard path) have already `cd`'d to `MAIN_ROOT` by this point, so
a fresh `git rev-parse` would report "normal repo" unconditionally and
silently skip cleanup of a real worktree.

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/`:** We created this — we own cleanup.

```bash
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment owns this workspace. Do NOT remove it. If the platform provides a workspace-exit tool, use it. Otherwise leave the workspace in place and report: "Workspace preserved (externally managed)."
```

- [ ] **Step 8: Update the Quick Reference table**

Old:
```markdown
## Quick Reference

| Option | Merge Locally | Push | Keep Workspace | Cleanup Branch |
|--------|--------------|------|----------------|----------------|
| 1. Merge locally | ✅ | — | ❌ | ✅ |
| 2. Create PR | — | ✅ | ✅ | — |
| 3. Keep as-is | — | — | ✅ | — |
| 4. Discard | — | — | ❌ | ✅ (force) |
```

New:
```markdown
## Quick Reference

| Option | Merge Locally | Push | Keep Workspace | Cleanup Branch |
|--------|--------------|------|----------------|----------------|
| 1. Merge locally | ✅ | — | ❌ | ✅ |
| 2. Create PR | — | ✅ | ✅ | — |
| 3. Keep as-is | — | — | ✅ | — |
| Discard (explicit request only, not a listed option) | — | — | ❌ | ✅ (force) |
```

- [ ] **Step 9: Update the Red Flags section**

Old:
```markdown
## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Remove a workspace before confirming merge success
- Clean up workspaces you didn't create (provenance check)
- Run `git worktree remove` from inside the workspace being removed

**Always:**
- Verify tests before offering options
- Detect environment before presenting menu
- Present exactly 4 options (or 3 for detached HEAD)
- Get typed confirmation for Option 4
- Cleanup only for Options 1 and 4
- `cd` to main repo root before any worktree removal
- Run `git worktree prune` after removal
```

New:
```markdown
## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result — run them fresh, don't reuse an earlier result
- List discarding the work as a numbered option, or infer a discard request from anything short of an explicit, unambiguous ask
- Delete work without typed confirmation
- Force-push without explicit request
- Remove a workspace before confirming merge success
- Clean up workspaces you didn't create (provenance check)
- Run `git worktree remove` from inside the workspace being removed
- Recompute `GIT_DIR`/`GIT_COMMON`/`WORKTREE_PATH` in Step 6 — reuse the values captured in Step 2, before any `cd`

**Always:**
- Verify tests before offering options, and again, fresh, before merging (Step 5, Option 1)
- Detect environment before presenting menu, capturing worktree state before any `cd`
- Present exactly 3 options (or 2 for detached HEAD) — discard is never listed
- Get typed confirmation before any discard
- Cleanup only for Option 1 and a confirmed discard
- `cd` to main repo root before any worktree removal
- Run `git worktree prune` after removal
```

- [ ] **Step 10: Verify no stale references remain**

Run: `grep -n "Option 4\|4 options\|3 options" home/.config/opencode/skills/finisher/SKILL.md`
Expected: no matches (empty output) — confirms every reference to the old 4-option/3-option menu and "Option 4" label was updated.

- [ ] **Step 11: Commit**

```bash
git add home/.config/opencode/skills/finisher/SKILL.md
git commit -m "fix: finisher captures worktree state before cd, drops Discard from menu"
```

---

### Task 3: Update `coder` skill — debugging cross-ref, review-response guidance, no-nested-dispatch, verification, description

**Files:**
- Modify: `home/.config/opencode/skills/coder/SKILL.md`

- [ ] **Step 1: Rewrite the frontmatter description**

Old:
```markdown
---
name: coder
description: "Sub-agent implementer — executes individual tasks from a plan with TDD, self-review, and structured reporting. For orchestrators: dispatch this skill per independent task, then follow the review pipeline."
---
```

New:
```markdown
---
name: coder
description: "Use when an orchestrator has an approved plan and needs an individual task implemented, tested, and reported back."
---
```

- [ ] **Step 2: Add the bugfix/debugging cross-reference and no-nested-dispatch constraint**

Old:
```markdown
## Before You Begin

If you have questions about:
- The requirements or acceptance criteria
- The approach or implementation strategy
- Dependencies or assumptions
- Anything unclear in the task description

**Ask them now.** Raise any concerns before starting work. Don't guess or make assumptions.

## Your Job
```

New:
```markdown
## Before You Begin

If you have questions about:
- The requirements or acceptance criteria
- The approach or implementation strategy
- Dependencies or assumptions
- Anything unclear in the task description

**Ask them now.** Raise any concerns before starting work. Don't guess or make assumptions.

## If This Task Is a Bugfix

<HARD-GATE>
Do not edit code to fix a bug, test failure, or unexpected behavior until you have invoked `skills/debugging` and can state the root cause with evidence. This applies even under time pressure or when the fix looks obvious.
</HARD-GATE>

New features and refactors don't need this — only tasks whose goal is fixing broken behavior.

## Constraints

- **Never dispatch your own sub-agents.** You implement directly. If you need
  a second opinion or a review, report back to the orchestrator (`BLOCKED`
  or `DONE_WITH_CONCERNS`) instead of spawning a helper or reviewer
  yourself — review always comes from the orchestrator after your report,
  never from an agent you spawned.

## Your Job
```

- [ ] **Step 3: Add "Responding to Review Feedback" section, before "Report Format"**

Old:
```markdown
If you find issues during self-review, fix them now before reporting.

## Report Format
```

New:
```markdown
If you find issues during self-review, fix them now before reporting.

## Responding to Review Feedback

When the orchestrator sends you back review findings to fix, this replaces "Before You Begin" for that round:

1. **Restate each finding in your own words before touching code.** If any
   finding is unclear, this is a **HARD-GATE** — stop and ask the
   orchestrator for clarification rather than guessing at intent. Items can
   be related; a partial fix based on a guess is often wrong for reasons
   you won't see until later.
2. **Verify against the actual code before implementing the suggested
   fix.** A reviewer's suggestion can be wrong for this codebase even when
   it's generically reasonable — check before applying it.
3. **If you believe a finding is wrong, say so with specific evidence**
   (file:line, behavior, a test result) rather than silently complying or
   arguing without evidence. State the disagreement clearly; the
   orchestrator decides how to resolve it — that call isn't yours to make
   unilaterally.
4. **No performative agreement.** Don't write "You're absolutely right!" or
   "Great catch!" — state the fix you made, or state your disagreement.
   Actions and technical statements only.
5. Fix one item at a time, verify each, then move to the next.

## Report Format
```

- [ ] **Step 4: Add fresh-verification wording to the Self-Review Checklist**

Old:
```markdown
**Testing:**
- Do tests actually verify behavior (not just mock behavior)?
- Did I follow TDD if required?
- Are tests comprehensive?
```

New:
```markdown
**Testing:**
- Do tests actually verify behavior (not just mock behavior)?
- Did I follow TDD if required?
- Are tests comprehensive?
- Did I run the tests **just now**, in this turn, rather than relying on an earlier run or assuming they'd still pass?
```

- [ ] **Step 5: Add fresh-verification note above the Report Format code block**

Old:
```markdown
## Report Format

When done, report using this exact format:

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
```

New:
```markdown
## Report Format

Every `Tests:` line in the report below must reflect a command you ran in
this turn — not a result remembered from earlier in the task. When done,
report using this exact format:

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
```

- [ ] **Step 6: Verify structure**

Run: `grep -n "^## " home/.config/opencode/skills/coder/SKILL.md`
Expected output includes, in order: `## Before You Begin`, `## If This Task Is a Bugfix`, `## Constraints`, `## Your Job`, `## Formatting`, `## Code Organization`, `## When You're in Over Your Head`, `## Self-Review Checklist`, `## Responding to Review Feedback`, `## Report Format`.

- [ ] **Step 7: Commit**

```bash
git add home/.config/opencode/skills/coder/SKILL.md
git commit -m "feat: coder cross-refs debugging skill, adds review-response and no-nested-dispatch guidance"
```

---

### Task 4: Update `reviewer` skill — fix-loop cap, verification reinforcement, description

**Files:**
- Modify: `home/.config/opencode/skills/reviewer/SKILL.md`

- [ ] **Step 1: Rewrite the frontmatter description**

Old:
```markdown
---
name: reviewer
description: "Dual-role review skill — handles both spec compliance review (did they build what was requested?) and code quality review (is it well-built?). Orchestrators dispatch this per completed task or for final cross-batch validation."
---
```

New:
```markdown
---
name: reviewer
description: "Use after a coder task completes, or for a final cross-batch check, to verify spec compliance and code quality."
---
```

- [ ] **Step 2: Add a verification bullet to "Do Not Trust the Report"**

Old:
```markdown
**DO:**
- Read the actual code they wrote
- Compare actual implementation to requirements line by line
- Check for missing pieces they claimed to implement
- Look for extra features they didn't mention
```

New:
```markdown
**DO:**
- Read the actual code they wrote
- Compare actual implementation to requirements line by line
- Check for missing pieces they claimed to implement
- Look for extra features they didn't mention
- Re-run any test command the report cites rather than trusting its stated
  result — the same verification-before-completion standard you'd apply to
  your own claims applies to reviewing theirs
```

- [ ] **Step 3: Add the fix-loop round cap**

Old:
```markdown
## Review Loop Protocol (For Orchestrators)

When a review finds issues:
1. The same implementer sub-agent fixes them
2. The orchestrator dispatches the same reviewer again with identical inputs
3. Repeat until APPROVED or PASS
4. Never skip the re-review — even if the implementer says "I fixed it"
5. Never move to the next task while any review has open issues
```

New:
```markdown
## Review Loop Protocol (For Orchestrators)

When a review finds issues:
1. The same implementer sub-agent fixes them
2. The orchestrator dispatches the same reviewer again with identical inputs
3. Repeat until APPROVED or PASS, **up to 3 rounds total**
4. Never skip the re-review — even if the implementer says "I fixed it"
5. Never move to the next task while any review has open issues

**Cap:** If round 3's re-review still reports open issues, stop looping.
Don't dispatch a 4th round and don't guess at a resolution. Present the open
findings directly to the user: what's still failing, what's been tried each
round, and let them decide whether to fix differently, accept the issue as a
known limitation, or abandon the current approach.
```

- [ ] **Step 4: Verify**

Run: `grep -n "up to 3 rounds\|Cap:" home/.config/opencode/skills/reviewer/SKILL.md`
Expected: both lines present, non-empty output.

- [ ] **Step 5: Commit**

```bash
git add home/.config/opencode/skills/reviewer/SKILL.md
git commit -m "feat: reviewer caps fix-loop at 3 rounds, reinforces fresh verification"
```

---

### Task 5: Update `planner` skill — batch same-shape work, description

**Files:**
- Modify: `home/.config/opencode/skills/planner/SKILL.md`

- [ ] **Step 1: Rewrite the frontmatter description**

Old:
```markdown
---
name: planner
description: "Write comprehensive implementation plans from approved designs — task decomposition with exact file paths, code, commands. Includes independence analysis for parallel dispatch and no-placeholder enforcement."
---
```

New:
```markdown
---
name: planner
description: "Use when a design has been approved and needs to be broken down into executable implementation tasks."
---
```

- [ ] **Step 2: Add "same-shape work" guidance to Independence Analysis**

Old:
```markdown
**Dependent tasks (must be sequential):**
- Task B depends on code that Task A creates
- Both tasks modify the same file
- Integration work that requires a specific component to exist first

Output an analysis at the end of the plan:
```

New:
```markdown
**Dependent tasks (must be sequential):**
- Task B depends on code that Task A creates
- Both tasks modify the same file
- Integration work that requires a specific component to exist first

**Same-shape work (batch into one dispatch, not one coder per task):**
- Several tasks that are each a small, identical-shape edit — the same
  one-line fix, the same field addition, the same rename — repeated across
  different files
- Dispatch ONE coder with the whole batch listed (every file and its exact
  change) rather than one coder per file. Reserve one-dispatch-per-task for
  work that needs its own judgment, its own tests, or its own review
  surface — not for mechanical repetition.

Output an analysis at the end of the plan:
```

- [ ] **Step 3: Add a same-shape example line to the Parallel Dispatch Analysis output template**

Old:
```markdown
### Batch 1 (independent — dispatch together):
- Task 1 (src/auth/login.ts) + Task 3 (src/api/routes.ts) + Task 5 (docs/README.md)
  Rationale: No shared files, no cross-dependencies
```

New:
```markdown
### Batch 1 (independent — dispatch together):
- Task 1 (src/auth/login.ts) + Task 3 (src/api/routes.ts) + Task 5 (docs/README.md)
  Rationale: No shared files, no cross-dependencies
- Tasks 6-9 (same one-line config rename across 4 files) — dispatch as ONE coder covering all 4, not 4 separate coders
  Rationale: Identical-shape mechanical edit; one review surface covers all four
```

- [ ] **Step 4: Verify**

Run: `grep -n "Same-shape work\|Batch into one dispatch" home/.config/opencode/skills/planner/SKILL.md`
Expected: at least one match for "Same-shape work".

- [ ] **Step 5: Commit**

```bash
git add home/.config/opencode/skills/planner/SKILL.md
git commit -m "feat: planner flags same-shape work for single-batch dispatch"
```

---

### Task 6: Update `engineer.md` — debugging wiring, verification principle, model-weight guidance

**Files:**
- Modify: `home/.config/opencode/agents/engineer.md`

- [ ] **Step 1: Add `debugging` to the Tool Usage Instructions example list**

Old:
```markdown
When this workflow requires a skill (e.g., triage, scope, researcher, planner, ingest, analyze), **you MUST literally invoke the `skill` tool** using the exact skill name. DO NOT simulate the skill, output its steps from memory, or skip the tool call. You must halt and wait for the `skill` tool to return the specific instructions.
```

New:
```markdown
When this workflow requires a skill (e.g., triage, scope, researcher, planner, debugging, ingest, analyze), **you MUST literally invoke the `skill` tool** using the exact skill name. DO NOT simulate the skill, output its steps from memory, or skip the tool call. You must halt and wait for the `skill` tool to return the specific instructions.
```

- [ ] **Step 2: Add the Verification-before-completion principle to Core Principles**

Old:
```markdown
- **Consistency** — match the style, naming conventions, and patterns already present in the codebase. Read surrounding files before writing new ones.
- **No silent TODOs** — never leave `TODO` or `FIXME` comments without an explanation of why and what unblocks them.

## Architecture
```

New:
```markdown
- **Consistency** — match the style, naming conventions, and patterns already present in the codebase. Read surrounding files before writing new ones.
- **No silent TODOs** — never leave `TODO` or `FIXME` comments without an explanation of why and what unblocks them.
- **Verification before completion** — never claim something works, passes, or is fixed without having run the actual check in this turn. "Should pass," "looks correct," or any expression of satisfaction before running the command is the same violation as not checking at all. Applies to every status claim you make, not just final sign-off.

## Architecture
```

- [ ] **Step 3: Add the model-weight guidance note to Scope Triage**

Old:
```markdown
**Promotion rule:** If you start on Path A and discover the change is actually multi-subsystem, stop and restart on Path B. If you start on Path B and discover ambiguity or need for design, stop and restart on Path C. Never silently drift between paths mid-execution.

## Commit Discipline
```

New:
```markdown
**Promotion rule:** If you start on Path A and discover the change is actually multi-subsystem, stop and restart on Path B. If you start on Path B and discover ambiguity or need for design, stop and restart on Path C. Never silently drift between paths mid-execution.

**Model choice is a session-level decision, not something this agent routes
automatically.** As a rough guide: Path A (trivial) tolerates a
lighter/faster model; Path C (design-heavy) benefits from your most capable
available model, whichever provider that is this session. Sub-agents
dispatched via `task` inherit the session's current model — there is no
per-task model override in this setup, deliberately, so that switching
between local and remote providers mid-workflow never breaks.

## Commit Discipline
```

- [ ] **Step 4: Add the debugging step to Path A**

Old:
```markdown
## Path A: Direct (Trivial Changes)

1. Read relevant files before making changes — never assume structure or types.
2. Make the smallest change that solves the problem correctly.
3. Run a verifier: syntax check, type check, or the relevant test(s). If the repo has a standard test command in `AGENTS.md`, use it. **If verification fails, fix and retry once. If it still fails, explain the error to the user and stop — do not leave broken code claiming the change is done.**
4. Apply the commit discipline rules above.

That's it. No skills, no sub-agents, no ceremony.
```

New:
```markdown
## Path A: Direct (Trivial Changes)

1. Read relevant files before making changes — never assume structure or types.
2. **If this is a bugfix** (not a new addition), invoke `skills/debugging` first — root cause before any edit. Skip this step for new features, config tweaks, or other non-bugfix changes.
3. Make the smallest change that solves the problem correctly.
4. Run a verifier: syntax check, type check, or the relevant test(s). If the repo has a standard test command in `AGENTS.md`, use it — run it fresh now, not from memory of an earlier pass. **If verification fails, fix and retry once. If it still fails, explain the error to the user and stop — do not leave broken code claiming the change is done.**
5. Apply the commit discipline rules above.

That's it. No skills, no sub-agents, no ceremony — except `skills/debugging` for bugfixes, which is itself skill-free ceremony (no sub-agent dispatch, just a structured inline process).
```

- [ ] **Step 5: Add `debugging` to the Sub-Agent Dispatch skill categorization**

Old:
```markdown
**Interactive skills — load inline via the `skill` tool:**
- `researcher`, `planner`, `finisher` (require user dialogue)

**Non-interactive skills — dispatch via the `task` tool with `subagent_type: general`:**
- `coder`, `reviewer` (no user interaction; need write access, so `explore` is unsuitable)
```

New:
```markdown
**Interactive skills — load inline via the `skill` tool:**
- `researcher`, `planner`, `finisher` (require user dialogue)
- `debugging` (also loaded inline when `engineer` itself is fixing a Path A bugfix — see Path A)

**Non-interactive skills — dispatch via the `task` tool with `subagent_type: general`:**
- `coder`, `reviewer` (no user interaction; need write access, so `explore` is unsuitable)
- `coder` invokes `debugging` itself, inline within its own sub-agent context, when its dispatched task is a bugfix
```

- [ ] **Step 6: Verify**

Run: `grep -n "skills/debugging\|Verification before completion\|Model choice is a session-level" home/.config/opencode/agents/engineer.md`
Expected: at least 4 matches (Path A reference, Sub-Agent Dispatch reference ×2, Core Principles bullet, model-weight note).

- [ ] **Step 7: Commit**

```bash
git add home/.config/opencode/agents/engineer.md
git commit -m "feat: engineer wires debugging skill, adds verification principle and model-weight guidance"
```

---

### Task 7: Update repo-root `AGENTS.md` — add `debugging` to the enumerated skill lists

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Update the engineering-lifecycle skill list**

Old:
```markdown
Workflow skills are vendored locally under `home/.config/opencode/skills/`. The engineering lifecycle uses researcher, planner, coder, reviewer, and finisher; the data pipeline uses ingest, analyze, and report; the product funnel uses triage, scope, refine, and handoff. No external plugin dependencies.
```

New:
```markdown
Workflow skills are vendored locally under `home/.config/opencode/skills/`. The engineering lifecycle uses researcher, planner, coder, debugging, reviewer, and finisher; the data pipeline uses ingest, analyze, and report; the product funnel uses triage, scope, refine, and handoff. No external plugin dependencies.
```

- [ ] **Step 2: Update the Project Structure skills enumeration**

Old:
```markdown
│   │   ├── skills/                        # Vendored workflow skills (analyze, coder, finisher, handoff, ingest, planner, refine, report, researcher, reviewer, scope, triage)
```

New:
```markdown
│   │   ├── skills/                        # Vendored workflow skills (analyze, coder, debugging, finisher, handoff, ingest, planner, refine, report, researcher, reviewer, scope, triage)
```

- [ ] **Step 3: Verify**

Run: `grep -n "debugging" AGENTS.md`
Expected: 2 matches (one per edit above).

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md
git commit -m "docs: add debugging skill to AGENTS.md enumerated skill lists"
```

---

### Task 8: Description-hygiene sweep (8 skills, description-only changes — single batched dispatch)

**Files:**
- Modify: `home/.config/opencode/skills/analyze/SKILL.md`
- Modify: `home/.config/opencode/skills/ingest/SKILL.md`
- Modify: `home/.config/opencode/skills/report/SKILL.md`
- Modify: `home/.config/opencode/skills/scope/SKILL.md`
- Modify: `home/.config/opencode/skills/refine/SKILL.md`
- Modify: `home/.config/opencode/skills/handoff/SKILL.md`
- Modify: `home/.config/opencode/skills/triage/SKILL.md`
- Modify: `home/.config/opencode/skills/researcher/SKILL.md`

This task is identical-shape mechanical work (one frontmatter line per file)
— per Task 5's new planner guidance, dispatch this as **one coder covering
all 8 files**, not 8 separate coders.

- [ ] **Step 1: `analyze/SKILL.md`**

Old: `description: "Answer a question or find patterns in a clean dataset — aggregations, groupings, comparisons, trends, outliers, distributions, joins. Use after data has been ingested and normalized, when the user wants insight rather than just extraction. Single-pass; produces findings, not a formatted report."`

New: `description: "Use after data has been ingested and normalized, when you need aggregations, groupings, comparisons, trends, outliers, distributions, or joins — insight rather than just extraction."`

- [ ] **Step 2: `ingest/SKILL.md`**

Old: `description: "Pull data out of raw files (PDF, XLSX, CSV/TSV, JSON, HTML, Markdown, plain text), clean each one, and converge everything into one consistent dataset ready for analysis. Use when you have a pile of messy files to extract and normalize. Scales from one file to many via an explicit parallelism ladder."`

New: `description: "Use when you have one or more raw files (PDF, XLSX, CSV/TSV, JSON, HTML, Markdown, plain text) that need extracting, cleaning, and normalizing into one dataset."`

- [ ] **Step 3: `report/SKILL.md`**

Old: `description: "Deliver analysis findings as a polished output in one or more formats — Markdown, CSV, XLSX, JSON, plain text, or inline. Use as the final pipeline stage once analysis is done. Always asks for the format if unspecified, and always documents the artifacts and scripts it created."`

New: `description: "Use when analysis findings exist and need to be delivered as a polished output in a specific format, once analysis is done."`

- [ ] **Step 4: `scope/SKILL.md`**

Old: `description: "Stakeholder requirements-intake skill — helps a stakeholder or user, via a series of structured prompts, turn their ideas or requests into a right-sized, refinable scope artifact. Adaptive: asks a few high-leverage questions when a request isn't specific enough, drafts-and-trims when it's too broad. Honest about what a non-technical stakeholder cannot know. Stand-alone; does not hand off to other agents."`

New: `description: "Use when a stakeholder or user has an idea or request — too vague or too broad — that needs to become a right-sized, refinable artifact."`

- [ ] **Step 5: `refine/SKILL.md`**

Old: `description: "Technical product-manager skill — matures a stakeholder scope artifact into a system-aware, ticket-ready brief in collaboration with engineering. Augments the same document in place with system considerations, authoritative scope, complexity, resolved open questions, and a ticket breakdown. Stand-alone; does not hand off to other agents."`

New: `description: "Use when an existing stakeholder scope artifact needs technical maturation before it is ready to hand off to engineering."`

- [ ] **Step 6: `handoff/SKILL.md`**

Old: `description: "Engineering hand-off packaging skill — turns a refined scope brief into a self-contained, liftable engineering hand-off artifact that seeds the engineer agent's design phase. Produces a separate liftable artifact; stand-alone; points to the engineer agent but never invokes it."`

New: `description: "Use when a refined scope brief exists and is ready to be packaged for engineering, before any work reaches the engineer agent."`

- [ ] **Step 7: `triage/SKILL.md`**

Old: `description: "Inbound request triage skill — the front door of the product work-shaping funnel. Classifies a raw, unsorted request into a routing bucket (product shaping, engineering, data, needs-info, or not-actionable) and produces a fast triage decision artifact. Single-pass; inline-only; stand-alone — recommends a next step but never invokes another agent or skill."`

New: `description: "Use when a raw, unsorted inbound request arrives and needs to be classified and routed before any other work begins."`

- [ ] **Step 8: `researcher/SKILL.md`**

Old: `description: "Mandatory pre-work step — explores project context, asks clarifying questions one at a time, proposes approaches, presents design for user approval. Terminal state: user-approved design doc ready for planning."`

New: `description: "Use before writing any implementation plan or code — when requirements need clarifying, approaches need exploring, or a design needs approval."`

- [ ] **Step 9: Verify all 8 descriptions start with "Use"**

Run:
```bash
for f in analyze ingest report scope refine handoff triage researcher; do
  grep -H "^description:" "home/.config/opencode/skills/$f/SKILL.md"
done
```
Expected: 8 lines, each of the form `description: "Use ...`.

- [ ] **Step 10: Commit**

```bash
git add home/.config/opencode/skills/analyze/SKILL.md home/.config/opencode/skills/ingest/SKILL.md home/.config/opencode/skills/report/SKILL.md home/.config/opencode/skills/scope/SKILL.md home/.config/opencode/skills/refine/SKILL.md home/.config/opencode/skills/handoff/SKILL.md home/.config/opencode/skills/triage/SKILL.md home/.config/opencode/skills/researcher/SKILL.md
git commit -m "docs: rewrite skill descriptions to trigger-conditions-only (SDO hygiene)"
```

---

### Task 9: Final consistency pass (sequential — depends on all prior tasks)

**Files:** none created/modified — read-only verification across the whole tree.

- [ ] **Step 1: Confirm every skill directory has valid, unique frontmatter**

Run:
```bash
for f in home/.config/opencode/skills/*/SKILL.md; do
  echo "=== $f ==="
  sed -n '1,3p' "$f"
done
```
Expected: every file starts with `---`, a `name:` line matching its
directory name, and a `description:` line starting with `Use`, followed by
`---` (or, for `finisher`, `mode: required` before the closing `---`).

- [ ] **Step 2: Confirm `debugging` is referenced everywhere it should be**

Run: `grep -rn "skills/debugging\|\`debugging\`" AGENTS.md home/.config/opencode/agents/engineer.md home/.config/opencode/skills/coder/SKILL.md`
Expected: matches in all three files (AGENTS.md ×2, engineer.md ×4 from Task 6, coder/SKILL.md ×1 from Task 3).

- [ ] **Step 3: Confirm no leftover "Option 4" / old menu-count references anywhere**

Run: `grep -rn "Option 4\|4 options" home/.config/opencode/skills/finisher/SKILL.md`
Expected: no matches.

- [ ] **Step 4: Confirm the design doc's Files Touched table is fully accounted for**

Run: `git log --stat --oneline review-skills-vs-superpowers -- home/.config/opencode AGENTS.md`

Read the output and manually cross-check against the "Files Touched" table
in `docs/specs/2026-08-17-agents-skills-superpowers-review-design.md` — every
listed file should appear in at least one commit's stat. `data.md` and
`product.md` should NOT appear (confirmed out of scope in the design).

- [ ] **Step 5: No commit for this task** — it's a verification-only gate before handing off to the reviewer.

---

## Parallel Dispatch Analysis

### Batch 1 (fully independent — dispatch together):
- Task 1 (`home/.config/opencode/skills/debugging/SKILL.md`, new file)
- Task 2 (`home/.config/opencode/skills/finisher/SKILL.md`)
- Task 3 (`home/.config/opencode/skills/coder/SKILL.md`)
- Task 4 (`home/.config/opencode/skills/reviewer/SKILL.md`)
- Task 5 (`home/.config/opencode/skills/planner/SKILL.md`)
- Task 6 (`home/.config/opencode/agents/engineer.md`)
- Task 7 (`AGENTS.md`)
- Task 8 (8 files: `analyze`, `ingest`, `report`, `scope`, `refine`, `handoff`, `triage`, `researcher` — dispatched as ONE coder per the same-shape-work guidance being introduced in Task 5)

Rationale: every task touches a completely disjoint set of files. Task 6
(`engineer.md`) references the `debugging` skill by name/path, and Task 3
(`coder`) does the same, but neither requires Task 1's file to physically
exist first — the skill name (`debugging`) is fixed by the approved design,
so there's no ordering dependency, only a naming agreement already locked
in. Task 8 bundles 8 files into one dispatch because they're identical-shape
edits (frontmatter description only) — exactly the case Task 5's new
planner guidance describes.

### Batch 2 (depends on Batch 1):
- Task 9 (verification-only; reads the results of every prior task)

Rationale: Task 9 greps/inspects files that Tasks 1-8 create or modify. It
must run after all of them complete.

### Single tasks:
- None — every task above is part of Batch 1 or Batch 2.

## Self-Review

**1. Spec coverage** — every item in the design doc's "Detailed Design"
section (§1-§10) maps to a task: §1→Task 2, §2→Task 1 (+ wiring in Task 3/6),
§3→Task 6 (principle) + Tasks 2/3/4 (reinforcement), §4→Task 3, §5→Task 8
(+ description edits folded into Tasks 2/3/4/5/6's own file), §6→Task 6,
§7→Task 2, §8→Task 4, §9→Task 5, §10→Task 3. `data.md`/`product.md`
exclusion from the design's Files Touched table is respected — no task
touches them.

**2. Placeholder scan** — no "TBD"/"add appropriate X"/"similar to Task N"
patterns present; every step shows complete before/after text or a runnable
command with expected output.

**3. Type/naming consistency** — the skill name `debugging` is spelled
identically everywhere it's referenced (Tasks 1, 3, 6, 7, 9); the fix-loop
cap number (3) is consistent between Task 4 (reviewer) and the design doc;
the model-weight note in Task 6 doesn't introduce any `opencode.json`
change, matching the design's Non-Goals section.
