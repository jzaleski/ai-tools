---
name: debugging
description: "Use when encountering a bug, test failure, or unexpected behavior, before proposing or applying any fix."
---

# Debugging Skill

Find the root cause before touching any code. A fix that addresses a symptom instead of its cause tends to resurface later, often in a harder-to-diagnose form. Symptom fixes are failure.

<HARD-GATE>
Do NOT propose or apply a fix until you can state the root cause and point to evidence for it (an error message, a reproduction, a traced data flow). "It's probably X" is not evidence — reproduce it or trace it first.
</HARD-GATE>

**Always announce at start:** "I'm using the debugging skill to investigate this before fixing anything."

## The Process

### 1. Reproduce and Gather Evidence

- **Reproduce consistently:** Trigger the failure yourself if at all possible. If you can't reproduce it reliably, say so explicitly and gather more evidence (logs, error output, exact steps) before guessing — do not skip straight to a fix because reproduction is inconvenient.
- **Read error messages and stack traces completely:** Note exact file paths, line numbers, and error codes — they usually point directly at the cause. Don't skip past warnings or preceding errors.

#### Multi-Component Boundary Diagnostic Instrumentation

When a system has multiple components or layers (e.g., CI → build → signing, API → service → database, orchestrator → worker → filesystem):

**Before proposing fixes, add diagnostic instrumentation at boundaries:**
1. Log what data **enters** each component boundary.
2. Log what data **exits** each component boundary.
3. Verify environment and configuration propagation across boundaries.
4. Check state at each layer.

Run once to gather evidence showing **where** the chain breaks, analyze the evidence to identify the failing boundary, then investigate that specific component.

Example (multi-layer diagnostic logging):
```bash
# Layer 1: Workflow / entry
echo "=== Input parameters: ==="
echo "TARGET: ${TARGET:-UNSET}"

# Layer 2: Intermediate processing
echo "=== Resolved environment: ==="
printenv TARGET >/dev/null 2>&1 && echo "TARGET in environment" || echo "TARGET not in environment"

# Layer 3: Execution boundary
echo "=== Boundary invocation ==="
command --target "$TARGET" --verbose
```
This reveals exactly which layer fails (e.g., entry has input, but intermediate processing failed to export it).

### 2. Check Recent Changes and Compare Patterns

- **Check recent changes:** `git diff`, `git log -p` on the affected files/area. What changed that could explain this? Look for new dependency versions, config changes, environment differences.
- **Find working examples:** Locate similar working code in the same codebase. Compare the working case against the broken case line by line. Don't assume a difference "can't matter" — list every difference.
- **Understand dependencies and assumptions:** What other components, settings, or environmental prerequisites does this path assume?

### 3. Trace to the Source (Root-Cause Tracing)

When a bug manifests deep in execution or a stack trace (e.g., a file written to the wrong location, empty parameter, or unexpected null):

**Never fix just where the error appears.** That is treating a symptom. Trace backward through the call chain until you find the original trigger:

```
[Immediate Failure Point] (e.g., function fails with invalid input)
        ▲
        │ Ask: What called this with the bad value?
[Caller Layer] (e.g., passed variable from state/param)
        ▲
        │ Ask: Where did that value originate?
[Original Trigger] (e.g., uninitialized default, missing config, unhandled promise)
        ▲
  Fix here at the source!
```

1. **Observe the symptom:** Identify the exact failing operation and invalid value.
2. **Find the immediate cause:** What code directly executed with the bad state?
3. **Ask: What called this?** Inspect the call chain.
4. **Keep tracing up:** Inspect each parameter passed along the chain until you find where the invalid value originated.
5. **Fix at the source:** Fix the code where the bad value or state is created, not at the downstream consumer.

#### Stack Trace Instrumentation

When you cannot trace backward manually through inspection alone, add diagnostic instrumentation right before the problematic call:

```typescript
// Before the problematic operation
const stack = new Error().stack;
console.error('DEBUG trace:', {
  inputVal,
  cwd: process.cwd(),
  stack,
});
```
- In tests, use stderr / `console.error` (standard loggers may be buffered or suppressed).
- Log *before* the dangerous operation executes, capturing parameters, relevant environment state, and a stack trace.
- Inspect the output to find the exact caller and parameters triggering the issue.

### 4. Form One Hypothesis, Test It Minimally

- **Form a single hypothesis:** State it explicitly: "I think X is the root cause because Y evidence."
- **Test minimally:** Make the smallest possible change that tests the hypothesis. Change one variable at a time — never stack multiple speculative fixes and re-run to see what sticks.
- **Evaluate results:**
  - If the hypothesis is confirmed, proceed to implementation.
  - If the hypothesis is refuted, form a NEW hypothesis based on what you learned. Do not layer a second fix on top of the first without understanding why the first didn't work.

### 5. Fix Root Cause, Defend in Depth, and Verify

- **Implement single root-cause fix:** Address the root cause identified. No unrelated "while I'm here" refactoring or speculative adjustments.
- **Write a regression test:** Create a failing test case that reproduces the bug before the fix and passes with it. If the project has a test suite, run it to verify no regressions.

#### Defense-in-Depth Validation

A bug caught at only one location can easily be reintroduced through another path, refactoring, or mocked calls. Once the root cause is fixed, add validation and guards at multiple layers:

- **Layer 1: Entry Point Validation:** Reject invalid input immediately at public API or boundary methods (throw or return descriptive errors).
- **Layer 2: Business Logic Validation:** Validate state invariants inside intermediate processors before proceeding with operations.
- **Layer 3: Environment & Context Guards:** Guard against dangerous operations in sensitive contexts (e.g., prevent writes outside temporary directories during test runs).
- **Layer 4: Debug / Forensic Logging:** Retain diagnostic logging or assertions before critical operations for rapid troubleshooting.

#### Condition-Based Waiting (Eliminate Flaky Timeouts)

When debugging asynchronous or concurrent issues, **never rely on arbitrary sleep/delay intervals** (`sleep(100)`, `setTimeout(..., 50)`). Arbitrary delays create flaky tests and race conditions that fail under system load.

- **Rule:** Wait for the *actual condition* you care about (state transition, file existence, event emitted), polled on a short interval with an explicit timeout.
- **Pattern:**
```typescript
async function waitFor<T>(
  condition: () => T | undefined | null | false,
  description: string,
  timeoutMs = 5000
): Promise<T> {
  const start = Date.now();
  while (true) {
    const val = condition();
    if (val) return val;
    if (Date.now() - start > timeoutMs) {
      throw new Error(`Timeout waiting for ${description} after ${timeoutMs}ms`);
    }
    await new Promise(r => setTimeout(r, 10)); // Poll every 10ms
  }
}
```
- **Only exception:** If testing actual timing behavior (e.g., debounce intervals or throttle windows), an explicit timeout is appropriate — always document *why* with a comment.

#### Verification Before Completion

Run the project's actual test or reproduction command fresh in this turn and read the full output before declaring the issue resolved. Never assume a fix works based on a diff or a prior test run.

## Escalation Cap: Question Architecture After 3 Failed Fixes

After **3 failed fix attempts** on the same issue, STOP. Do not attempt a 4th fix variation.

Three consecutive failed fixes is a clear signal that the problem is not a simple bug: the **underlying architecture or pattern itself may be fundamentally flawed**.

### Signs of an Architectural Problem:
- Each fix reveals new shared state, unexpected coupling, or breaks something in a different place.
- Each fix attempt requires increasingly complicated workarounds or "massive refactoring".
- Each fix creates new symptoms elsewhere.
- The code fights the abstraction or framework conventions.

### Stop and Question Fundamentals:
1. Is this architecture or pattern fundamentally sound for this problem?
2. Are we persisting with this approach purely through inertia?
3. Should we refactor the architecture vs. continue fixing symptoms?

### How to Escalate:
- **If working directly with the user (inline):** Stop and state:
  "Three fix attempts have failed. Each attempt revealed [symptoms/coupling]. This indicates the current architecture or pattern around [component] may be fundamentally flawed rather than having a local bug. I recommend stepping back to reconsider the design instead of trying fix #4. Here is what we know..."
- **If running as a dispatched sub-agent (e.g., via `coder`):** Stop and report status `BLOCKED` using `coder`'s escalation format:
  - Explain what was attempted in all 3 tries.
  - Explain the evidence indicating an architectural mismatch.
  - Outline potential architectural alternatives for the orchestrator/user.

## Red Flags

**Never:**
- Say "quick fix for now, I'll investigate properly later"
- Propose a fix based on "it's probably X" without reproduction or traced data flow
- Propose fixes before adding boundary logging in multi-component systems
- Fix where the symptom appeared instead of tracing backward to the original trigger
- Change multiple variables at once "to save time"
- Use arbitrary `sleep()` / `setTimeout()` to patch race conditions
- Attempt a 4th fix variation without stopping to question the architecture
- Report a bug as resolved without running fresh verification in the current turn

**Always:**
- Reproduce the failure (or explicitly state why it cannot be reproduced) before modifying code
- Instrument component boundaries when failures span multiple systems
- Trace backward through call chains to locate the true root cause
- Add multi-layer defense-in-depth checks after fixing the root cause
- Replace arbitrary sleeps with condition-based polling
- Stop and question architectural assumptions after 3 failed fix attempts
- Verify fresh with real test/reproduction commands before completing

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The bug is obvious, no need to trace it" | Obvious-looking bugs often have root causes elsewhere in the call chain. Tracing takes less time than a wrong fix plus rework. |
| "I don't have time to reproduce it, I'll just patch the symptom" | An unreproduced "fix" is a blind guess. Guesses that miss waste more time than systematic reproduction. |
| "Fixing at the error site is cleaner" | Patching where the error surfaces hides bad data originating earlier, allowing the bug to escape along other code paths. |
| "One validation check is enough" | Single checks are easily bypassed by alternative callers, refactors, or mocks. Add defense in depth across layers. |
| "A small sleep/delay will fix the race condition" | Sleeps make tests slow and flaky under load. Always poll for the specific condition. |
| "Fourth fix attempt, but this one will work" | 3 failed fixes signal an architectural flaw or incomplete diagnosis. Stop and re-evaluate fundamentals. |
| "Tests passed before, they'll still pass" | Re-run them now in this turn. See the verification-before-completion principle. |
| "I'll write the regression test after confirming the fix" | Unverified fixes easily regress. Write or run the reproduction test to prove the fix. |

## Related

- **`coder`** — sub-agents invoke this skill first when a task is a bugfix.
- **`test-driven-development`** — create failing regression tests before applying fixes.
- **`verification-before-completion`** — verify fixes with fresh evidence before claiming resolution.
