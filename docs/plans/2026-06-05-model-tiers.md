# Model Tiers Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Replace the `jzaleski/local` / `jzaleski/server` / `--experimental` model scheme with three stable, purpose-oriented tiers (`jzaleski/low`, `jzaleski/medium`, `jzaleski/high`) across all scripts, templates, and opencode configuration.

**Architecture:** Two INI templates (local and server) each define all three tier sections; `run-router` renders them via `sed` into `tmp/`. `run-local` and `run-server` are restructured to accept `--tier low|medium|high` (default: `medium`) and dispatch to per-tier functions. `opencode.json` is updated so both providers expose all three model aliases with correct token limits.

**Tech Stack:** Bash, llama-server INI preset format, opencode JSON config.

---

## Task 1: Update `templates/llama-cpp-local.ini.template`

**Files:**
- Modify: `templates/llama-cpp-local.ini.template`
- Delete: `templates/llama-cpp-local-experimental.ini.template`

- [ ] **Step 1: Overwrite `templates/llama-cpp-local.ini.template` with the new three-tier content**

The file should contain exactly:

```ini
# Router preset config — local mode
# Keys use llama-server long-form flag names (no leading dashes).
# The [*] section supplies defaults inherited by every model section.
# Each named section becomes a routable model alias.

[*]
flash-attn        = on
n-gpu-layers      = -1
batch-size        = 2048
ubatch-size       = 512
ctx-size          = 131072
cache-type-k      = q4_0
cache-type-v      = q4_0
presence-penalty  = 1.5
repeat-penalty    = 1.0
min-p             = 0.01
temp              = 1.0
top-k             = 20
top-p             = 0.95

[jzaleski/low]
model             = MODELS_DIR/unsloth/gemma-4-12b-it-UD-Q4_K_XL.gguf

[jzaleski/medium]
model             = MODELS_DIR/unsloth/Qwen3.6-27B-UD-Q4_K_XL.gguf

[jzaleski/high]
model             = MODELS_DIR/unsloth/MiniMax-M2.7-UD-Q4_K_XL.gguf
```

- [ ] **Step 2: Delete the experimental local template**

```bash
rm /Users/jzaleski/src/jzaleski/ai-tools/templates/llama-cpp-local-experimental.ini.template
```

- [ ] **Step 3: Verify**

```bash
cat /Users/jzaleski/src/jzaleski/ai-tools/templates/llama-cpp-local.ini.template
ls /Users/jzaleski/src/jzaleski/ai-tools/templates/
```

Expected: file shows three tier sections; `llama-cpp-local-experimental.ini.template` is absent from the listing.

---

## Task 2: Update `templates/llama-cpp-server.ini.template`

**Files:**
- Modify: `templates/llama-cpp-server.ini.template`
- Delete: `templates/llama-cpp-server-experimental.ini.template`

- [ ] **Step 1: Overwrite `templates/llama-cpp-server.ini.template` with the new three-tier content**

The file should contain exactly:

```ini
# Router preset config — server mode
# Keys use llama-server long-form flag names (no leading dashes).
# The [*] section supplies defaults inherited by every model section.
# Each named section becomes a routable model alias.

[*]
flash-attn        = on
n-gpu-layers      = -1
batch-size        = 4096
ubatch-size       = 1024
ctx-size          = 262144
cache-type-k      = q8_0
cache-type-v      = q8_0
presence-penalty  = 1.5
repeat-penalty    = 1.0
min-p             = 0.01
temp              = 1.0
top-k             = 20
top-p             = 0.95

[jzaleski/low]
model             = MODELS_DIR/unsloth/gemma-4-12b-it-UD-Q8_K_XL.gguf

[jzaleski/medium]
model             = MODELS_DIR/unsloth/Qwen3.6-27B-UD-Q8_K_XL.gguf

[jzaleski/high]
model             = MODELS_DIR/unsloth/MiniMax-M2.7-UD-Q8_K_XL.gguf
```

- [ ] **Step 2: Delete the experimental server template**

```bash
rm /Users/jzaleski/src/jzaleski/ai-tools/templates/llama-cpp-server-experimental.ini.template
```

- [ ] **Step 3: Verify**

```bash
cat /Users/jzaleski/src/jzaleski/ai-tools/templates/llama-cpp-server.ini.template
ls /Users/jzaleski/src/jzaleski/ai-tools/templates/
```

Expected: file shows three tier sections; `llama-cpp-server-experimental.ini.template` is absent.

---

## Task 3: Update `bin/run-router`

**Files:**
- Modify: `bin/run-router`

- [ ] **Step 1: Overwrite `bin/run-router` with the simplified two-function version**

Remove `run_local_experimental`, `run_server_experimental`, and the `--experimental` flag. The file should contain exactly:

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

run_local() {
  local preset;
  preset="$(render_preset "${TEMPLATES_DIR}/llama-cpp-local.ini.template")";
  exec llama-server \
    --host "${HOST:-"127.0.0.1"}" \
    --port "${PORT:-"8080"}" \
    --models-preset "${preset}";
}

run_server() {
  local preset;
  preset="$(render_preset "${TEMPLATES_DIR}/llama-cpp-server.ini.template")";
  exec llama-server \
    --host "${HOST:-"0.0.0.0"}" \
    --port "${PORT:-"8080"}" \
    --models-preset "${preset}";
}

server=false;
for arg in "$@"; do
  case "${arg}" in
    --server) server=true;;
  esac
done

if [[ "${server}" == "true" ]]; then
  run_server;
else
  run_local;
fi
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n /Users/jzaleski/src/jzaleski/ai-tools/bin/run-router && echo "syntax OK"
```

Expected: `syntax OK`

---

## Task 4: Update `bin/run-local`

**Files:**
- Modify: `bin/run-local`

- [ ] **Step 1: Overwrite `bin/run-local` with the three-tier version**

Replace `run_local` / `run_local_experimental` / `--experimental` with `run_low` / `run_medium` / `run_high` dispatched via `--tier` (default: `medium`). The file should contain exactly:

```bash
#!/usr/bin/env bash

set -e;

MODELS_DIR="${MODELS_DIR:-"$HOME/.cache/models"}";

require_model() {
  local model_file="${1}";
  local hf_repo="${2}";
  if [[ ! -f "${model_file}" ]]; then
    local hf_filename;
    hf_filename="$(basename "${model_file}")";
    echo "Model not found: ${model_file}";
    echo "Downloading ${hf_repo}/${hf_filename} ...";
    "$(dirname "$0")/download-model" "${hf_repo}" "${hf_filename}" || {
      echo "Error: download failed." >&2;
      exit 1;
    };
  fi
}

run_low() {
  local model="${MODELS_DIR}/unsloth/gemma-4-12b-it-UD-Q4_K_XL.gguf";
  require_model "${model}" "unsloth/gemma-4-12b-it-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/low \
    --host             127.0.0.1 \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       2048 \
    --ubatch-size      512 \
    --ctx-size         131072 \
    --cache-type-k     q4_0 \
    --cache-type-v     q4_0 \
    --presence-penalty 1.5 \
    --repeat-penalty   1.0 \
    --min-p            0.01 \
    --temp             1.0 \
    --top-k            20 \
    --top-p            0.95;
}

run_medium() {
  local model="${MODELS_DIR}/unsloth/Qwen3.6-27B-UD-Q4_K_XL.gguf";
  require_model "${model}" "unsloth/Qwen3.6-27B-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/medium \
    --host             127.0.0.1 \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       2048 \
    --ubatch-size      512 \
    --ctx-size         131072 \
    --cache-type-k     q4_0 \
    --cache-type-v     q4_0 \
    --presence-penalty 1.5 \
    --repeat-penalty   1.0 \
    --min-p            0.01 \
    --temp             1.0 \
    --top-k            20 \
    --top-p            0.95;
}

run_high() {
  local model="${MODELS_DIR}/unsloth/MiniMax-M2.7-UD-Q4_K_XL.gguf";
  require_model "${model}" "unsloth/MiniMax-M2.7-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/high \
    --host             127.0.0.1 \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       2048 \
    --ubatch-size      512 \
    --ctx-size         131072 \
    --cache-type-k     q4_0 \
    --cache-type-v     q4_0 \
    --presence-penalty 1.5 \
    --repeat-penalty   1.0 \
    --min-p            0.01 \
    --temp             1.0 \
    --top-k            20 \
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
  *)
    echo "Error: unknown tier '${tier}'. Use: low, medium, high" >&2;
    exit 1;;
esac
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n /Users/jzaleski/src/jzaleski/ai-tools/bin/run-local && echo "syntax OK"
```

Expected: `syntax OK`

---

## Task 5: Update `bin/run-server`

**Files:**
- Modify: `bin/run-server`

- [ ] **Step 1: Overwrite `bin/run-server` with the three-tier version**

Same structure as `run-local` but with server host (`0.0.0.0`), context size 262144, batch-size 4096, ubatch-size 1024, cache-type q8_0, and `UD-Q8_K_XL` quants. The file should contain exactly:

```bash
#!/usr/bin/env bash

set -e;

MODELS_DIR="${MODELS_DIR:-"$HOME/.cache/models"}";

require_model() {
  local model_file="${1}";
  local hf_repo="${2}";
  if [[ ! -f "${model_file}" ]]; then
    local hf_filename;
    hf_filename="$(basename "${model_file}")";
    echo "Model not found: ${model_file}";
    echo "Downloading ${hf_repo}/${hf_filename} ...";
    "$(dirname "$0")/download-model" "${hf_repo}" "${hf_filename}" || {
      echo "Error: download failed." >&2;
      exit 1;
    };
  fi
}

run_low() {
  local model="${MODELS_DIR}/unsloth/gemma-4-12b-it-UD-Q8_K_XL.gguf";
  require_model "${model}" "unsloth/gemma-4-12b-it-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/low \
    --host             0.0.0.0 \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       4096 \
    --ubatch-size      1024 \
    --ctx-size         262144 \
    --cache-type-k     q8_0 \
    --cache-type-v     q8_0 \
    --presence-penalty 1.5 \
    --repeat-penalty   1.0 \
    --min-p            0.01 \
    --temp             1.0 \
    --top-k            20 \
    --top-p            0.95;
}

run_medium() {
  local model="${MODELS_DIR}/unsloth/Qwen3.6-27B-UD-Q8_K_XL.gguf";
  require_model "${model}" "unsloth/Qwen3.6-27B-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/medium \
    --host             0.0.0.0 \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       4096 \
    --ubatch-size      1024 \
    --ctx-size         262144 \
    --cache-type-k     q8_0 \
    --cache-type-v     q8_0 \
    --presence-penalty 1.5 \
    --repeat-penalty   1.0 \
    --min-p            0.01 \
    --temp             1.0 \
    --top-k            20 \
    --top-p            0.95;
}

run_high() {
  local model="${MODELS_DIR}/unsloth/MiniMax-M2.7-UD-Q8_K_XL.gguf";
  require_model "${model}" "unsloth/MiniMax-M2.7-GGUF";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/high \
    --host             0.0.0.0 \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       4096 \
    --ubatch-size      1024 \
    --ctx-size         262144 \
    --cache-type-k     q8_0 \
    --cache-type-v     q8_0 \
    --presence-penalty 1.5 \
    --repeat-penalty   1.0 \
    --min-p            0.01 \
    --temp             1.0 \
    --top-k            20 \
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
  *)
    echo "Error: unknown tier '${tier}'. Use: low, medium, high" >&2;
    exit 1;;
esac
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n /Users/jzaleski/src/jzaleski/ai-tools/bin/run-server && echo "syntax OK"
```

Expected: `syntax OK`

---

## Task 6: Update `home/.config/opencode/opencode.json`

**Files:**
- Modify: `home/.config/opencode/opencode.json`

- [ ] **Step 1: Overwrite `home/.config/opencode/opencode.json` with the three-tier model config**

Token limits:
- Local — context: 131072, input: 122880 (context minus 8192), output: 8192
- Server — context: 262144, input: 245760 (context minus 16384), output: 16384

The file should contain exactly:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "agent": {
    "build": {
      "disable": true
    },
    "plan": {
      "disable": true
    }
  },
  "default_agent": "engineer",
  "disabled_providers": [
    "opencode",
    "openai"
  ],
  "provider": {
    "llama.cpp (local)": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama.cpp (local)",
      "options": {
        "baseURL": "http://localhost:8080/v1"
      },
      "models": {
        "jzaleski/low": {
          "name": "jzaleski/low",
          "limit": {
            "context": 131072,
            "input": 122880,
            "output": 8192
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          }
        },
        "jzaleski/medium": {
          "name": "jzaleski/medium",
          "limit": {
            "context": 131072,
            "input": 122880,
            "output": 8192
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          }
        },
        "jzaleski/high": {
          "name": "jzaleski/high",
          "limit": {
            "context": 131072,
            "input": 122880,
            "output": 8192
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          }
        }
      }
    },
    "llama.cpp (server)": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama.cpp (server)",
      "options": {
        "baseURL": "http://server-hostname-or-ip:8080/v1"
      },
      "models": {
        "jzaleski/low": {
          "name": "jzaleski/low",
          "limit": {
            "context": 262144,
            "input": 245760,
            "output": 16384
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          }
        },
        "jzaleski/medium": {
          "name": "jzaleski/medium",
          "limit": {
            "context": 262144,
            "input": 245760,
            "output": 16384
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          }
        },
        "jzaleski/high": {
          "name": "jzaleski/high",
          "limit": {
            "context": 262144,
            "input": 245760,
            "output": 16384
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          }
        }
      }
    }
  },
  "plugin": [],
  "mcp": {
    "jira": {
      "type": "remote",
      "url": "https://mcp.atlassian.com/v1/mcp",
      "enabled": false,
      "oauth": {}
    },
    "playwright": {
      "type": "local",
      "command": ["npx", "@playwright/mcp@latest"],
      "enabled": false
    },
    "vercel": {
      "type": "remote",
      "url": "https://mcp.vercel.com/v1/mcp",
      "enabled": false,
      "oauth": {}
    }
  }
}
```

- [ ] **Step 2: Verify valid JSON**

```bash
jq . /Users/jzaleski/src/jzaleski/ai-tools/home/.config/opencode/opencode.json > /dev/null && echo "valid JSON"
```

Expected: `valid JSON`

---

## Task 7: Update `AGENTS.md`

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Update the Project Overview section**

Find:
```
Supports coding assistance (Qwen3.6-35B-A3B local and server) and general advising (Qwen3.6-35B-A3B local and server).
```
Replace with:
```
Supports three model tiers — low (Gemma4-12B), medium (Qwen3.6-27B), high (MiniMax-M2.7) — each available in local and server modes.
```

- [ ] **Step 2: Update the conf/ directory reference in the Project Structure section**

Find:
```
├── conf/                                  # llama-server INI presets
│   ├── llama-cpp-local.ini                # Router preset: local profile
│   ├── llama-cpp-local-experimental.ini   # Router preset: local experimental profile
│   ├── llama-cpp-server.ini               # Router preset: server profile
│   └── llama-cpp-server-experimental.ini  # Router preset: server experimental profile
```
Replace with:
```
├── templates/                             # llama-server INI preset templates
│   ├── llama-cpp-local.ini.template       # Router preset: local profile (low/medium/high, 128K ctx)
│   └── llama-cpp-server.ini.template      # Router preset: server profile (low/medium/high, 256K ctx)
```

- [ ] **Step 3: Update the Build/Test Commands section**

Find:
```
./bin/run-local                            # direct llama-server, local mode (127.0.0.1:8080)
./bin/run-local --experimental             # direct llama-server, local experimental mode
./bin/run-server                           # direct llama-server, server mode (0.0.0.0:8080)
./bin/run-server --experimental            # direct llama-server, server experimental mode
```
Replace with:
```
./bin/run-local                            # direct llama-server, local mode, medium tier (127.0.0.1:8080)
./bin/run-local --tier low                 # direct llama-server, local mode, low tier
./bin/run-local --tier high                # direct llama-server, local mode, high tier
./bin/run-server                           # direct llama-server, server mode, medium tier (0.0.0.0:8080)
./bin/run-server --tier low                # direct llama-server, server mode, low tier
./bin/run-server --tier high               # direct llama-server, server mode, high tier
```

- [ ] **Step 4: Update the router commands in the Build/Test Commands section**

Find:
```
./bin/run-router --experimental            # llama.cpp, local experimental mode (8080)
./bin/run-router --server --experimental   # llama.cpp, server experimental mode (8080); flags are order-independent
```
Replace with:
```
# Clients select tier via: ?model=jzaleski/low  ?model=jzaleski/medium  ?model=jzaleski/high
```

- [ ] **Step 5: Update the Environment Variables table**

The table only covers `HOST` and `PORT` — those are unchanged. No edit needed here.

- [ ] **Step 6: Update the opencode provider table in the Opencode Agent Architecture section**

Find:
```
- **llama.cpp (local - jzaleski/local)**: `localhost:8080` — Qwen3.6-35B-A3B, 81K context
- **llama.cpp (server - jzaleski/server)**: `server-hostname-or-ip:8080`, 262K context
```
Replace with:
```
- **llama.cpp (local)**: `localhost:8080` — 128K context; models: `jzaleski/low` (Gemma4-12B), `jzaleski/medium` (Qwen3.6-27B), `jzaleski/high` (MiniMax-M2.7)
- **llama.cpp (server)**: `server-hostname-or-ip:8080` — 256K context; same three aliases
```

- [ ] **Step 7: Verify no remaining references to experimental, jzaleski/local, or jzaleski/server**

```bash
grep -n "experimental\|jzaleski/local\|jzaleski/server\|81920\|conf/" /Users/jzaleski/src/jzaleski/ai-tools/AGENTS.md
```

Expected: no output (zero matches).

---

## Task 8: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the Overview paragraph**

Find:
```
This repository provides scripts and configurations for running local AI models using llama-server. It includes support for coding assistance (Qwen3.6-35B-A3B local and server) and general advising (Qwen3.6-35B-A3B local and server). Experimental profiles swap in the Qwopus3.6-35B-A3B-v1 model with tuned sampling parameters.
```
Replace with:
```
This repository provides scripts and configurations for running local AI models using llama-server. It supports three model tiers — low (Gemma4-12B), medium (Qwen3.6-27B), and high (MiniMax-M2.7) — each available in local and server modes. Tiers are purpose-oriented and stable; the models behind them can rotate without changing client-facing aliases.
```

- [ ] **Step 2: Update the Project Structure `conf/` entry**

Find:
```
├── conf/                           # llama-server INI presets
│   ├── llama-cpp-local.ini         # Router preset: local profile (Q4, q4_0 KV, 81K ctx, 127.0.0.1)
│   ├── llama-cpp-local-experimental.ini   # Router preset: local experimental profile (Q4_K_M, 81K ctx)
│   ├── llama-cpp-server.ini        # Router preset: server profile (Q8, q8_0 KV, 262K ctx, 0.0.0.0)
│   └── llama-cpp-server-experimental.ini  # Router preset: server experimental profile (Q8_0, 262K ctx)
```
Replace with:
```
├── templates/                      # llama-server INI preset templates
│   ├── llama-cpp-local.ini.template   # Router preset: local profile (low/medium/high, Q4, 128K ctx)
│   └── llama-cpp-server.ini.template  # Router preset: server profile (low/medium/high, Q8, 256K ctx)
```

- [ ] **Step 3: Update the run-local component section**

Find:
```
### run-local
Starts a single llama-server directly (no router mode) in local mode. Loads the Qwen3.6-35B-A3B model with local defaults. Supports an `--experimental` flag that swaps in the Qwopus model.

**Local Mode Defaults:**
- Host: 127.0.0.1
- Port: 8080
- Model: `unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL`
- KV cache quantization: q4_0 (K and V)
- Context size: 81920 tokens
- Batch size: 2048 / Ubatch size: 512

**Local Experimental Mode Defaults:**
- Host: 127.0.0.1
- Port: 8080
- Model: `Jackrong/Qwopus3.6-35B-A3B-v1-GGUF:Q4_K_M`
- KV cache quantization: q4_0 (K and V)
- Context size: 81920 tokens
- Batch size: 2048 / Ubatch size: 512

**Environment Variables:**
- `PORT`: Override listen port (default: 8080)
```
Replace with:
```
### run-local
Starts a single llama-server directly (no router mode) in local mode. Accepts `--tier low|medium|high` (default: `medium`). Downloads the model automatically if not present.

**Defaults (all tiers):**
- Host: 127.0.0.1
- Port: 8080
- KV cache quantization: q4_0 (K and V)
- Context size: 131072 tokens
- Batch size: 2048 / Ubatch size: 512

| Tier | Model | Quant |
|---|---|---|
| low | `unsloth/gemma-4-12b-it-GGUF` | `UD-Q4_K_XL` |
| medium | `unsloth/Qwen3.6-27B-GGUF` | `UD-Q4_K_XL` |
| high | `unsloth/MiniMax-M2.7-GGUF` | `UD-Q4_K_XL` |

**Environment Variables:**
- `PORT`: Override listen port (default: 8080)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)
```

- [ ] **Step 4: Update the run-server component section**

Find:
```
### run-server
Starts a single llama-server directly (no router mode) in server mode. Loads the Qwen3.6-35B-A3B model with server defaults. Supports an `--experimental` flag that swaps in the Qwopus model.

**Server Mode Defaults:**
- Host: 0.0.0.0
- Port: 8080
- Model: `unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q8_K_XL`
- KV cache quantization: q8_0 (K and V)
- Context size: 262144 tokens
- Batch size: 4096 / Ubatch size: 1024

**Server Experimental Mode Defaults:**
- Host: 0.0.0.0
- Port: 8080
- Model: `Jackrong/Qwopus3.6-35B-A3B-v1-GGUF:Q8_0`
- KV cache quantization: q8_0 (K and V)
- Context size: 262144 tokens
- Batch size: 4096 / Ubatch size: 1024

**Environment Variables:**
- `PORT`: Override listen port (default: 8080)
```
Replace with:
```
### run-server
Starts a single llama-server directly (no router mode) in server mode. Accepts `--tier low|medium|high` (default: `medium`). Downloads the model automatically if not present.

**Defaults (all tiers):**
- Host: 0.0.0.0
- Port: 8080
- KV cache quantization: q8_0 (K and V)
- Context size: 262144 tokens
- Batch size: 4096 / Ubatch size: 1024

| Tier | Model | Quant |
|---|---|---|
| low | `unsloth/gemma-4-12b-it-GGUF` | `UD-Q8_K_XL` |
| medium | `unsloth/Qwen3.6-27B-GGUF` | `UD-Q8_K_XL` |
| high | `unsloth/MiniMax-M2.7-GGUF` | `UD-Q8_K_XL` |

**Environment Variables:**
- `PORT`: Override listen port (default: 8080)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)
```

- [ ] **Step 5: Update the run-router component section**

Find:
```
### run-router
Starts a single llama-server in [router mode](https://github.com/ggml-org/llama.cpp/blob/master/docs/preset.md), loading the model defined in the appropriate INI preset file. Clients route to the model via `?model=jzaleski/local` (local mode) or `?model=jzaleski/server` (server mode). Supports both local and server modes via `--server` flag, and an `--experimental` flag that swaps in the experimental preset (different model/quantization).

**Local Mode Defaults:**
- Preset: `conf/llama-cpp-local.ini`
- Host: 127.0.0.1
- Port: 8080
- Quantization: UD-Q4_K_XL
- KV cache quantization: q4_0 (K and V)
- Context size: 81920 tokens
- Batch size: 2048 / Ubatch size: 512

**Local Experimental Mode Defaults:**
- Preset: `conf/llama-cpp-local-experimental.ini`
- Host: 127.0.0.1
- Port: 8080
- Model: `Jackrong/Qwopus3.6-35B-A3B-v1-GGUF:Q4_K_M`
- KV cache quantization: q4_0 (K and V)
- Context size: 81920 tokens
- Batch size: 2048 / Ubatch size: 512

**Server Mode Defaults:**
- Preset: `conf/llama-cpp-server.ini`
- Host: 0.0.0.0
- Port: 8080
- Quantization: UD-Q8_K_XL
- KV cache quantization: q8_0 (K and V)
- Context size: 262144 tokens
- Batch size: 4096 / Ubatch size: 1024

**Server Experimental Mode Defaults:**
- Preset: `conf/llama-cpp-server-experimental.ini`
- Host: 0.0.0.0
- Port: 8080
- Model: `Jackrong/Qwopus3.6-35B-A3B-v1-GGUF:Q8_0`
- KV cache quantization: q8_0 (K and V)
- Context size: 262144 tokens
- Batch size: 4096 / Ubatch size: 1024

**Environment Variables:**
- `HOST`: Override bind address
- `PORT`: Override listen port (default: 8080)
```
Replace with:
```
### run-router
Starts a single llama-server in [router mode](https://github.com/ggml-org/llama.cpp/blob/master/docs/preset.md), loading all three tiers from the rendered INI preset. Supports `--server` flag for server mode (default: local). Clients select a tier via the `model` parameter.

**Local Mode Defaults:**
- Preset: `templates/llama-cpp-local.ini.template` → rendered to `tmp/llama-cpp-local.ini`
- Host: 127.0.0.1
- Port: 8080
- KV cache quantization: q4_0 (K and V)
- Context size: 131072 tokens
- Batch size: 2048 / Ubatch size: 512

**Server Mode Defaults:**
- Preset: `templates/llama-cpp-server.ini.template` → rendered to `tmp/llama-cpp-server.ini`
- Host: 0.0.0.0
- Port: 8080
- KV cache quantization: q8_0 (K and V)
- Context size: 262144 tokens
- Batch size: 4096 / Ubatch size: 1024

**Environment Variables:**
- `HOST`: Override bind address
- `PORT`: Override listen port (default: 8080)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)
```

- [ ] **Step 6: Update the Usage section**

Find:
```
# Start local server directly (no router, localhost:8080)
./bin/run-local

# Start local server with experimental model
./bin/run-local --experimental

# Start server mode directly (no router, 0.0.0.0:8080)
./bin/run-server

# Start server mode with experimental model
./bin/run-server --experimental

# Start router (llama.cpp, local mode — jzaleski/local on localhost:8080)
./bin/run-router

# Start router (llama.cpp, server mode — jzaleski/server on 0.0.0.0:8080)
./bin/run-router --server

# Start router (llama.cpp, local experimental mode — Qwopus model on localhost:8080)
./bin/run-router --experimental

# Start router (llama.cpp, server experimental mode — Qwopus model on 0.0.0.0:8080)
./bin/run-router --server --experimental
```
Replace with:
```
# Start local server directly — medium tier (default)
./bin/run-local

# Start local server — specific tier
./bin/run-local --tier low
./bin/run-local --tier high

# Start server mode directly — medium tier (default)
./bin/run-server

# Start server mode — specific tier
./bin/run-server --tier low
./bin/run-server --tier high

# Start router (local mode — all three tiers available on localhost:8080)
./bin/run-router

# Start router (server mode — all three tiers available on 0.0.0.0:8080)
./bin/run-router --server
```

- [ ] **Step 7: Update the client model selection examples**

Find:
```
curl http://localhost:8080/v1/chat/completions?model=jzaleski/local  ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/server ...
```
Replace with:
```
curl http://localhost:8080/v1/chat/completions?model=jzaleski/low    ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/medium ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/high   ...
```

- [ ] **Step 8: Update the router architecture ASCII diagram model alias labels**

Find:
```
   │ ┌──────────────────┐ │
   │ │jzaleski/local    │ │
   │ │(or /server)      │ │
   │ └──────────────────┘ │
```
Replace with:
```
   │ ┌──────────────────┐ │
   │ │jzaleski/low      │ │
   │ │jzaleski/medium   │ │
   │ │jzaleski/high     │ │
   │ └──────────────────┘ │
```

- [ ] **Step 9: Update the opencode provider table**

Find:
```
| llama.cpp (local) | `localhost:8080` | jzaleski/local | 81,920 | 73,728 | 8,192 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/server | 262,144 | 245,760 | 16,384 | text+image in, text out |
```
Replace with:
```
| llama.cpp (local) | `localhost:8080` | jzaleski/low, jzaleski/medium, jzaleski/high | 131,072 | 122,880 | 8,192 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/low, jzaleski/medium, jzaleski/high | 262,144 | 245,760 | 16,384 | text+image in, text out |
```

- [ ] **Step 10: Update the Performance Tips context size note**

Find:
```
- Context size: 81920 tokens (local), 262144 tokens (server)
```
Replace with:
```
- Context size: 131072 tokens (local), 262144 tokens (server)
```

- [ ] **Step 11: Verify no remaining references to experimental, jzaleski/local, jzaleski/server, 81920, or conf/**

```bash
grep -n "experimental\|jzaleski/local\|jzaleski/server\|81920\|conf/" /Users/jzaleski/src/jzaleski/ai-tools/README.md
```

Expected: no output (zero matches).

---

## Parallel Dispatch Analysis

### Batch 1 (independent — dispatch together):

- **Task 1** (`templates/llama-cpp-local.ini.template` + delete experimental local template)
- **Task 2** (`templates/llama-cpp-server.ini.template` + delete experimental server template)
- **Task 3** (`bin/run-router`)
- **Task 4** (`bin/run-local`)
- **Task 5** (`bin/run-server`)
- **Task 6** (`home/.config/opencode/opencode.json`)

Rationale: All six tasks touch completely different files with no cross-dependencies. The templates don't depend on the scripts; the scripts don't depend on each other; opencode.json is independent of all of them.

### Batch 2 (depends on Batch 1):

- **Task 7** (`AGENTS.md`) + **Task 8** (`README.md`)

Rationale: Documentation must reflect the final state of all files changed in Batch 1. Both doc tasks are independent of each other and can run in parallel within Batch 2.
