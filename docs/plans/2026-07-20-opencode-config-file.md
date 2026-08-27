# Merged `.opencode-config` File Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Replace the plain-text `.opencode-model` file with a JSON `.opencode-config` file that defaults both `--model` and `--agent` for the `opencode` wrapper, keep `.last-opencode-session` separate/gitignored/unchanged, and migrate the 7 known external repos to the new format.

**Architecture:** `home/.local/lib/opencode.sh` gains a unified config-reading section that validates `.opencode-config` as JSON via `jq empty`, extracts `.model`/`.agent` via `jq -r`, and appends `--model`/`--agent` to `"$@"` only when the caller didn't already pass the corresponding flag — mirroring the existing `.opencode-model` precedence logic exactly, just generalized to two keys and one file. Documentation (`README.md`, `AGENTS.md`) is updated to describe the new file and its precedence/error-handling rules. Seven external repos under `~/src/` get their `.opencode-model` converted to `.opencode-config` with the old file removed.

**Tech Stack:** Bash, `jq` (already a required binary in this repo).

**Design doc:** `docs/specs/2026-07-20-opencode-config-file-design.md`

---

### Task 1: Replace `.opencode-model` logic with `.opencode-config` in the wrapper

**Files:**
- Modify: `home/.local/lib/opencode.sh`

- [ ] **Step 1: Update the file header comment to mention the new behavior**

Read the current header (lines 1-13):

```bash
#!/usr/bin/env bash
#
# opencode wrapper script
#
# This script wraps the opencode CLI to provide additional functionality:
#   1. Persists the last session ID to .last-opencode-session in the repo root
#   2. Resumes sessions via --continue by reading the persisted session ID
#   3. Resets opencode history/cache on new sessions (configurable via env vars)
#
# The session persistence enables resuming sessions even after moving the repo
# to a different location on the filesystem, which is useful when working across
# multiple repositories.
```

Replace it with:

```bash
#!/usr/bin/env bash
#
# opencode wrapper script
#
# This script wraps the opencode CLI to provide additional functionality:
#   1. Persists the last session ID to .last-opencode-session in the repo root
#   2. Resumes sessions via --continue by reading the persisted session ID
#   3. Resets opencode history/cache on new sessions (configurable via env vars)
#   4. Reads default --model/--agent values from .opencode-config (JSON) in
#      the repo root if present, applied only when not already passed on
#      the command line
#
# The session persistence enables resuming sessions even after moving the repo
# to a different location on the filesystem, which is useful when working across
# multiple repositories.
```

- [ ] **Step 2: Replace the "DEFAULT MODEL CONFIGURATION" section**

Find this exact block (currently near the end of the file, right before the "EXECUTE OPENCODE" section):

```bash
# =============================================================================
# DEFAULT MODEL CONFIGURATION
# =============================================================================
# Read the default model from .opencode-model in the repo root (or pwd) if it
# exists, and append --model to the opencode arguments if not already specified.

opencode_model_file="$(${git_cmd} rev-parse --show-toplevel 2> /dev/null || pwd)/.opencode-model";
has_model_arg=0;
for arg in "$@"; do
  if [[ "$arg" == "--model" ]] || [[ "$arg" == "-m" ]]; then
    has_model_arg=1;
    break;
  fi
done

if [[ "$has_model_arg" -eq 0 ]] && [[ -e "$opencode_model_file" ]]; then
  opencode_model=$(${cat_cmd} "$opencode_model_file" 2> /dev/null | xargs);
  if [[ -n "$opencode_model" ]]; then
    set -- "$@" --model "$opencode_model";
  fi
fi
```

Replace it entirely with:

```bash
# =============================================================================
# DEFAULT MODEL/AGENT CONFIGURATION
# =============================================================================
# Read default --model and --agent values from .opencode-config (JSON) in the
# repo root (or pwd) if it exists, and append them to the opencode arguments
# for any flag not already specified on the command line. Invalid JSON is
# reported as a warning to stderr and otherwise ignored (the underlying
# opencode command still runs normally, falling through to CLI flags and
# opencode.json defaults).

opencode_config_file="$(${git_cmd} rev-parse --show-toplevel 2> /dev/null || pwd)/.opencode-config";

has_model_arg=0;
has_agent_arg=0;
for arg in "$@"; do
  if [[ "$arg" == "--model" ]] || [[ "$arg" == "-m" ]]; then
    has_model_arg=1;
  fi
  if [[ "$arg" == "--agent" ]]; then
    has_agent_arg=1;
  fi
done

if [[ -e "$opencode_config_file" ]]; then
  if ${jq_cmd} empty "$opencode_config_file" 2> /dev/null; then
    opencode_config_model=$(${jq_cmd} -r '.model // empty' "$opencode_config_file" 2> /dev/null);
    opencode_config_agent=$(${jq_cmd} -r '.agent // empty' "$opencode_config_file" 2> /dev/null);

    if [[ "$has_model_arg" -eq 0 ]] && [[ -n "$opencode_config_model" ]]; then
      set -- "$@" --model "$opencode_config_model";
    fi

    if [[ "$has_agent_arg" -eq 0 ]] && [[ -n "$opencode_config_agent" ]]; then
      set -- "$@" --agent "$opencode_config_agent";
    fi
  else
    echo "Warning: .opencode-config contains invalid JSON, ignoring" >&2;
  fi
fi
```

- [ ] **Step 3: Syntax-check the script**

Run: `bash -n home/.local/lib/opencode.sh`
Expected: no output, exit code 0.

- [ ] **Step 4: Manual scenario verification**

Run each of these from a scratch temp directory that is its own git repo (so `.opencode-config` resolves to that directory), stubbing `opencode` itself with a fake executable that just echoes its args, so no real API calls happen:

```bash
tmpdir=$(mktemp -d)
cd "$tmpdir"
git init -q
mkdir -p bin
cat > bin/opencode <<'EOF'
#!/usr/bin/env bash
echo "ARGS: $@"
EOF
chmod +x bin/opencode
export PATH="$tmpdir/bin:$PATH"
```

Scenario A — no `.opencode-config`, no CLI flags:
```bash
~/src/jzaleski/ai-tools/home/.local/lib/opencode.sh "hello"
```
Expected: `ARGS: hello` (no `--model`/`--agent` injected).

Scenario B — `.opencode-config` with only `model`:
```bash
echo '{"model": "jzaleski/high"}' > .opencode-config
~/src/jzaleski/ai-tools/home/.local/lib/opencode.sh "hello"
```
Expected: `ARGS: hello --model jzaleski/high` (no `--agent` injected).

Scenario C — `.opencode-config` with only `agent`:
```bash
echo '{"agent": "data"}' > .opencode-config
~/src/jzaleski/ai-tools/home/.local/lib/opencode.sh "hello"
```
Expected: `ARGS: hello --agent data` (no `--model` injected).

Scenario D — `.opencode-config` with both:
```bash
echo '{"model": "jzaleski/high", "agent": "data"}' > .opencode-config
~/src/jzaleski/ai-tools/home/.local/lib/opencode.sh "hello"
```
Expected: `ARGS: hello --model jzaleski/high --agent data`.

Scenario E — CLI flag wins over config:
```bash
~/src/jzaleski/ai-tools/home/.local/lib/opencode.sh --agent product "hello"
```
Expected: `ARGS: --agent product hello --model jzaleski/high` (agent from CLI kept, `--agent data` from config NOT appended, model from config still injected).

Scenario F — invalid JSON:
```bash
echo 'not json' > .opencode-config
~/src/jzaleski/ai-tools/home/.local/lib/opencode.sh "hello" 2>&1
```
Expected: stderr contains `Warning: .opencode-config contains invalid JSON, ignoring` followed by `ARGS: hello` (no flags injected, command still runs).

Clean up:
```bash
cd ~
rm -rf "$tmpdir"
```

- [ ] **Step 5: Commit**

```bash
git add home/.local/lib/opencode.sh
git commit -m "feat: merge .opencode-model/.opencode-agent into .opencode-config"
```

---

### Task 2: Update `README.md`

**Files:**
- Modify: `README.md:415-427` (the "Opencode Wrapper Script" section's Features list, followed by the Configuration Notes section)

- [ ] **Step 1: Replace the Features list and add a schema subsection**

Find this exact block:

```markdown
**Features:**
- Persists the last session ID to `.last-opencode-session` in the git repo root after each run
- Resumes sessions via `--continue` by reading the persisted session ID (works even after moving the repo)
- Automatically resets opencode model history on session start (configurable)
- Clears model cache to ensure fresh model selection
- Supports `--continue`, `-s`, or `--session` flags to preserve history/cache across invocations

**Required binaries** (all installed via bootstrap): `cat`, `git`, `jq`, `opencode`, `sqlite3`

**Environment Variables:**
- `RESET_OPENCODE_HISTORY` — Reset model history on each invocation (default: `true`)
- `RESET_OPENCODE_MODELS_CACHE` — Clear model cache on each invocation (default: `true`)
```

Replace it with:

```markdown
**Features:**
- Persists the last session ID to `.last-opencode-session` in the git repo root after each run
- Resumes sessions via `--continue` by reading the persisted session ID (works even after moving the repo)
- Automatically resets opencode model history on session start (configurable)
- Clears model cache to ensure fresh model selection
- Supports `--continue`, `-s`, or `--session` flags to preserve history/cache across invocations
- Reads default `--model`/`--agent` values from `.opencode-config` (JSON) in the git repo root, applied only when the corresponding flag isn't already passed on the command line

**Default Model/Agent Configuration**

Commit a `.opencode-config` JSON file to a repo root to set per-repo defaults:

```json
{
  "model": "jzaleski/high",
  "agent": "engineer"
}
```

- Both keys are optional — set either, both, or neither.
- Precedence (highest to lowest): explicit CLI flag (`--model`/`-m`, `--agent`) → `.opencode-config` → `opencode.json`'s `default_agent`/defaults.
- Invalid JSON prints a warning to stderr and is otherwise ignored — the underlying `opencode` command still runs.
- Unlike `.last-opencode-session`, this file is meant to be committed to the repo.

**Required binaries** (all installed via bootstrap): `cat`, `git`, `jq`, `opencode`, `sqlite3`

**Environment Variables:**
- `RESET_OPENCODE_HISTORY` — Reset model history on each invocation (default: `true`)
- `RESET_OPENCODE_MODELS_CACHE` — Clear model cache on each invocation (default: `true`)
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document .opencode-config in README"
```

---

### Task 3: Update `AGENTS.md`

**Files:**
- Modify: `AGENTS.md:205-212` (the "Opencode Wrapper" section)

- [ ] **Step 1: Add a bullet for `.opencode-config`**

Find this exact block:

```markdown
### Opencode Wrapper

`home/.local/lib/opencode.sh` wraps the `opencode` CLI to add session persistence and cache reset behavior. It is aliased via `home/.opencoderc`, which is sourced from `~/.bashrc` and `~/.zshrc` by the bootstrap system.

- Persists the last session ID to `.last-opencode-session` in the git repo root
- Resumes via `--continue` / `-s` / `--session` using the persisted ID
- Resets model history and clears model cache on fresh sessions (configurable via `RESET_OPENCODE_HISTORY`, `RESET_OPENCODE_MODELS_CACHE`)
- Required binaries (all installed via bootstrap): `cat`, `git`, `jq`, `opencode`, `sqlite3`
```

Replace it with:

```markdown
### Opencode Wrapper

`home/.local/lib/opencode.sh` wraps the `opencode` CLI to add session persistence and cache reset behavior. It is aliased via `home/.opencoderc`, which is sourced from `~/.bashrc` and `~/.zshrc` by the bootstrap system.

- Persists the last session ID to `.last-opencode-session` in the git repo root
- Resumes via `--continue` / `-s` / `--session` using the persisted ID
- Resets model history and clears model cache on fresh sessions (configurable via `RESET_OPENCODE_HISTORY`, `RESET_OPENCODE_MODELS_CACHE`)
- Reads default `--model`/`--agent` values from `.opencode-config` (JSON) in the git repo root, applied only when not already passed as a CLI flag; invalid JSON logs a warning to stderr and is otherwise ignored. Unlike `.last-opencode-session` (per-user, gitignored), `.opencode-config` is meant to be committed
- Required binaries (all installed via bootstrap): `cat`, `git`, `jq`, `opencode`, `sqlite3`
```

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: document .opencode-config in AGENTS.md"
```

---

### Task 4: Migrate the 7 external repos from `.opencode-model` to `.opencode-config`

**Files (outside `ai-tools`, no commits made in `ai-tools` for this task):**
- `~/src/ibbleinc/mobile-app/.opencode-model` → `.opencode-config` (tracked in git)
- `~/src/ibbleinc/web/.opencode-model` → `.opencode-config` (untracked in git)
- `~/src/ibbleinc/ultraviolet/.opencode-model` → `.opencode-config` (tracked in git)
- `~/src/ibbleinc/ibble-platform-config/.opencode-model` → `.opencode-config` (tracked in git)
- `~/src/alakai-operations/engie-fr-to-ap-file-workflow/.opencode-model` → `.opencode-config` (tracked in git)
- `~/src/alakai-marketing/alakai-website/.opencode-model` → `.opencode-config` (tracked in git)
- `~/src/alakai-software/alakai-data-studio/.opencode-model` → `.opencode-config` (tracked in git)

Current contents (verified):

| Repo | `.opencode-model` contents |
|---|---|
| `ibbleinc/mobile-app` | `google-vertex/gemini-3.1-pro-preview` |
| `ibbleinc/web` | `google-vertex/gemini-3.1-pro-preview` |
| `ibbleinc/ultraviolet` | `google-vertex/gemini-3.1-pro-preview` |
| `ibbleinc/ibble-platform-config` | `google-vertex/gemini-3.1-pro-preview` |
| `alakai-operations/engie-fr-to-ap-file-workflow` | `amazon-bedrock/anthropic.claude-opus-4-8` |
| `alakai-marketing/alakai-website` | `amazon-bedrock/anthropic.claude-sonnet-5` |
| `alakai-software/alakai-data-studio` | `amazon-bedrock/anthropic.claude-opus-4-8` |

No `agent` key is added for any of these — none previously specified an agent default, and inventing one would change behavior beyond a format migration.

- [ ] **Step 1: Migrate the 6 tracked repos (git rm old file, write new file, git add new file — leave staged, do not commit)**

```bash
for pair in \
  "$HOME/src/ibbleinc/mobile-app|google-vertex/gemini-3.1-pro-preview" \
  "$HOME/src/ibbleinc/ultraviolet|google-vertex/gemini-3.1-pro-preview" \
  "$HOME/src/ibbleinc/ibble-platform-config|google-vertex/gemini-3.1-pro-preview" \
  "$HOME/src/alakai-operations/engie-fr-to-ap-file-workflow|amazon-bedrock/anthropic.claude-opus-4-8" \
  "$HOME/src/alakai-marketing/alakai-website|amazon-bedrock/anthropic.claude-sonnet-5" \
  "$HOME/src/alakai-software/alakai-data-studio|amazon-bedrock/anthropic.claude-opus-4-8"; do
  repo="${pair%%|*}"
  model="${pair##*|}"
  (
    cd "$repo" || exit 1
    git rm --cached -q .opencode-model
    rm -f .opencode-model
    printf '{\n  "model": "%s"\n}\n' "$model" > .opencode-config
    git add .opencode-config
  )
done
```

- [ ] **Step 2: Migrate the 1 untracked repo (`ibbleinc/web`) — plain rm + create, no git staging needed since the old file was never committed**

```bash
repo="$HOME/src/ibbleinc/web"
(
  cd "$repo" || exit 1
  rm -f .opencode-model
  printf '{\n  "model": "%s"\n}\n' "google-vertex/gemini-3.1-pro-preview" > .opencode-config
)
```

- [ ] **Step 3: Verify each repo's resulting state**

```bash
for repo in \
  "$HOME/src/ibbleinc/mobile-app" \
  "$HOME/src/ibbleinc/web" \
  "$HOME/src/ibbleinc/ultraviolet" \
  "$HOME/src/ibbleinc/ibble-platform-config" \
  "$HOME/src/alakai-operations/engie-fr-to-ap-file-workflow" \
  "$HOME/src/alakai-marketing/alakai-website" \
  "$HOME/src/alakai-software/alakai-data-studio"; do
  echo "== $repo =="
  test -f "$repo/.opencode-model" && echo "FAIL: .opencode-model still exists" || echo "OK: .opencode-model removed"
  test -f "$repo/.opencode-config" && cat "$repo/.opencode-config" || echo "FAIL: .opencode-config missing"
  (cd "$repo" && git status --short -- .opencode-model .opencode-config)
  echo
done
```

Expected for each: `OK: .opencode-model removed`, valid JSON content printed for `.opencode-config`, and `git status --short` showing either `D  .opencode-model` + `A  .opencode-config` (staged, tracked repos) or `?? .opencode-config` (untracked, `web` repo — `.opencode-model` won't appear at all since it was never tracked and is now deleted).

**Note:** These changes are intentionally left staged/in the working tree in each of the 7 external repos — no commits are made there as part of this plan. Each repo's own commit/PR conventions apply; the user reviews and commits per repo on their own terms.

---

## Parallel Dispatch Analysis

### Batch 1 (independent — dispatch together):
- Task 1 (`home/.local/lib/opencode.sh`) + Task 2 (`README.md`) + Task 3 (`AGENTS.md`) + Task 4 (7 external repos, entirely outside `ai-tools`)
  Rationale: Task 1 touches only the wrapper script; Tasks 2 and 3 touch only documentation files with no code dependency on Task 1's exact implementation (the design doc already fixes the exact behavior/schema being documented); Task 4 touches files in seven unrelated repositories with no file overlap with Tasks 1-3 or each other. All four tasks can run fully in parallel.

### Single tasks:
- None — all 4 tasks are independent and batched above.

No sequential batches are required for this plan.
