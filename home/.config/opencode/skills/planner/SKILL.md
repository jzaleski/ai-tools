---
name: planner
description: "Use when a design has been approved and needs to be broken down into executable implementation tasks."
---

# Planner — Task Decomposition Skill

Write detailed, executable implementation plans that sub-agents (coders) can follow without any additional context. Plans assume the engineer has zero familiarity with the codebase.

**Always announce at start:** "I'm using the planner skill to create the implementation plan."

## Prerequisites

- An approved design document from the researcher skill
- Read and understood `AGENTS.md` if it exists

## Save Plans To

`docs/plans/YYYY-MM-DD-<feature-name>.md`
(User preferences for plan location override this default.)

## Scope Check

If the spec covers multiple independent subsystems, suggest breaking into separate plans. Each plan should produce working, testable software on its own. If the user proceeds with a single plan covering multiple subsystems, structure it so each subsystem has clearly separated task groups.

## File Structure Mapping

Before defining tasks, map out which files will be created or modified:

- Design units with clear boundaries and well-defined interfaces
- Each file should have one clear responsibility
- Prefer smaller, focused files over large ones that do too much
- Files that change together should live together — split by responsibility, not technical layer
- Follow established patterns in existing codebases (don't unilaterally restructure)
- This structure informs task decomposition and parallel independence analysis

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" — step
- "Run it to make sure it fails" — step
- "Implement the minimal code to make the test pass" — step
- "Run the tests and make sure they pass" — step
- "Commit" — step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
```

## No Placeholders (Enforced)

Every step must contain the actual content an implementer needs. These are **plan failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the implementer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Independence Analysis (Critical for Parallel Dispatch)

After defining all tasks, analyze which ones can run in parallel:

**Independent tasks (can dispatch together):**
- Modify completely different files with no shared mutable state
- Different subsystems, different modules
- One modifies `src/auth/` and another modifies `src/api/`
- Doc updates alongside code changes

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

```markdown
## Parallel Dispatch Analysis

### Batch 1 (independent — dispatch together):
- Task 1 (src/auth/login.ts) + Task 3 (src/api/routes.ts) + Task 5 (docs/README.md)
  Rationale: No shared files, no cross-dependencies
- Tasks 6-9 (same one-line config rename across 4 files) — dispatch as ONE coder covering all 4, not 4 separate coders
  Rationale: Identical-shape mechanical edit; one review surface covers all four

### Batch 2 (depends on Batch 1):
- Task 4 (tests/integration/auth-api.test.ts)
  Rationale: Requires both auth module and API routes to exist before testing

### Single tasks:
- Task 2 (src/models/user.ts) — standalone, can run whenever
```

## Self-Review

After writing the complete plan, check it yourself:

**1. Spec coverage:** Skim each requirement in the design doc. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search for red flags — any of the "No Placeholders" patterns above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names used in later tasks match what was defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. If a spec requirement has no task, add the task.

## Execution Handoff

After saving the plan:

> "Plan complete and saved to `docs/plans/<filename>.md`. Ready for parallel dispatch via skills/coder."

The plan is now ready for the orchestrating agent to execute — it will dispatch coders in batches per the independence analysis. No further handoff needed from this skill.

## Key Principles

- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits
- Independence analysis enables parallel dispatch (saves wall-clock time)
