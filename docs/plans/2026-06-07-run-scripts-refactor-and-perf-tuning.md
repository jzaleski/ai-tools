# Run Scripts Refactor & Performance Tuning Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Replace the local/server script split with a single `run-model` (single model) and `run-router` (multi-model), use `HOST` env var as the only bind toggle, consolidate templates, and right-size per-tier context and batch/ubatch for Apple Silicon.

**Architecture:** Bash scripts under `bin/` invoke `llama-server` with per-tier flags. The local-vs-server distinction (previously baked into both bind address and perf params) is removed: bind address comes solely from `HOST` (default `127.0.0.1`), and performance params are tier-driven only. A new `long` tier provides a 256K-context profile. The router renders one consolidated INI template exposing all four tier aliases.

**Tech Stack:** Bash, llama.cpp (`llama-server`), INI preset templates.

---

## Reference: Final Tier Configuration

| Tier | Model file | HF repo | ctx | KV quant | batch | ubatch | ngl |
|---|---|---|---|---|---|---|---|
| `low` | `unsloth/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf` | `unsloth/Qwen3.6-35B-A3B-GGUF` | 32768 | q4_0 | 2048 | 512 | -1 |
| `medium` | `unsloth/Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf` | `unsloth/Qwen3.6-35B-A3B-GGUF` | 65536 | q4_0 | 2048 | 512 | -1 |
| `high` | `unsloth/Qwen3.6-27B-UD-Q8_K_XL.gguf` | `unsloth/Qwen3.6-27B-GGUF` | 131072 | q8_0 | 1024 | 256 | -1 |
| `long` | `unsloth/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf` | `unsloth/Qwen3.6-35B-A3B-GGUF` | 262144 | q4_0 | 1024 | 256 | -1 |

Shared across all tiers: `flash-attn on`, `presence-penalty 0.2`, `repeat-penalty 1.0`, `min-p 0.02`, `temp 0.7`, `top-k 0`, `top-p 0.95`. Default tier when `--tier` omitted: `medium`.

---

## Task 1: Create `bin/run-model`

**Files:**
- Create: `bin/run-model`
- Delete (in Task 2): `bin/run-local`, `bin/run-server`

- [ ] **Step 1: Write the new `bin/run-model` script**

Create `bin/run-model` with exactly this content:

```bash
#!/usr/bin/env bash

set -e;

MODELS_DIR="${MODELS_DIR:-"$HOME/.cache/models"}";

require_model() {
  local model_file="${1}";
  local hf_repo="${2}";
  # Optional third arg: HF path relative to repo root (e.g. subdir/file.gguf).
  # Falls back to basename of model_file for flat (non-split) models.
  local hf_filename="${3:-"$(basename "${model_file}")"}";
  if [[ ! -f "${model_file}" ]]; then
    echo "Model not found: ${model_file}";
    echo "Downloading ${hf_repo}/${hf_filename} ...";
    "$(dirname "$0")/download-model" "${hf_repo}" "${hf_filename}" || {
      echo "Error: download failed." >&2;
      exit 1;
    };
  fi
}

run_low() {
  local model="${MODELS_DIR}/unsloth/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
  require_model "${model}" "unsloth/Qwen3.6-35B-A3B-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/low \
    --host             "${HOST:-"127.0.0.1"}" \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       2048 \
    --ubatch-size      512 \
    --ctx-size         32768 \
    --cache-type-k     q4_0 \
    --cache-type-v     q4_0 \
    --presence-penalty 0.2 \
    --repeat-penalty   1.0 \
    --min-p            0.02 \
    --temp             0.7 \
    --top-k            0 \
    --top-p            0.95;
}

run_medium() {
  local model="${MODELS_DIR}/unsloth/Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf";
  require_model "${model}" "unsloth/Qwen3.6-35B-A3B-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/medium \
    --host             "${HOST:-"127.0.0.1"}" \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       2048 \
    --ubatch-size      512 \
    --ctx-size         65536 \
    --cache-type-k     q4_0 \
    --cache-type-v     q4_0 \
    --presence-penalty 0.2 \
    --repeat-penalty   1.0 \
    --min-p            0.02 \
    --temp             0.7 \
    --top-k            0 \
    --top-p            0.95;
}

run_high() {
  local model="${MODELS_DIR}/unsloth/Qwen3.6-27B-UD-Q8_K_XL.gguf";
  require_model "${model}" "unsloth/Qwen3.6-27B-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/high \
    --host             "${HOST:-"127.0.0.1"}" \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       1024 \
    --ubatch-size      256 \
    --ctx-size         131072 \
    --cache-type-k     q8_0 \
    --cache-type-v     q8_0 \
    --presence-penalty 0.2 \
    --repeat-penalty   1.0 \
    --min-p            0.02 \
    --temp             0.7 \
    --top-k            0 \
    --top-p            0.95;
}

run_long() {
  local model="${MODELS_DIR}/unsloth/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
  require_model "${model}" "unsloth/Qwen3.6-35B-A3B-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/long \
    --host             "${HOST:-"127.0.0.1"}" \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       1024 \
    --ubatch-size      256 \
    --ctx-size         262144 \
    --cache-type-k     q4_0 \
    --cache-type-v     q4_0 \
    --presence-penalty 0.2 \
    --repeat-penalty   1.0 \
    --min-p            0.02 \
    --temp             0.7 \
    --top-k            0 \
    --top-p            0.95;
}

tier="medium";
for arg in "$@"; do
  case "${arg}" in
    --tier) ;;
    *)
      case "${prev_arg}" in
        --tier) tier="${arg}";;
      esac
      ;;
  esac
  prev_arg="${arg}";
done

case "${tier}" in
  low)    run_low;;
  medium) run_medium;;
  high)   run_high;;
  long)   run_long;;
  *)
    echo "Error: unknown tier '${tier}'. Use: low, medium, high, long" >&2;
    exit 1;;
esac
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x bin/run-model`
Expected: no output, exit 0.

- [ ] **Step 3: Syntax check**

Run: `bash -n bin/run-model`
Expected: no output, exit 0 (no syntax errors).

- [ ] **Step 4: Verify tier dispatch for each tier via trace**

Run: `bash -x bin/run-model --tier low 2>&1 | grep -E 'ctx-size|alias|batch-size|host' | head`
Expected trace lines include `--alias jzaleski/low`, `--ctx-size 32768`, `--batch-size 2048`, `--host 127.0.0.1`.
Note: the script will then attempt to exec `llama-server` and may fail if the model/binary is absent — that is expected; we only verify the assembled flags before exec. If `llama-server` is missing the trace still prints the intended `exec llama-server ...` line.

- [ ] **Step 5: Verify `long` tier and unknown-tier rejection**

Run: `bash -x bin/run-model --tier long 2>&1 | grep -E 'ctx-size|alias' | head`
Expected: `--alias jzaleski/long`, `--ctx-size 262144`.

Run: `bash bin/run-model --tier bogus; echo "exit=$?"`
Expected: prints `Error: unknown tier 'bogus'. Use: low, medium, high, long` and `exit=1`.

- [ ] **Step 6: Verify HOST override**

Run: `HOST=0.0.0.0 bash -x bin/run-model --tier low 2>&1 | grep -- '--host' | head`
Expected: trace shows `--host 0.0.0.0`.

- [ ] **Step 7: Commit**

```bash
git add bin/run-model
git commit -m "Add run-model: single-model launcher with low/medium/high/long tiers"
```

---

## Task 2: Delete obsolete `bin/run-local` and `bin/run-server`

**Files:**
- Delete: `bin/run-local`
- Delete: `bin/run-server`

- [ ] **Step 1: Remove both scripts**

Run: `git rm bin/run-local bin/run-server`
Expected: `rm 'bin/run-local'` and `rm 'bin/run-server'`.

- [ ] **Step 2: Verify no remaining references in shell scripts under bin/**

Run: `grep -rn 'run-local\|run-server' bin/ || echo "no references"`
Expected: `no references` (the `bin/bootstrap` array does not reference these; confirm). If any reference appears, it must be removed — but per current repo state none exist outside docs.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "Remove run-local and run-server (replaced by run-model)"
```

---

## Task 3: Consolidate templates into `templates/llama-cpp.ini.template`

**Files:**
- Create: `templates/llama-cpp.ini.template`
- Delete: `templates/llama-cpp-local.ini.template`
- Delete: `templates/llama-cpp-server.ini.template`

- [ ] **Step 1: Create the consolidated template**

Create `templates/llama-cpp.ini.template` with exactly this content:

```ini
# Router preset config
# Keys use llama-server long-form flag names (no leading dashes).
# The [*] section supplies defaults inherited by every model section.
# Each named section becomes a routable model alias.
# Bind address is supplied by the launcher via --host (HOST env var); it is
# intentionally not set here.

[*]
flash-attn        = on
n-gpu-layers      = -1
presence-penalty  = 0.2
repeat-penalty    = 1.0
min-p             = 0.02
temp              = 0.7
top-k             = 0
top-p             = 0.95

[jzaleski/low]
model             = MODELS_DIR/unsloth/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf
ctx-size          = 32768
batch-size        = 2048
ubatch-size       = 512
cache-type-k      = q4_0
cache-type-v      = q4_0

[jzaleski/medium]
model             = MODELS_DIR/unsloth/Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf
ctx-size          = 65536
batch-size        = 2048
ubatch-size       = 512
cache-type-k      = q4_0
cache-type-v      = q4_0

[jzaleski/high]
model             = MODELS_DIR/unsloth/Qwen3.6-27B-UD-Q8_K_XL.gguf
ctx-size          = 131072
batch-size        = 1024
ubatch-size       = 256
cache-type-k      = q8_0
cache-type-v      = q8_0

[jzaleski/long]
model             = MODELS_DIR/unsloth/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf
ctx-size          = 262144
batch-size        = 1024
ubatch-size       = 256
cache-type-k      = q4_0
cache-type-v      = q4_0
```

- [ ] **Step 2: Remove the old templates**

Run: `git rm templates/llama-cpp-local.ini.template templates/llama-cpp-server.ini.template`
Expected: `rm 'templates/llama-cpp-local.ini.template'` and `rm 'templates/llama-cpp-server.ini.template'`.

- [ ] **Step 3: Commit**

```bash
git add templates/llama-cpp.ini.template
git commit -m "Consolidate INI templates into single llama-cpp.ini.template with low/medium/high/long"
```

---

## Task 4: Update `bin/run-router` (remove `--server`, single template, HOST toggle)

**Files:**
- Modify: `bin/run-router` (full rewrite — 49 lines)

This task depends on Task 3 (the consolidated template must exist). Rewrite the entire file.

- [ ] **Step 1: Replace `bin/run-router` with this content**

```bash
#!/usr/bin/env bash

set -e;

TEMPLATES_DIR="$(dirname "$0")/../templates";
TMP_DIR="$(dirname "$0")/../tmp";
MODELS_DIR="${MODELS_DIR:-"$HOME/.cache/models"}";

# Expand template tokens in a preset INI file and write the rendered result to
# the sibling tmp/ directory, deriving the output filename by stripping the
# .template suffix from the template basename.  Prints the output path to stdout.
render_preset() {
  local template="$1";
  local out="${TMP_DIR}/$(basename "${template%.template}")";
  mkdir -p "${TMP_DIR}";
  sed "s|MODELS_DIR|${MODELS_DIR}|g" "${template}" > "${out}";
  echo "${out}";
}

main() {
  local preset;
  preset="$(render_preset "${TEMPLATES_DIR}/llama-cpp.ini.template")";
  exec llama-server \
    --host "${HOST:-"127.0.0.1"}" \
    --port "${PORT:-"8080"}" \
    --models-preset "${preset}";
}

main;
```

- [ ] **Step 2: Syntax check**

Run: `bash -n bin/run-router`
Expected: no output, exit 0.

- [ ] **Step 3: Verify template renders and host binding (default)**

Run: `bash -x bin/run-router 2>&1 | grep -E 'host|models-preset|sed' | head`
Expected trace shows the `sed` render against `llama-cpp.ini.template`, `--host 127.0.0.1`, and `--models-preset .../tmp/llama-cpp.ini`. (exec of `llama-server` may fail if the binary is absent — expected; flags are assembled before exec.)

- [ ] **Step 4: Verify the rendered preset content**

Run: `cat tmp/llama-cpp.ini | grep -E '\[jzaleski|ctx-size'`
Expected: four sections `[jzaleski/low]`, `[jzaleski/medium]`, `[jzaleski/high]`, `[jzaleski/long]` with ctx-size `32768`, `65536`, `131072`, `262144` respectively, and `MODELS_DIR` expanded to the real path (no literal `MODELS_DIR` token remaining).

Run: `grep -c 'MODELS_DIR' tmp/llama-cpp.ini || echo 0`
Expected: `0` (token fully expanded).

- [ ] **Step 5: Verify HOST override**

Run: `HOST=0.0.0.0 bash -x bin/run-router 2>&1 | grep -- '--host' | head`
Expected: trace shows `--host 0.0.0.0`.

- [ ] **Step 6: Verify `--server` flag is gone**

Run: `grep -n 'server' bin/run-router || echo "no server references"`
Expected: `no server references` (the function was renamed to `main`; no `--server` parsing remains).

- [ ] **Step 7: Commit**

```bash
git add bin/run-router
git commit -m "Simplify run-router: drop --server flag, single template, HOST bind toggle"
```

---

## Task 5: Update `AGENTS.md`

**Files:**
- Modify: `AGENTS.md`

This is a documentation task and can run in parallel with code tasks (it does not touch any script). Apply these edits.

- [ ] **Step 1: Update the Project Overview tier description**

Find this line:
```
Supports three model tiers — low (Qwen3.6-35B-A3B Q4_K_XL), medium (Qwen3.6-35B-A3B Q6_K_XL), high (Qwen3.6-27B Q8_K_XL) — each available in local and server modes.
```
Replace with:
```
Supports four model tiers — low (Qwen3.6-35B-A3B Q4_K_XL, 32K ctx), medium (Qwen3.6-35B-A3B Q6_K_XL, 64K ctx), high (Qwen3.6-27B Q8_K_XL, 128K ctx), long (Qwen3.6-35B-A3B Q4_K_XL, 256K ctx). Bind address is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN).
```

- [ ] **Step 2: Update the Project Structure tree (bin/ entries)**

Find these three lines:
```
│   ├── run-local                          # Direct llama-server launcher (local mode, no router)
│   ├── run-router                         # Router server (llama.cpp, local and server modes)
│   └── run-server                         # Direct llama-server launcher (server mode, no router)
```
Replace with:
```
│   ├── run-model                          # Direct llama-server launcher (single model, --tier low|medium|high|long)
│   └── run-router                         # Router server (llama.cpp, multi-model; HOST env toggles bind)
```

- [ ] **Step 3: Update the Project Structure tree (templates/ entries)**

Find these three lines:
```
├── templates/                             # llama-server INI preset templates
│   ├── llama-cpp-local.ini.template       # Router preset: local profile (low: 32K, medium: 64K, high: 128K ctx)
│   └── llama-cpp-server.ini.template      # Router preset: server profile (low: 64K, medium: 128K, high: 256K ctx)
```
Replace with:
```
├── templates/                             # llama-server INI preset templates
│   └── llama-cpp.ini.template             # Router preset (low: 32K, medium: 64K, high: 128K, long: 256K ctx)
```

- [ ] **Step 4: Replace the Build/Test Commands section body**

Find the fenced bash block under "## Build/Test Commands" that begins with `./bin/run-router` and ends with the `./bin/run-server --tier high` line, plus the surrounding intro sentence. Replace the whole intro sentence + code block with:

Intro sentence — find:
```
Scripts in `bin/` support **local** and **server** modes, each with an optional `--tier` flag that selects the model tier (low/medium/high):
```
Replace with:
```
Scripts in `bin/` bind to `127.0.0.1` by default; set `HOST=0.0.0.0` to expose on the LAN. `run-model` takes an optional `--tier` flag (low/medium/high/long, default medium):
```

Code block — replace the entire existing block with:
```bash
./bin/run-router                           # multi-model router, localhost (8080)
HOST=0.0.0.0 ./bin/run-router              # multi-model router, exposed on LAN
# Clients select tier via: ?model=jzaleski/low  jzaleski/medium  jzaleski/high  jzaleski/long

./bin/run-model                            # single model, medium tier, localhost (127.0.0.1:8080)
./bin/run-model --tier low                 # single model, low tier
./bin/run-model --tier high                # single model, high tier
./bin/run-model --tier long                # single model, long-context tier
HOST=0.0.0.0 ./bin/run-model --tier high   # single model, high tier, exposed on LAN
```

- [ ] **Step 5: Update the test invocation line**

Find:
```
Test with: `bash -x ./bin/run-router` or `bash -x ./bin/run-local`
```
Replace with:
```
Test with: `bash -x ./bin/run-router` or `bash -x ./bin/run-model`
```

- [ ] **Step 6: Update the Naming Conventions block**

Find:
```
- Scripts: `run-{component}.sh`
- Modes: `local` / `server`
- Ports: 8080 (all scripts)
- Aliases: `jzaleski/{component}`
```
Replace with:
```
- Scripts: `run-{component}`
- Bind toggle: `HOST` env var (`127.0.0.1` default / `0.0.0.0` for LAN)
- Ports: 8080 (all scripts)
- Aliases: `jzaleski/{tier}`
```

- [ ] **Step 7: Update the Performance section bullets**

Find:
```
- KV cache quantization is tier-specific: local: all tiers=q4_0; server: low=q4_0, medium=q4_0, high=q8_0
- Context size is tier-specific — local: low=64K, medium=64K, high=64K; server: low=256K, medium=256K, high=256K
```
Replace with:
```
- KV cache quantization is tier-specific: low=q4_0, medium=q4_0, high=q8_0, long=q4_0
- Context size is tier-specific: low=32K, medium=64K, high=128K, long=256K
- Batch/ubatch is tier-specific and scales inversely with context for steady latency on Apple Silicon: low & medium=2048/512, high & long=1024/256
```

- [ ] **Step 8: Update the llama.cpp provider description under "Opencode Agent Architecture"**

Find:
```
- **llama.cpp (local)**: `localhost:8080` — per-tier context (low: 64K, medium: 64K, high: 64K); models: `jzaleski/low` (Qwen3.6-35B-A3B Q4_K_XL), `jzaleski/medium` (Qwen3.6-35B-A3B Q6_K_XL), `jzaleski/high` (Qwen3.6-27B Q8_K_XL)
- **llama.cpp (server)**: `server-hostname-or-ip:8080` — per-tier context (low: 256K, medium: 256K, high: 256K); same three aliases
```
Replace with:
```
- **llama.cpp (local)**: `localhost:8080` — per-tier context (low: 32K, medium: 64K, high: 128K, long: 256K); models: `jzaleski/low` (Qwen3.6-35B-A3B Q4_K_XL), `jzaleski/medium` (Qwen3.6-35B-A3B Q6_K_XL), `jzaleski/high` (Qwen3.6-27B Q8_K_XL), `jzaleski/long` (Qwen3.6-35B-A3B Q4_K_XL)
- **llama.cpp (server)**: `server-hostname-or-ip:8080` — same four aliases and contexts; reach this endpoint by launching with `HOST=0.0.0.0`
```

- [ ] **Step 9: Verify no stale references remain**

Run: `grep -n 'run-local\|run-server\|--server\|llama-cpp-local\|llama-cpp-server' AGENTS.md || echo "clean"`
Expected: `clean`.

- [ ] **Step 10: Commit**

```bash
git add AGENTS.md
git commit -m "Update AGENTS.md for run-model/run-router refactor and new tier config"
```

---

## Task 6: Update `README.md`

**Files:**
- Modify: `README.md`

Documentation task; touches no scripts. Can run in parallel with code tasks but must NOT run in the same batch as Task 5 only because both are docs — they edit different files, so they ARE parallel-safe with each other. Apply these edits.

- [ ] **Step 1: Update the Overview paragraph**

Find:
```
This repository provides scripts and configurations for running local AI models using llama-server. It supports three model tiers — low (Qwen3.6-35B-A3B Q4_K_XL), medium (Qwen3.6-35B-A3B Q6_K_XL), and high (Qwen3.6-27B Q8_K_XL) — each available in local and server modes. Tiers are purpose-oriented and stable; the models behind them can rotate without changing client-facing aliases.
```
Replace with:
```
This repository provides scripts and configurations for running local AI models using llama-server. It supports four model tiers — low (Qwen3.6-35B-A3B Q4_K_XL, 32K ctx), medium (Qwen3.6-35B-A3B Q6_K_XL, 64K ctx), high (Qwen3.6-27B Q8_K_XL, 128K ctx), and long (Qwen3.6-35B-A3B Q4_K_XL, 256K ctx for long agent sessions). The tier axis runs from speed (low) to quality (high) within the Qwen3.6 family; `long` is a large-context sibling of `low`. Bind address is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN). Tiers are stable; the models behind them can rotate without changing client-facing aliases.
```

- [ ] **Step 2: Update the Project Structure tree (bin/ and templates/ entries)**

Find:
```
│   ├── run-local                   # Direct llama-server launcher (local mode, no router)
│   ├── run-router                  # Router server (llama.cpp, local and server modes)
│   └── run-server                  # Direct llama-server launcher (server mode, no router)
├── templates/                      # llama-server INI preset templates
│   ├── llama-cpp-local.ini.template   # Router preset: local profile (low: 32K, medium: 64K, high: 128K ctx)
│   └── llama-cpp-server.ini.template  # Router preset: server profile (low: 256K, medium: 256K, high: 192K ctx)
```
Replace with:
```
│   ├── run-model                   # Direct llama-server launcher (single model, --tier low|medium|high|long)
│   └── run-router                  # Router server (llama.cpp, multi-model; HOST env toggles bind)
├── templates/                      # llama-server INI preset templates
│   └── llama-cpp.ini.template      # Router preset (low: 32K, medium: 64K, high: 128K, long: 256K ctx)
```

- [ ] **Step 3: Update the Environment Variables intro**

Find:
```
You can override default settings via environment variables. The same variables apply to both local and server modes.

**Common Variables:**
- `HOST`: Network interface address to bind the server to (default: 127.0.0.1 for local, 0.0.0.0 for server)
- `PORT`: Network port for the server to listen on (default: 8080)
```
Replace with:
```
You can override default settings via environment variables.

**Common Variables:**
- `HOST`: Network interface address to bind the server to (default: `127.0.0.1`; set `0.0.0.0` to expose on the LAN)
- `PORT`: Network port for the server to listen on (default: 8080)
```

- [ ] **Step 4: Replace the `### run-local`, `### run-server`, and `### run-router` Components subsections**

Find the entire block from the `### run-local` heading through the end of the `### run-router` subsection (the line ending `MODELS_DIR\`: Override model cache directory (default: \`~/.cache/models\`)` that closes run-router's env-var list, just before `## Usage`). Replace that whole block with:

```
### run-model
Starts a single llama-server directly (no router). Accepts `--tier low|medium|high|long` (default: `medium`). Downloads the model automatically if not present. Binds to `127.0.0.1` unless `HOST=0.0.0.0` is set.

**Shared defaults (all tiers):**
- Host: `127.0.0.1` (override with `HOST`)
- Port: 8080
- Sampling: `temp=0.7`, `top-k=0` (disabled), `top-p=0.95`, `min-p=0.02`, `presence-penalty=0.2`, `repeat-penalty=1.0`
- GPU: `n-gpu-layers=-1` (all), flash-attn on

| Tier | Model | Quant | KV Cache | Context | Batch/Ubatch |
|---|---|---|---|---|---|
| low | `unsloth/Qwen3.6-35B-A3B-GGUF` | `UD-Q4_K_XL` | q4_0 | 32,768 | 2048 / 512 |
| medium | `unsloth/Qwen3.6-35B-A3B-GGUF` | `UD-Q6_K_XL` | q4_0 | 65,536 | 2048 / 512 |
| high | `unsloth/Qwen3.6-27B-GGUF` | `UD-Q8_K_XL` | q8_0 | 131,072 | 1024 / 256 |
| long | `unsloth/Qwen3.6-35B-A3B-GGUF` | `UD-Q4_K_XL` | q4_0 | 262,144 | 1024 / 256 |

**Environment Variables:**
- `HOST`: Bind address (default: `127.0.0.1`; set `0.0.0.0` for LAN)
- `PORT`: Override listen port (default: 8080)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)

### run-router
Starts a single llama-server in [router mode](https://github.com/ggml-org/llama.cpp/blob/master/docs/preset.md), loading all four tiers from the rendered INI preset (`templates/llama-cpp.ini.template` → `tmp/llama-cpp.ini`). Clients select a tier via the `model` parameter. Binds to `127.0.0.1` unless `HOST=0.0.0.0` is set.

**Defaults:**
- Host: `127.0.0.1` (override with `HOST`)
- Port: 8080
- Sampling: `temp=0.7`, `top-k=0` (disabled), `top-p=0.95`, `min-p=0.02`, `presence-penalty=0.2`, `repeat-penalty=1.0`
- Per-tier context/KV/batch as in the run-model table above (low: 32K/q4_0/2048-512, medium: 64K/q4_0/2048-512, high: 128K/q8_0/1024-256, long: 256K/q4_0/1024-256)

**Environment Variables:**
- `HOST`: Bind address (default: `127.0.0.1`; set `0.0.0.0` for LAN)
- `PORT`: Override listen port (default: 8080)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)
```

- [ ] **Step 5: Replace the Usage code block**

Find the fenced bash block under `## Usage` (from `# Start local server directly` through `./bin/run-router --server`). Replace it with:

```bash
# Start single model directly — medium tier (default), localhost
./bin/run-model

# Start single model — specific tier
./bin/run-model --tier low
./bin/run-model --tier high
./bin/run-model --tier long

# Expose a single model on the LAN
HOST=0.0.0.0 ./bin/run-model --tier high

# Start router (all four tiers on localhost:8080)
./bin/run-router

# Start router exposed on the LAN (all four tiers on 0.0.0.0:8080)
HOST=0.0.0.0 ./bin/run-router
```

- [ ] **Step 6: Update the client model-select examples**

Find:
```
curl http://localhost:8080/v1/chat/completions?model=jzaleski/low    ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/medium ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/high   ...
```
Replace with:
```
curl http://localhost:8080/v1/chat/completions?model=jzaleski/low    ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/medium ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/high   ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/long   ...
```

- [ ] **Step 7: Replace the Architecture section diagram and intro**

Find the intro sentence:
```
The router listens on port 8080 and is selected at launch time via flags. Alternatively, `run-local` and `run-server` bypass the router and start llama-server directly.
```
Replace with:
```
The router listens on port 8080 and serves all four tiers. Alternatively, `run-model` bypasses the router and starts a single llama-server directly. Both bind to `127.0.0.1` unless `HOST=0.0.0.0` is set.
```

Then find the entire ASCII diagram fenced block immediately following (the box drawing showing `run-router`, `run-local`, `run-server`) and replace it with:
```
┌──────────────────────────┐   ┌──────────────────────────┐
│   ./bin/run-router        │   │   ./bin/run-model         │
│   (multi-model router)    │   │   (single model)          │
└────────────┬──────────────┘   └────────────┬─────────────┘
             │                               │
   ┌──────────┴──────────┐          ┌─────────┴──────────┐
   │  llama.cpp (router) │          │  llama.cpp         │
   │  HOST:8080          │          │  HOST:8080         │
   │  --models-preset    │          │  (direct, --tier)  │
   │                     │          └────────────────────┘
   │ ┌──────────────────┐ │
   │ │jzaleski/low      │ │  HOST defaults to 127.0.0.1;
   │ │jzaleski/medium   │ │  set HOST=0.0.0.0 to expose
   │ │jzaleski/high     │ │  on the LAN.
   │ │jzaleski/long     │ │
   │ └──────────────────┘ │
   └─────────────────────┘
```

- [ ] **Step 8: Update the Performance Tips bullets**

Find:
```
- KV cache quantization is tier-specific: local: all tiers=q4_0; server: low=q4_0, medium=q4_0, high=q8_0
- Context size is tier-specific — local: low=64K, medium=64K, high=64K; server: low=256K, medium=256K, high=256K
```
Replace with:
```
- KV cache quantization is tier-specific: low=q4_0, medium=q4_0, high=q8_0, long=q4_0
- Context size is tier-specific: low=32K, medium=64K, high=128K, long=256K
- Batch/ubatch scales inversely with context for steady latency on Apple Silicon: low & medium=2048/512, high & long=1024/256
```

- [ ] **Step 9: Verify no stale references remain**

Run: `grep -n 'run-local\|run-server\|--server\|llama-cpp-local\|llama-cpp-server' README.md || echo "clean"`
Expected: `clean`.

Note: the "local"/"server" wording in the Opencode provider table (llama.cpp local vs. server endpoints) is a separate concept (provider endpoints, not run-script modes) and should remain unchanged.

- [ ] **Step 10: Commit**

```bash
git add README.md
git commit -m "Update README for run-model/run-router refactor and four-tier config"
```

---

## Parallel Dispatch Analysis

### Batch 1 (independent — dispatch together):
- **Task 1** (`bin/run-model`) — new file, no dependencies.
- **Task 3** (`templates/llama-cpp.ini.template` + delete old templates) — touches only `templates/`.
- **Task 5** (`AGENTS.md`) — docs only, different file.
- **Task 6** (`README.md`) — docs only, different file.

Rationale: These four touch disjoint file sets (`bin/run-model`, `templates/*`, `AGENTS.md`, `README.md`) with no cross-dependencies. The docs tasks describe the final state, which is fixed by the design regardless of code-task execution order.

### Batch 2 (depends on Batch 1):
- **Task 2** (delete `bin/run-local`, `bin/run-server`) — independent of others in practice, but sequence it after Task 1 so `run-model` exists before its predecessors are removed (avoids a transient state with no single-model launcher). Low risk; could also run in Batch 1, but ordering after Task 1 is cleaner.
- **Task 4** (rewrite `bin/run-router`) — depends on **Task 3** because Step 3/4 verification renders `templates/llama-cpp.ini.template`, which Task 3 creates.

Rationale: Task 4's verification requires the consolidated template to exist. Task 2 is ordered after Task 1 for a clean transition.

### Suggested execution:
```
Batch 1 (parallel): Task 1 + Task 3 + Task 5 + Task 6
Batch 2 (parallel): Task 2 + Task 4
```

---

## Self-Review

**Spec coverage:**
- Delete run-local/run-server → Task 2 ✓
- Create run-model with low/medium/high/long → Task 1 ✓
- HOST bind toggle (default 127.0.0.1) on both scripts → Task 1 (run-model) + Task 4 (run-router) ✓
- Remove `--server` from run-router → Task 4 (Step 6 verifies) ✓
- Consolidate two templates → one → Task 3 ✓
- Router exposes all four aliases → Task 3 (template) verified in Task 4 Step 4 ✓
- Per-tier ctx 32/64/128/256K → Tasks 1, 3 ✓
- Inverse batch/ubatch 2048-512 / 1024-256 → Tasks 1, 3 ✓
- KV quant q4_0 except high=q8_0; long=q4_0 → Tasks 1, 3 ✓
- medium standardized on Q6_K_XL → Task 1 (run_medium), Task 3 (template) ✓
- ngl=-1 kept explicit → Tasks 1, 3 ✓
- flash-attn on, sampling unchanged → Tasks 1, 3 ✓
- AGENTS.md + README updates → Tasks 5, 6 ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases". All script and template content is complete and literal. All edits show exact find/replace text. ✓

**Type/name consistency:** Alias names (`jzaleski/{low,medium,high,long}`), model filenames, HF repos, ctx/batch/ubatch/KV values are identical between `run-model` (Task 1) and the template (Task 3). The `medium` quant is Q6_K_XL in both. The router function rename (`run_local`/`run_server` → `main`) is consistent with the `--server` removal verified in Task 4 Step 6. ✓
