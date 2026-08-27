# Merged `.opencode-config` File — Design

**Date:** 2026-07-20
**Status:** Approved-pending
**Author:** researcher (engineer agent, Path C)

## 1. Overview & Goals

`home/.local/lib/opencode.sh` (the `opencode` wrapper) currently reads a
plain-text `.opencode-model` file from the repo root to default the `--model`
flag when the caller doesn't pass one explicitly. We want to add an
equivalent default for `--agent`, but introducing a second single-purpose
dotfile (`.opencode-agent`) alongside `.opencode-model` and the existing
`.last-opencode-session` would leave three per-repo dotfiles, two of which
(`model`, `agent`) are conceptually the same thing: **static, committable,
per-repo defaults for the wrapper to inject as CLI flags when not otherwise
specified.**

This design **merges `model` and `agent` defaults into a single JSON file,
`.opencode-config`**, and keeps `.last-opencode-session` (per-user, runtime,
gitignored) entirely separate — it is not a static config and must never be
committed.

### Non-Goals

- No change to `.last-opencode-session` behavior.
- No new dependencies — `jq` is already a required binary for the wrapper
  (used today for model-history/cache reset) and already installed via
  `bin/install-dependencies`.
- No backward-compatible fallback to `.opencode-model` — this is a clean
  cutover (see §4).

## 2. File Format & Location

**Filename:** `.opencode-config`

**Location:** git repo root if inside a git repo, else `pwd` — identical
resolution logic to the existing `.opencode-model` / `.last-opencode-session`
files (`$(git rev-parse --show-toplevel 2> /dev/null || pwd)`).

**Format:** JSON, both keys optional:

```json
{
  "model": "jzaleski/high",
  "agent": "engineer"
}
```

- `model` — string, format `provider/model`, injected as `--model <value>`.
- `agent` — string, agent name, injected as `--agent <value>`.
- Either key may be omitted. An empty `{}` is valid (no-op).
- Unknown keys are ignored (forward-compatible, no validation error).

## 3. Precedence Rules

For both `model` and `agent`, precedence (highest to lowest):

1. **Explicit CLI flag** (`--model`/`-m`, `--agent`) — always wins; the
   wrapper never overrides a flag the caller already passed.
2. **`.opencode-config`** — used if the corresponding CLI flag was not
   passed and the key is present and non-empty in the file.
3. **`opencode.json` defaults** (e.g. `default_agent: engineer`) — opencode
   itself falls through to these if neither a CLI flag nor an injected
   wrapper flag is present.

This mirrors the existing `.opencode-model` precedence logic exactly (see
`has_model_arg` check in `opencode.sh` today), extended to `agent`.

## 4. Migration from `.opencode-model` (Clean Cutover)

- Remove all `.opencode-model`-reading logic from `opencode.sh`.
- No fallback path, no deprecation warning — this is a personal tooling repo
  with no external consumers depending on the old file.
- Existing `.opencode-model` files in other repos (see §7) are migrated to
  `.opencode-config` as part of this effort, and the old files deleted.

## 5. Error Handling

If `.opencode-config` exists but contains invalid JSON:

- Print a warning to **stderr**: `Warning: .opencode-config contains invalid JSON, ignoring`
- Continue as if the file did not exist (no `--model`/`--agent` injected from
  it; CLI flags and `opencode.json` defaults still apply normally).
- This must not abort the wrapper or block the underlying `opencode` command
  from running.

Validation approach: use `jq empty <file> 2>/dev/null` (or equivalent) to
check parseability before attempting to extract `.model` / `.agent` — `jq`
returns non-zero on invalid JSON, which the wrapper can check before reading
values as it will with `has_model_arg`/`has_agent_arg`.

If a key is present but not a string (e.g. `{"model": 123}`), `jq -r` will
stringify it. This is acceptable — no special-case validation beyond
"parses as JSON."

## 6. Wrapper Script Changes (`home/.local/lib/opencode.sh`)

Replace the existing "DEFAULT MODEL CONFIGURATION" section with a unified
"DEFAULT MODEL/AGENT CONFIGURATION" section:

1. Resolve `opencode_config_file` the same way `opencode_model_file` is
   resolved today (repo-root-or-pwd + `/.opencode-config`).
2. If the file exists:
   a. Validate JSON via `jq empty`. If invalid, print the stderr warning and
      skip to step 3 (treat as absent).
   b. If valid, extract `.model` and `.agent` via `jq -r '.model // empty'`
      and `jq -r '.agent // empty'` respectively (the `// empty` guards
      against `null`/missing keys producing the literal string `"null"`).
3. Scan `"$@"` for an existing `--model`/`-m` flag (as today) and separately
   for an existing `--agent` flag.
4. If no `--model`/`-m` was passed and the config produced a non-empty
   `model` value, append `--model <value>` to `$@`.
5. If no `--agent` was passed and the config produced a non-empty `agent`
   value, append `--agent <value>` to `$@`.

This section runs before the "EXECUTE OPENCODE" step, in the same place the
model-only logic runs today.

No changes are needed to:
- Binary validation section (`jq` is already required).
- Session persistence / `--continue` handling.
- Model history / cache reset logic.
- `.gitignore` (`.last-opencode-session` stays ignored; `.opencode-config`,
  like `.opencode-model` before it, is intentionally **not** ignored — it's
  meant to be committed per-repo).

## 7. Migration of Existing `.opencode-model` Files

The following repos under `~/src/` currently have a `.opencode-model` file
and need to be migrated to `.opencode-config` (same model value, under the
`model` key, old file deleted):

- `ibbleinc/mobile-app/.opencode-model`
- `ibbleinc/web/.opencode-model`
- `ibbleinc/ultraviolet/.opencode-model`
- `ibbleinc/ibble-platform-config/.opencode-model`
- `alakai-operations/engie-fr-to-ap-file-workflow/.opencode-model`
- `alakai-marketing/alakai-website/.opencode-model`
- `alakai-software/alakai-data-studio/.opencode-model`

For each: read the existing model string, write `.opencode-config` with
`{"model": "<value>"}` (no `agent` key — none was previously specified, and
we should not invent a default that wasn't there before), delete
`.opencode-model`. These are mechanical, independent, single-file-pair
changes in unrelated repos — not part of the `ai-tools` implementation plan
itself, and not part of this repo's git history. Each target repo's own
commit conventions apply (left as working-tree changes for the user to
review/commit per repo, consistent with this being tooling-adjacent rather
than a reviewed engineering change).

## 8. Documentation Updates (this repo)

- **`README.md`**: Update the "Opencode Wrapper Script" section (currently
  describes only session/history/cache behavior, and never documented
  `.opencode-model` despite it existing in code) to document
  `.opencode-config`, its JSON schema, precedence rules, and the
  invalid-JSON warning behavior.
- **`AGENTS.md`**: Update the "Opencode Wrapper" description under
  "Opencode Agent Architecture" to mention `.opencode-config` alongside
  `.last-opencode-session`.
- Neither file currently documents `.opencode-model`, so there is no
  deprecated-reference cleanup needed beyond the code itself.

## 9. Testing / Verification

Since this is a bash script with no existing test harness, verification is
manual, covering:

1. No `.opencode-config`, no CLI flags → behaves exactly as before (falls
   through to `opencode.json` defaults).
2. `.opencode-config` with only `model` set, no CLI flags → `--model`
   injected, `--agent` not injected.
3. `.opencode-config` with only `agent` set, no CLI flags → `--agent`
   injected, `--model` not injected.
4. `.opencode-config` with both set, no CLI flags → both injected.
5. `.opencode-config` with both set, `--agent data` passed on CLI → `--agent`
   from CLI wins, `--model` from config still injected.
6. `.opencode-config` with invalid JSON → stderr warning printed, command
   still runs, no flags injected from the file.
7. `bash -n home/.local/lib/opencode.sh` (syntax check) passes.

## 10. Out of Scope

- No changes to `run-model` / `run-router` / model tier behavior.
- No changes to the bootstrap system.
- No new environment variables.
