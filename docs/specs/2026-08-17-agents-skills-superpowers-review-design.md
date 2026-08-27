# Agents & Skills Review: Enhancements from `obra/superpowers` — Design

**Status:** Approved
**Author:** engineer agent (with jzaleski)
**Date:** 2026-08-17

## Background

The `home/.config/opencode` agents and skills were originally derived from
`obra/superpowers`, then fully internalized (`7c0ef24 feat: Remove reliance
on superpowers`, May 2026) and evolved independently since. This spec is the
output of a comparative review against the current upstream `superpowers`
skill library (`brainstorming`, `writing-plans`, `subagent-driven-development`,
`executing-plans`, `requesting-code-review`, `receiving-code-review`,
`systematic-debugging`, `verification-before-completion`,
`test-driven-development`, `dispatching-parallel-agents`,
`finishing-a-development-branch`, `using-git-worktrees`, `writing-skills`,
`using-superpowers`) plus a self-review of this repo's own skills
(`researcher`, `planner`, `coder`, `reviewer`, `finisher`, `ingest`,
`analyze`, `report`, `scope`, `refine`, `handoff`, `triage`) and agents
(`engineer`, `data`, `product`).

**Repo is the source of truth.** All changes land under
`home/.config/opencode/` in this repository; the bootstrap system installs
them into `~/.config/opencode`. No edits are made directly to the live
`~/.config/opencode` copy.

**Cross-model reliability requirement.** The user runs both Anthropic
(Bedrock Claude) and Google (Vertex Gemini) models, plus local llama.cpp
tiers (Qwen3.8, DeepSeek), and switches between them freely per session.
Gemini is observed to ask fewer clarifying questions than Claude before
acting. Every new piece of guidance that depends on the model *choosing* to
stop and ask — rather than being structurally forced to — gets phrased as an
explicit `HARD-GATE`/`CRITICAL` stop, matching the pattern this repo already
uses for Gemini tool-call compliance (see `engineer.md`'s "Gemini 3.1 Pro
Specific Adjustments" precedent in `AGENTS.md`). This applies to every new
skill/section below, not just the ones that look Gemini-specific.

## Goals

1. Fix a real correctness bug in `finisher` found during the comparison.
2. Close two skill gaps with no local equivalent: root-cause-first debugging,
   and a "no completion claims without fresh evidence" discipline.
3. Add missing guidance for how a coder responds to review feedback.
4. Tighten all skill frontmatter `description` fields to trigger-conditions-
   only (evidence-backed finding from upstream's own skill-authoring tests:
   a description that summarizes workflow causes agents to act on the
   description and skip reading the skill body).
5. Add a documentation-only, session-level model-weight suggestion to the
   engineer triage table — explicitly **not** auto-routing sub-agent
   dispatch to a hardcoded model, which would break cross-provider
   portability (see Non-Goals).
6. Make `finisher`'s destructive "discard" path opt-in-only, not a listed
   menu item.
7. Cap the reviewer fix-loop so it can't repeat indefinitely.
8. Add a "batch same-shape work" note to the planner's independence
   analysis.
9. Add a "sub-agents don't dispatch sub-agents" contract to `coder`.

## Non-Goals (explicitly rejected, with rationale)

- **Git worktrees / `using-git-worktrees` / ledger-per-plan workspaces.**
  Already a deliberate divergence (`engineer.md`: "Do NOT use git
  worktrees"). `finisher` already accommodates an externally-managed
  worktree if the host platform provides one; we don't need to start
  creating our own. No change.
- **`writing-skills`' full TDD-for-skills methodology** (pressure-scenario
  testing, rationalization tables, micro-testing wording against a
  no-guidance control). Valuable for a skills *library* maintained at
  scale; disproportionate ceremony for a personal-use repo with ~12 skills.
  We do cherry-pick its one concrete, cheap finding (description hygiene,
  Goal 4).
- **Model-tier-aware sub-agent dispatch** (superpowers' "Model Selection"
  heuristics — route mechanical tasks to a cheap model, architecture to the
  most capable). Implementing this for real requires binding a subagent
  definition to a literal `provider/model-id` in `opencode.json`. Since the
  user swaps between Bedrock, Vertex, and local llama.cpp per session, a
  hardcoded tier would pull in a fixed provider regardless of what the
  *session* is currently running on — exactly the portability breakage the
  user flagged as the top concern. Scoped down to Goal 5 (doc-only,
  session-level suggestion, no config/agent-definition changes, nothing
  that touches `opencode.json`'s `agent` block).
- **Superpowers' full `subagent-driven-development` ledger/round-escalation
  machinery** (progress ledger files surviving compaction, 5-round fix
  loops with automatic model-tier escalation on rounds 4–5, "breaker"
  adjudication). We adopt the *shape* of the idea (bounded rounds, then
  stop and surface to a human) at a lighter weight (Goal 7's 3-round cap,
  no automatic model swapping — see previous bullet).

## Detailed Design

### 1. Bug fix: `finisher` worktree-cleanup no-op

**File:** `home/.config/opencode/skills/finisher/SKILL.md`

**Problem:** Step 6 (Cleanup Workspace) recomputes `GIT_DIR`, `GIT_COMMON`,
and `WORKTREE_PATH` via fresh `git rev-parse` calls. But Option 1 (Merge
Locally) and Option 4 (Discard) both `cd` to `MAIN_ROOT` in Step 5 *before*
Step 6 runs. Once inside `MAIN_ROOT`, `git rev-parse --git-dir` and
`--git-common-dir` both resolve to the main repo's `.git`, so the "is this a
worktree?" check always says no — cleanup of an externally-managed worktree
silently never happens.

**Fix:** Capture `GIT_DIR`, `GIT_COMMON`, and `WORKTREE_PATH` once, in Step
2 (Detect Environment), before any `cd`. Steps 5 and 6 reuse those captured
values instead of recomputing. This only changes behavior when `finisher`
runs inside a worktree created by a host platform (Path C itself never
creates one) — in the normal-repo case captured-vs-recomputed values are
identical, so no behavior change there.

### 2. New skill: `debugging`

**File (new):** `home/.config/opencode/skills/debugging/SKILL.md`

A lightweight adaptation of `systematic-debugging`, matching this repo's
existing tone (direct, no "Iron Law" ASCII-box theatrics, but keeping the
one non-negotiable rule as a `HARD-GATE`). Covers:

- **HARD-GATE:** no fix proposed before root cause is understood — applies
  to any bug, test failure, or unexpected behavior.
- Reproduce → check recent changes (git diff/log) → trace the failure to its
  origin, not just where it surfaced.
- Form one specific hypothesis, test it minimally (smallest change that
  proves or disproads it), don't stack multiple speculative fixes at once.
- **Escalation cap:** after 3 failed fix attempts on the same issue, stop —
  this is a signal the approach (not just the fix) is wrong. Report back
  (if a sub-agent) or say so explicitly (if inline) rather than trying a
  4th variation.
- Fix the root cause, then run the **verification-before-completion**
  check (§3) before claiming it's resolved.
- Cross-references `coder`'s `BLOCKED`/`NEEDS_CONTEXT` escalation statuses
  for sub-agent use, and is invocable inline by `engineer` for Path A
  bugfixes.

**Wiring:**
- `engineer.md` Path A: when the task is a bugfix (not a green-field
  change), invoke `skills/debugging` before editing.
- `coder/SKILL.md`: when a dispatched task is a bugfix, invoke
  `skills/debugging` first; add it to the coder's "Before You Begin" list.
- `AGENTS.md`'s "Opencode Agent Configuration(s)" section: add `debugging`
  to the enumerated list of vendored skills.

### 3. Verification-before-completion — principle, not a skill

**Files:** `home/.config/opencode/agents/engineer.md` (Core Principles),
`home/.config/opencode/skills/coder/SKILL.md`,
`home/.config/opencode/skills/reviewer/SKILL.md`,
`home/.config/opencode/skills/finisher/SKILL.md`

Add one new bullet to `engineer.md`'s **Core Principles** list:

> **Verification before completion** — never claim something works, passes,
> or is fixed without having run the actual check in this turn. "Should
> pass" / "looks correct" / expressing satisfaction before running the
> command are the same violation as not checking at all. This applies to
> every status claim, not just final sign-off.

Reinforce at the three places code already claims success:
- `coder`'s Report Format / self-review: the `DONE` status requires the
  test command was *just run*, not remembered from earlier in the task.
- `reviewer`'s "Do Not Trust the Report" section: extend the existing
  distrust-of-the-implementer's-report principle with the same "would I
  have fresh evidence for this claim" framing.
- `finisher`'s Step 1: tests must be re-run fresh at finish time even if
  they passed earlier in the session (a later commit could have broken
  them).

No new skill file — this is a continuous discipline referenced at point of
use, not a phase with its own entry/exit.

### 4. Receiving code review — new section in `coder`

**File:** `home/.config/opencode/skills/coder/SKILL.md`

Add a **"Responding to Review Feedback"** section, used during the reviewer
fix-loop (§7):

- Restate the finding in your own words before fixing it; if genuinely
  unclear, this is a `HARD-GATE` — stop and ask rather than guess at intent.
- Verify against the actual codebase before implementing a suggested fix —
  don't blindly apply a reviewer's suggestion if it contradicts something
  you can point to in the code.
- If you believe a finding is wrong, say so with specific technical
  reasoning (file/line, behavior, test result) rather than complying
  silently or arguing without evidence. The orchestrator (not the coder)
  makes the final call on a disputed finding — the coder's job is to
  surface the disagreement clearly, not resolve it unilaterally.
- No performative agreement ("You're absolutely right!", "Great catch!").
  State the fix, or state the disagreement. Actions/technical statements
  only.

### 5. Skill description hygiene (all 12 local skills + new `debugging`)

**Files:** every `SKILL.md` under `home/.config/opencode/skills/`.

Rewrite each frontmatter `description` to cover triggering conditions only
("Use when...") with no summary of internal steps/workflow, per the
evidence cited in upstream's `writing-skills` skill: a description that
tells the model *how* the skill works lets it act on the description alone
and skip loading the skill body, silently dropping steps. Exact rewritten
text for each skill is a mechanical editing task (word-for-word new
descriptions land in the implementation plan, not here) — the design
constraint is: **third person, starts with "Use when", names concrete
triggers, zero workflow/process summary.**

### 6. Model-weight guidance — documentation only

**File:** `home/.config/opencode/agents/engineer.md`

Add a short note under the Scope Triage table (not a new mechanism, not a
config change):

> **Model choice is a session-level decision, not something this agent
> routes automatically.** As a rough guide: Path A (trivial) tolerates a
> lighter/faster model; Path C (design-heavy) benefits from your most
> capable available model, whichever provider that is this session. Sub-
> agents dispatched via `task` inherit the session's current model — there
> is no per-task model override in this setup, and none is added by this
> guidance, specifically to avoid hardcoding a provider and breaking your
> ability to swap between local and remote models freely.

This directly documents *why* we're not doing the fancier thing, so a
future pass doesn't reintroduce it by surprise.

### 7. `finisher`: remove "Discard" from the presented menu

**File:** `home/.config/opencode/skills/finisher/SKILL.md`

- Step 4 menu drops to the same **3 options** superpowers settled on (Merge
  locally / Push+PR / Keep as-is) for the normal-repo and named-worktree
  cases; detached HEAD drops to 2 (no merge option, as today, minus
  discard).
- Add a new subsection, reachable only when **the user explicitly asks to
  discard the work in so many words** (not inferred from "yeah get rid of
  it" or similar) — same typed-`discard` confirmation flow as today, just
  relocated out of the numbered menu.
- Update the Quick Reference table and Red Flags section to match.

### 8. `reviewer`: cap the fix-loop at 3 rounds

**File:** `home/.config/opencode/skills/reviewer/SKILL.md`

Add to the "Review Loop Protocol" section:

- Rounds 1–3: same implementer fixes, same reviewer re-reviews with
  identical inputs (unchanged from today).
- **After round 3**, if findings remain open: stop looping. The
  orchestrating agent presents the open findings directly to the user for a
  decision (fix differently / accept as a known issue / abandon the
  approach) instead of dispatching a 4th round automatically. No automatic
  model escalation (see Non-Goals) — just a hard stop that hands the
  decision back to a human instead of guessing.

### 9. `planner`: batch same-shape tasks

**File:** `home/.config/opencode/skills/planner/SKILL.md`

Add to "Independence Analysis": when several tasks in a batch are each a
small, identical-shape edit (same one-line fix / same field addition /
same rename, repeated across files), call this out explicitly in the
Parallel Dispatch Analysis output and recommend the orchestrator dispatch
**one coder covering the whole batch** rather than one coder per task —
reduces dispatch overhead for genuinely mechanical, repetitive work. This
is guidance for the plan's output, not a new planning phase.

### 10. `coder`: sub-agents don't dispatch sub-agents

**File:** `home/.config/opencode/skills/coder/SKILL.md`

Add one line near the top (near "Before You Begin" or "Your Job"): the
coder implements directly and never dispatches its own helper or reviewer
sub-agents — review arrives from the orchestrator after the coder reports,
never from a sub-agent the coder spawned itself. Prevents duplicate review
seats / context blow-up.

## Files Touched (summary)

| File | Change |
|---|---|
| `home/.config/opencode/skills/debugging/SKILL.md` | **New** |
| `home/.config/opencode/skills/finisher/SKILL.md` | Bug fix (capture timing), Discard menu removal, description rewrite, verification reinforcement |
| `home/.config/opencode/skills/coder/SKILL.md` | Debugging cross-ref, Responding to Review Feedback section, no-nested-subagents line, verification reinforcement, description rewrite |
| `home/.config/opencode/skills/reviewer/SKILL.md` | Fix-loop cap, verification reinforcement, description rewrite |
| `home/.config/opencode/skills/planner/SKILL.md` | Batch same-shape guidance, description rewrite |
| `home/.config/opencode/skills/researcher/SKILL.md` | Description rewrite only |
| `home/.config/opencode/skills/ingest/SKILL.md` | Description rewrite only |
| `home/.config/opencode/skills/analyze/SKILL.md` | Description rewrite only |
| `home/.config/opencode/skills/report/SKILL.md` | Description rewrite only |
| `home/.config/opencode/skills/scope/SKILL.md` | Description rewrite only |
| `home/.config/opencode/skills/refine/SKILL.md` | Description rewrite only |
| `home/.config/opencode/skills/handoff/SKILL.md` | Description rewrite only |
| `home/.config/opencode/skills/triage/SKILL.md` | Description rewrite only |
| `home/.config/opencode/agents/engineer.md` | Debugging skill wiring (Path A + dispatch template), Verification-before-completion principle, model-weight guidance note |
| `AGENTS.md` (repo root) | Add `debugging` to the enumerated skills list |

`data.md` and `product.md` are unaffected — the gaps found are specific to
the engineering lifecycle (researcher/planner/coder/reviewer/finisher);
`data` and `product` don't use those skills.

## Verification Approach

These are prompt/documentation changes with no executable test suite. Verification is:

1. **Consistency read-through** — every cross-reference between files (e.g.
   `engineer.md` pointing at `skills/debugging`, `coder` pointing at the
   verification principle) resolves to something that actually exists after
   all edits land.
2. **Frontmatter validity** — every rewritten `description` is still valid
   YAML frontmatter, third person, starts with "Use when", and (per
   `customize-opencode`) has no unknown top-level frontmatter fields.
3. **No behavior regression in `finisher`** — trace through Option 1 and
   Option 4 by hand (normal repo case) confirming the captured-vs-recomputed
   values are identical, so existing non-worktree behavior is unchanged.
4. **`AGENTS.md` skill-list stays accurate** — grep the skills directory
   list against the enumerated names in `AGENTS.md` after edits.

No opencode restart is required to review the diff, but per
`customize-opencode`, the user should restart their opencode session before
these changes take effect in a live session.

## Rollout

Single feature branch (`review-skills-vs-superpowers`, already created),
committed in logically-grouped commits (bug fix separate from new skill,
separate from description-hygiene sweep, etc. — exact grouping decided at
commit time), then through `finisher` at the end for the merge/PR decision.
