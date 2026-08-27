# Dual-Router Architecture Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Refactor the model router architecture to support standard (`jzaleski/default/*`) and experimental (`jzaleski/experimental/*`) namespaces running on separate ports via a unified script, and update client run scripts/configs to match.

**Architecture:** 
- The existing `llama-cpp.ini.template` becomes `llama-cpp-default.ini.template` (using the `jzaleski/default/` prefix).
- A new `llama-cpp-experimental.ini.template` is created for experimental models (`jzaleski/experimental/quark`, `jzaleski/experimental/boson`).
- `bin/run-router` is updated to parse `--default` and `--experimental` flags, routing to the appropriate template and default port (8080 or 8081).
- `bin/run-model` is updated to handle the new structured namespaces.
- `opencode.json` and documentation are updated to reflect the new architecture.

**Tech Stack:** Bash, JSON, INI templates

---

### Task 1: Rename and Update the Default Router Template

**Files:**
- Modify: `templates/llama-cpp-default.ini.template` (Rename from `templates/llama-cpp.ini.template`)

- [ ] **Step 1: Rename the template file**

```bash
mv templates/llama-cpp.ini.template templates/llama-cpp-default.ini.template
```

- [ ] **Step 2: Update the aliases to use the `jzaleski/default/` namespace**
Edit `templates/llama-cpp-default.ini.template` to update the section headers:
`[jzaleski/low]` -> `[jzaleski/default/low]`
`[jzaleski/medium]` -> `[jzaleski/default/medium]`
`[jzaleski/high]` -> `[jzaleski/default/high]`
`[jzaleski/low-multimodal]` -> `[jzaleski/default/low-multimodal]`
`[jzaleski/medium-multimodal]` -> `[jzaleski/default/medium-multimodal]`
`[jzaleski/high-multimodal]` -> `[jzaleski/default/high-multimodal]`

- [ ] **Step 3: Commit**

```bash
git add templates/llama-cpp.ini.template templates/llama-cpp-default.ini.template
git commit -m "refactor(templates): rename router template and apply default namespace"
```

---

### Task 2: Create the Experimental Router Template

**Files:**
- Create: `templates/llama-cpp-experimental.ini.template`

- [ ] **Step 1: Create the template with the quark (DeepSeek) and boson (Qwen) configs**

```ini
# Experimental Router preset config
# Keys use llama-server long-form flag names (no leading dashes).
# The [*] section supplies defaults inherited by every model section.
# Bind address is supplied by the launcher via --host (HOST env var).

[*]
flash-attn         = on
n-gpu-layers       = -1
reasoning-preserve = 1
cache-reuse        = 256
cache-ram          = -1
load-mode          = mlock
predict            = 262144
presence-penalty   = 0.0
repeat-penalty     = 1.0
min-p              = 0.0

[jzaleski/experimental/quark]
model             = MODELS_DIR/unsloth/DeepSeek-V4-Flash-0731-GGUF/DeepSeek-V4-Flash-0731-UD-Q8_K_XL-00001-of-00005.gguf
spec-draft-model  = MODELS_DIR/unsloth/DeepSeek-V4-Flash-0731-GGUF/dspark-DeepSeek-V4-Flash-0731-Q8_0.gguf
ctx-size          = 1048576
batch-size        = 1024
ubatch-size       = 256
cache-type-k      = q8_0
cache-type-v      = q8_0
spec-type         = draft-dspark
spec-draft-n-max  = 3
chat-template-kwargs = {"reasoning_effort":"high"}
min-p             = 0.01
temp              = 1.0
top-p             = 0.95

[jzaleski/experimental/boson]
model             = MODELS_DIR/unsloth/Qwen3.8-Flash-Next-GGUF/Qwen3.8-Flash-Next-UD-Q8_K_XL.gguf
ctx-size          = 262144
batch-size        = 1024
ubatch-size       = 256
cache-type-k      = q8_0
cache-type-v      = q8_0
spec-type         = draft-mtp
spec-draft-n-max  = 3
chat-template-kwargs = {"reasoning_effort":"high"}
temp              = 1.0
top-k             = 20
top-p             = 0.95
```

- [ ] **Step 2: Commit**

```bash
git add templates/llama-cpp-experimental.ini.template
git commit -m "feat(templates): add experimental router template for quark and boson"
```

---

### Task 3: Update bin/run-router Script

**Files:**
- Modify: `bin/run-router`

- [ ] **Step 1: Add the require_experimental_models function**
Add this function before `main()`:
```bash
require_experimental_models() {
  # quark: DeepSeek-V4-Flash
  require_split_model "${MODELS_DIR}/unsloth/DeepSeek-V4-Flash-0731-GGUF/DeepSeek-V4-Flash-0731-UD-Q8_K_XL.gguf" "unsloth/DeepSeek-V4-Flash-0731-GGUF" "UD-Q8_K_XL/DeepSeek-V4-Flash-0731-UD-Q8_K_XL.gguf" 5;
  require_model "${MODELS_DIR}/unsloth/DeepSeek-V4-Flash-0731-GGUF/dspark-DeepSeek-V4-Flash-0731-Q8_0.gguf" "unsloth/DeepSeek-V4-Flash-0731-GGUF" "dspark-DeepSeek-V4-Flash-0731-Q8_0.gguf";

  # boson: Qwen3.8-Flash-Next
  require_model "${MODELS_DIR}/unsloth/Qwen3.8-Flash-Next-GGUF/Qwen3.8-Flash-Next-UD-Q8_K_XL.gguf" "unsloth/Qwen3.8-Flash-Next-GGUF" "Qwen3.8-Flash-Next-UD-Q8_K_XL.gguf";
}

# Ensure all parts of a split GGUF model exist, downloading them if missing.
# Args: <base-model-file> <hf-repo> <hf-base-filename> [num-parts]
require_split_model() {
  local base_model_file="${1}";
  local hf_repo="${2}";
  local hf_base_filename="${3}";
  local num_parts="${4:-1}";

  if [[ "${num_parts}" -eq 1 ]]; then
    require_model "${base_model_file}" "${hf_repo}" "${hf_base_filename}";
    return 0;
  fi

  local local_dir="$(dirname "${base_model_file}")";
  local local_base="$(basename "${base_model_file}" .gguf)";
  local hf_dir="$(dirname "${hf_base_filename}")";
  local hf_base="$(basename "${hf_base_filename}" .gguf)";
  
  if [[ "${hf_dir}" == "." ]]; then
    hf_dir="";
  else
    hf_dir="${hf_dir}/";
  fi

  local i;
  for ((i=1; i<=num_parts; i++)); do
    local part_suffix;
    part_suffix=$(printf -- "-%05d-of-%05d.gguf" "${i}" "${num_parts}");
    require_model "${local_dir}/${local_base}${part_suffix}" "${hf_repo}" "${hf_dir}${hf_base}${part_suffix}";
  done
}
```

- [ ] **Step 2: Update main() to handle flags and port routing**
Replace `main()` with:
```bash
main() {
  local mode="default";
  for arg in "$@"; do
    case "${arg}" in
      --experimental) mode="experimental";;
      --default)      mode="default";;
    esac
  done

  local preset_file;
  local default_port;

  if [[ "${mode}" == "experimental" ]]; then
    require_experimental_models;
    preset_file="${TEMPLATES_DIR}/llama-cpp-experimental.ini.template";
    default_port="8081";
  else
    require_models;
    preset_file="${TEMPLATES_DIR}/llama-cpp-default.ini.template";
    default_port="8080";
  fi

  local preset;
  preset="$(render_preset "${preset_file}")";
  
  exec llama-server \
    --host "${HOST:-"127.0.0.1"}" \
    --port "${PORT:-"${default_port}"}" \
    --models-preset "${preset}";
}
```

- [ ] **Step 3: Test syntax and commit**

```bash
bash -n bin/run-router
git add bin/run-router
git commit -m "feat(router): add flag-driven routing to default/experimental templates and ports"
```

---

### Task 4: Update bin/run-model Script

**Files:**
- Modify: `bin/run-model`

- [ ] **Step 1: Update tier matching logic**
At the bottom of the script, update the `case "${tier}" in` block:
```bash
tier="default/medium";
# ... (argument parsing stays the same) ...

case "${tier}" in
  default/low)               run_low;;
  default/medium)            run_medium;;
  default/high)              run_high;;
  default/low-multimodal)    run_low_multimodal;;
  default/medium-multimodal) run_medium_multimodal;;
  default/high-multimodal)   run_high_multimodal;;
  experimental/quark)        run_experimental_quark;;
  experimental/boson)        run_experimental_boson;;
  experimental)
    echo "Error: the 'experimental' tier has been removed. Use experimental/quark or experimental/boson." >&2;
    exit 1;;
  low|medium|high|low-multimodal|medium-multimodal|high-multimodal)
    echo "Error: standard tiers have moved to the default/ namespace (e.g. default/${tier})." >&2;
    exit 1;;
  *)
    echo "Error: unknown tier '${tier}'. Use: default/low, default/medium, default/high, default/low-multimodal, default/medium-multimodal, default/high-multimodal, experimental/quark, experimental/boson" >&2;
    exit 1;;
esac
```

- [ ] **Step 2: Update run functions and aliases**
Edit `run_low`, `run_medium`, etc. to change `--alias jzaleski/low` to `--alias jzaleski/default/low`. Do this for all 6 standard models.
Rename `run_experimental()` to `run_experimental_quark()`, and change its alias to `--alias jzaleski/experimental/quark`.

- [ ] **Step 3: Add run_experimental_boson() for Qwen3.8-Flash-Next**
Add this function before the arg parsing block:
```bash
run_experimental_boson() {
  local model="${MODELS_DIR}/unsloth/Qwen3.8-Flash-Next-GGUF/Qwen3.8-Flash-Next-UD-Q8_K_XL.gguf";
  require_model "${model}" "unsloth/Qwen3.8-Flash-Next-GGUF" "Qwen3.8-Flash-Next-UD-Q8_K_XL.gguf";
  exec llama-server \
    --model            "${model}" \
    --alias            jzaleski/experimental/boson \
    --host             "${HOST:-"127.0.0.1"}" \
    --port             "${PORT:-"8080"}" \
    --flash-attn       on \
    --n-gpu-layers     -1 \
    --batch-size       1024 \
    --ubatch-size      256 \
    --ctx-size         262144 \
    --cache-type-k     q8_0 \
    --cache-type-v     q8_0 \
    --spec-type        draft-mtp \
    --spec-draft-n-max 3 \
    --chat-template-kwargs '{"reasoning_effort":"high"}' \
    --reasoning-preserve \
    --cache-reuse      256 \
    --cache-ram        -1 \
    --load-mode        mlock \
    --predict          262144 \
    --presence-penalty 0.0 \
    --repeat-penalty   1.0 \
    --min-p            0.0 \
    --temp             1.0 \
    --top-k            20 \
    --top-p            0.95;
}
```

- [ ] **Step 4: Test syntax and commit**

```bash
bash -n bin/run-model
git add bin/run-model
git commit -m "feat(model): update namespaces and add experimental/boson model"
```

---

### Task 5: Update opencode.json Configuration

**Files:**
- Modify: `home/.config/opencode/opencode.json`

- [ ] **Step 1: Create a script to generate the updated JSON**
Run this to safely mutate the JSON using jq (it handles the namespace renaming and adds the 8081 router):

```bash
cat << 'EOF' > tmp/update_opencode.jq
.provider["llama.cpp (local) (default)"] = .provider["llama.cpp (local)"] |
.provider["llama.cpp (local) (default)"].name = "llama.cpp (local) (default)" |
.provider["llama.cpp (local) (default)"].models = (
  .provider["llama.cpp (local) (default)"].models | with_entries(.key |= sub("jzaleski/"; "jzaleski/default/") | .value.name |= sub("jzaleski/"; "jzaleski/default/"))
) |

.provider["llama.cpp (server) (default)"] = .provider["llama.cpp (server)"] |
.provider["llama.cpp (server) (default)"].name = "llama.cpp (server) (default)" |
.provider["llama.cpp (server) (default)"].models = (
  .provider["llama.cpp (server) (default)"].models | with_entries(.key |= sub("jzaleski/"; "jzaleski/default/") | .value.name |= sub("jzaleski/"; "jzaleski/default/"))
) |

.provider["llama.cpp (local) (experimental)"] = {
  "npm": "@ai-sdk/openai-compatible",
  "name": "llama.cpp (local) (experimental)",
  "options": {
    "baseURL": "http://localhost:8081/v1"
  },
  "models": {
    "jzaleski/experimental/quark": {
      "name": "jzaleski/experimental/quark",
      "limit": {
        "context": 1048576,
        "input": 917504,
        "output": 131072
      },
      "modalities": {
        "input": ["text"],
        "output": ["text"]
      }
    },
    "jzaleski/experimental/boson": {
      "name": "jzaleski/experimental/boson",
      "limit": {
        "context": 262144,
        "input": 229376,
        "output": 32768
      },
      "modalities": {
        "input": ["text"],
        "output": ["text"]
      }
    }
  }
} |
del(.provider["llama.cpp (local)"]) |
del(.provider["llama.cpp (server)"])
EOF

jq -f tmp/update_opencode.jq home/.config/opencode/opencode.json > tmp/opencode.json.new
mv tmp/opencode.json.new home/.config/opencode/opencode.json
```

- [ ] **Step 2: Commit**

```bash
git add home/.config/opencode/opencode.json
git commit -m "config(opencode): update provider to dual router namespaces and ports"
```

---

### Task 6: Update Documentation

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Update the architecture and commands sections in AGENTS.md**
Update mentions of the models from `jzaleski/<tier>` to `jzaleski/default/<tier>`, and document the experimental router behavior (`8081`) and namespace (`jzaleski/experimental/<particle>`). Include the `--default` and `--experimental` flags. Remove mentions of `--tier experimental` in favor of `--tier experimental/quark` and `--tier experimental/boson`.

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md for dual router and namespace architecture"
```

---

## Parallel Dispatch Analysis

### Batch 1 (independent — dispatch together):
- Task 1 (Templates)
- Task 2 (Experimental Template)
- Task 3 (Router Script)
- Task 4 (Model Script)
- Task 5 (Opencode config)
- Task 6 (Docs)

All 6 tasks can run in parallel. They modify mutually exclusive files and rely entirely on the design spec, not on each other's code implementation order.

(Note for Orchestrator: Given the small scale of these tasks and their direct file modification nature without complex testing compilation requirements, Batch 1 is safe to run in a single dispatch step if using independent workers).
