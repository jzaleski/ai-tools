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

## Red Flags

**Never:**
- Say "quick fix for now, I'll investigate properly later"
- Propose a fix based on "it's probably X" without having reproduced or traced anything
- Change more than one thing at once "to save a round trip"
- Report a fix as done without having just run the check that proves it
- Reach for fix attempt #4 on the same issue without questioning the approach

**Always:**
- Reproduce the failure (or explicitly say you couldn't) before proposing anything
- Trace to the source — fix where the problem originates, not where it surfaced
- Test one hypothesis at a time, with the smallest change that proves or disproves it
- Run the verification check fresh, this turn, before calling anything fixed
- Stop and reconsider the approach after 3 failed fix attempts, rather than trying a 4th

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
