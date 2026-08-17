---
name: finisher
description: "Use when implementation is complete and every task has passed review, before deciding how to merge, publish, or otherwise integrate the work."
mode: required
---

# Finisher Skill

Guide completion of development work by presenting clear options and handling the chosen workflow. Use this when implementation is complete and all tasks have passed review.

**Always announce at start:** "I'm using the finisher skill to complete this work."

## The Process

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

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing.

[Show failures]

Cannot proceed with merge/PR until tests pass.
```
Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

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

### Step 3: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

If that fails, ask: "This branch split from which base branch? (main or master)"

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

### Step 5: Execute Choice

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

Then proceed to Step 6, then:
```bash
git branch -d <feature-branch>
```

#### Option 2: Push and Create PR

```bash
git push -u origin <feature-branch>

gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Do NOT clean up — the user needs the branch alive to iterate on PR feedback. Report: "PR created. Branch <name> is live for iteration."

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

## Quick Reference

| Option | Merge Locally | Push | Keep Workspace | Cleanup Branch |
|--------|--------------|------|----------------|----------------|
| 1. Merge locally | ✅ | — | ❌ | ✅ |
| 2. Create PR | — | ✅ | ✅ | — |
| 3. Keep as-is | — | — | ✅ | — |
| Discard (explicit request only, not a listed option) | — | — | ❌ | ✅ (force) |

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
