---
name: finisher
description: "Complete development work — verify tests pass, detect environment state, present structured merge/PR options to user, execute choice with proper cleanup."
mode: required
---

# Finisher Skill

Guide completion of development work by presenting clear options and handling the chosen workflow. Use this when implementation is complete and all tasks have passed review.

**Always announce at start:** "I'm using the finisher skill to complete this work."

## The Process

### Step 1: Verify Tests

Before presenting options, run the project's test suite:

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

### Step 3: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

If that fails, ask: "This branch split from which base branch? (main or master)"

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

# Verify tests on merged result
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

## Quick Reference

| Option | Merge Locally | Push | Keep Workspace | Cleanup Branch |
|--------|--------------|------|----------------|----------------|
| 1. Merge locally | ✅ | — | ❌ | ✅ |
| 2. Create PR | — | ✅ | ✅ | — |
| 3. Keep as-is | — | — | ✅ | — |
| 4. Discard | — | — | ❌ | ✅ (force) |

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
