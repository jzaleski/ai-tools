---
name: planner
description: "Use when a design has been approved and needs to be broken down into executable implementation tasks."
---

# Planner — Task Decomposition Skill

Write detailed, executable implementation plans that sub-agents (coders) can follow without any additional context. Plans assume the engineer has zero familiarity with the codebase. Assume they write idiomatic code in the project's language once they know the exact interface and the exact test, and that they will make a reasonable choice wherever the plan leaves one open.

What an implementer cannot know is what you decided: which files, which names and signatures, which values from the spec, which tests prove each task. Document those. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

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

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate. When drawing task boundaries:
- Fold setup, configuration, scaffolding, and documentation steps into the task whose deliverable needs them.
- Split only where a reviewer could meaningfully reject one task while approving its neighbor.
- Each task ends with an independently testable deliverable.

## Bite-Sized Step Granularity

**Each step is one action with a checkable result (2-5 minutes):**
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

**Spec:** [path to the spec/design doc this plan implements — the plan argues from the spec, so the spec travels with it; executors read both]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits, naming and copy rules, platform requirements — one line each, with exact values copied verbatim from the spec. Every task's requirements implicitly include this section.]

## Review Focus

[Up to 5 input classes or failure modes the spec implies but no task's tests exercise that are most likely to bite a person using this software — one line each, naming the input or condition and the behavior a reasonable person would expect, most likely first. The spec is a vision document: it says what the software must do, not everything it will meet, and its silence on an input is not permission for that input to break the program. Write the list here, once, with the spec in front of you. Then, for each line, add the test that pins it to the task that owns the code, in that task's own step style.]

---
```

## Task Structure

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter and return types. A task's implementer sees only their own task; this block is how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Implement `function(input: InputType) -> ResultType` in `exact/path/to/file.py`**

[One line on the approach when the signature and the test leave a choice (which library call, which data structure); a code block only for an algorithm they do not determine.]

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
```

## What a Step Contains (Decisions, Not Transcripts)

A step is done when the implementer can write exactly one reasonable thing from it. That is the whole requirement: unambiguous, not complete. Each kind of step carries what makes it unambiguous and nothing more:

- **A test step:** the test's name and its assertions, as code, with the spec's exact values in them.
- **A code step:** the exact signature (name, parameters, return type), the file it lives in, and the specific values the spec pins. The implementer writes the body. A body appears only for an algorithm the signature and tests do not determine, or for exact copy the spec fixes.
- **A verification step:** the command to run and the output that means it passed.
- **A reference to another task:** that task's Interfaces block says what to use; the plan does not repeat that task's code.

A plan is the set of decisions the implementer cannot make alone. A plan longer than the code it describes has written the code instead. Lines that decide nothing ("TBD", "handle edge cases", "add appropriate validation", "write tests for the above", a type or function no task defines) are the opposite failure, and self-review catches both.

## No Placeholders (Enforced)

Every step must contain the actual decisions an implementer needs. These are **plan failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without test names and assertions)
- "Similar to Task N" (repeat signatures and assertions — the implementer may be reading tasks out of order)
- Steps that describe what to do without showing exact signatures, files, or assertions
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

After writing the complete plan, look at the spec with fresh eyes and check the plan against it:

**1. Spec coverage:** Skim each requirement in the design doc. Can you point to a task that implements it? List any gaps.

**2. Step scan:** Every step must let the implementer write exactly one reasonable thing, and no step may carry more than that: a line that decides nothing is a gap, a function body the signature and tests already determine is a transcript. Fix both.

**3. Type consistency:** Do the types, method signatures, and property names used in later tasks match what was defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

**4. Review Focus:** For each input class or failure mode the spec implies, is there a task whose tests exercise it? The five uncovered ones most likely to bite a person go in the Review Focus section, and each line there gets its test added to the owning task.

**5. Proportion check:** Compare the plan's length to the spec's. If the plan is several times longer than the spec it implements, it is a transcript of the program, not a plan. If code blocks dominate the document, replace bodies with signatures, test names, and assertions, and check that each step remains unambiguous.

If you find issues, fix them inline. If a spec requirement has no task, add the task.

## Execution Handoff

After saving the plan:

> "Plan complete and saved to `docs/plans/<filename>.md`. Ready for parallel dispatch via skills/coder."

The plan is now ready for the orchestrating agent to execute — it will dispatch coders in batches per the independence analysis. No further handoff needed from this skill.

## Key Principles

- Decisions, not transcripts: signatures, files, spec values, test names/assertions
- Exact file paths always
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits
- Task right-sizing: smallest unit carrying its own test cycle and reviewer gate
- Independence analysis and same-shape batching enable efficient parallel dispatch
