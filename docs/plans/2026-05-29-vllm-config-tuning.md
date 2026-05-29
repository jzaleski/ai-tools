# vLLM Config Tuning & cipher/sage Client Sampling Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Register both `jzaleski/cipher` and `jzaleski/sage` on the vLLM Metal backend, restore their behavioral distinction via client-side sampling in opencode, right-size vLLM concurrency/context, lower the llama.cpp **server** context to match, and sync documentation.

**Architecture:** Config-only change set (no application code). vLLM serves one checkpoint under two alias names; per-alias sampling lives in the opencode client (`opencode.json`) because vLLM cannot do per-alias server-side sampling. Server context is lowered to 131072 on both the vLLM YAML and the llama.cpp server INI (llama.cpp local INI untouched). An empirical verification gate confirms which sampling fields opencode actually forwards to vLLM, and documentation reflects the truth.

**Tech Stack:** Bash launcher (`bin/run-router`), vLLM `vllm serve --config` YAML, llama.cpp `--models-preset` INI, opencode `@ai-sdk/openai-compatible` provider JSON. macOS (darwin), Apple Silicon (M3 Ultra), vllm-metal 0.2.0 / vllm 0.21.0.

**Design reference:** `docs/specs/2026-05-29-vllm-config-tuning-design.md`

**Context limit convention (when lowering 262144 → 131072):** keep the same proportions as the existing 262144 rows — `context: 131072`, `input: 114688` (≈87.5%), `output: 16384` (half of the prior 32768). Applied to the two llama.cpp-server rows only.

---

### Task 1: vLLM server config — aliases, concurrency, context, doc comments

**Files:**
- Modify: `conf/vllm-server.yaml`

The file currently looks like this (the two-alias `served-model-name` from A.1 is already in the working tree):

```yaml
# vLLM server config — native `vllm serve --config` format.
# Keys are the long-form of `vllm serve` CLI flags (hyphenated). CLI flags
# passed by bin/run-router (host, port) take precedence over this file.
#
# Backend: vllm-metal (MLX, Apple Silicon, text-only). The Metal backend loads
# via mlx_lm, which requires an MLX-format checkpoint (model*.safetensors). We
# use the mlx-community 8-bit build to mirror the llama.cpp Q8 server preset.
# The Qwen3.6 hybrid model requires prefix caching to be DISABLED on Metal.

model: mlx-community/Qwen3.6-35B-A3B-8bit
# Both aliases map to the SAME loaded checkpoint. vLLM serves one model per
# process; cipher and sage differ only in per-request sampling (see profiles
# below), which the client supplies at inference time. Registering both names
# makes /v1/models expose both and routes either alias to the loaded weights.
served-model-name:
  - jzaleski/cipher
  - jzaleski/sage
max-model-len: 262144
enable-prefix-caching: false
enable-auto-tool-choice: true
tool-call-parser: hermes
```
(…followed by the `# --- Per-request sampling profiles ---` comment block and the `# --- Memory control (Metal) ---` block.)

- [ ] **Step 1: Replace the top comment block + header keys**

Use the Edit tool. Replace this exact block:

```yaml
# Backend: vllm-metal (MLX, Apple Silicon, text-only). The Metal backend loads
# via mlx_lm, which requires an MLX-format checkpoint (model*.safetensors). We
# use the mlx-community 8-bit build to mirror the llama.cpp Q8 server preset.
# The Qwen3.6 hybrid model requires prefix caching to be DISABLED on Metal.
```

with:

```yaml
# Backend: vllm-metal (MLX, Apple Silicon, text-only). The Metal backend loads
# via mlx_lm, which requires an MLX-format checkpoint (model*.safetensors). We
# use the mlx-community 8-bit build to mirror the llama.cpp Q8 server preset.
#
# Prefix caching MUST stay disabled: Qwen3.6 is a hybrid (SDPA + GDN) model, and
# core vLLM (vllm/config/model.py, `is_prefix_caching_supported`) returns False
# for any generative model with attn_type == "hybrid" ("Hybrid models do not
# support prefix caching since the feature is still experimental"). Enabling it
# would be ignored or risk crashes. The full-prefill cost per request is inherent
# to this model on vLLM, not a misconfiguration.
```

- [ ] **Step 2: Change `max-model-len` and add `max-num-seqs`**

Use the Edit tool. Replace this exact block:

```yaml
max-model-len: 262144
enable-prefix-caching: false
enable-auto-tool-choice: true
tool-call-parser: hermes
```

with:

```yaml
# Lowered from the model's trained max (262144) to reduce KV-cache pressure and
# improve single/few-user decode locality. 131072 is still a very large coding
# context. See docs/specs/2026-05-29-vllm-config-tuning-design.md (B.1).
max-model-len: 131072
# Cap concurrency to a moderate level for occasional parallel sub-agent dispatch.
# The implicit default (1024) over-reserves hybrid GDN state (~64.4MB/seq ≈ 66GB);
# 16 seqs ≈ 1.03GB, freeing memory without hurting the expected workload (B.1).
max-num-seqs: 16
enable-prefix-caching: false
enable-auto-tool-choice: true
tool-call-parser: hermes
```

- [ ] **Step 3: Repoint the sampling-profiles comment block**

Use the Edit tool. Replace this exact block:

```yaml
# --- Per-request sampling profiles (NOT server config) ---
# vLLM applies these per request; the client sends them at inference time.
# Documented here for parity with the llama.cpp cipher/sage aliases.
#
# Shared defaults:
#   temperature: 1.0
#   top_p: 0.95
#   presence_penalty: 1.5
#   repetition_penalty: 1.0
#
# jzaleski/cipher:
#   min_p: 0.01
#   top_k: 40
#
# jzaleski/sage:
#   min_p: 0.0
#   top_k: 20
```

with:

```yaml
# --- Per-request sampling profiles (NOT server config) ---
# vLLM serves ONE checkpoint; cipher vs. sage is purely a client-side per-request
# sampling distinction. These profiles are configured in the opencode client
# (home/.config/opencode/opencode.json) on the two vLLM provider entries, NOT
# here. Listed for reference only. Which fields actually reach vLLM depends on
# what the opencode @ai-sdk/openai-compatible provider forwards — see AGENTS.md.
#
# Shared:           temperature 1.0, top_p 0.95, presence_penalty 1.5, repetition_penalty 1.0
# jzaleski/cipher:  min_p 0.01, top_k 40
# jzaleski/sage:    min_p 0.0,  top_k 20
```

- [ ] **Step 4: Validate the YAML parses**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('conf/vllm-server.yaml')); print('OK')"`
Expected: `OK`

- [ ] **Step 5: Confirm key values via parse**

Run: `python3 -c "import yaml; d=yaml.safe_load(open('conf/vllm-server.yaml')); print(d['max-model-len'], d['max-num-seqs'], d['enable-prefix-caching'], d['served-model-name'])"`
Expected: `131072 16 False ['jzaleski/cipher', 'jzaleski/sage']`

- [ ] **Step 6: Commit**

```bash
git add conf/vllm-server.yaml
git commit -m "feat(vllm): dual aliases, max-num-seqs cap, lower context, doc prefix-caching"
```

---

### Task 2: llama.cpp server INI — lower context only

**Files:**
- Modify: `conf/router-server.ini`

The file currently contains (full file):

```ini
# Router preset config — server mode
# Keys use llama-server long-form flag names (no leading dashes).
# The [*] section supplies defaults inherited by every model section.
# Each named section becomes a routable model alias.

[*]
hf                = unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q8_K_XL
flash-attn        = on
n-gpu-layers      = -1
batch-size        = 4096
ubatch-size       = 1024
ctx-size          = 262144
cache-type-k      = q8_0
cache-type-v      = q8_0
presence-penalty  = 1.5
repeat-penalty    = 1.0
temp              = 1.0
top-p             = 0.95

[jzaleski/cipher]
min-p             = 0.01
top-k             = 40

[jzaleski/sage]
min-p             = 0.0
top-k             = 20
```

> **IMPORTANT:** Change ONLY the `ctx-size` line. Do NOT touch any sampling keys
> or the `[jzaleski/cipher]` / `[jzaleski/sage]` sections — llama.cpp sampling
> relocation is explicitly deferred (design Out of Scope).

- [ ] **Step 1: Lower the server context size**

Use the Edit tool. Replace this exact line:

```ini
ctx-size          = 262144
```

with:

```ini
ctx-size          = 131072
```

- [ ] **Step 2: Confirm the change and that sampling is untouched**

Run: `grep -nE "ctx-size|min-p|top-k|presence-penalty|repeat-penalty|temp|top-p" conf/router-server.ini`
Expected output (sampling lines unchanged, ctx-size now 131072):
```
ctx-size          = 131072
presence-penalty  = 1.5
repeat-penalty    = 1.0
temp              = 1.0
top-p             = 0.95
min-p             = 0.01
top-k             = 40
min-p             = 0.0
top-k             = 20
```

- [ ] **Step 3: Commit**

```bash
git add conf/router-server.ini
git commit -m "feat(llama.cpp): lower server ctx-size to 131072 for consistency"
```

---

### Task 3: opencode.json — vLLM sampling options + llama.cpp-server context sync

**Files:**
- Modify: `home/.config/opencode/opencode.json`

There are TWO distinct edits in this file:
1. Add sampling `options` to the two **vLLM** model entries (lines ~129 cipher, ~154 sage).
2. Lower `limit.context`/`input`/`output` on the two **llama.cpp-server** model entries (lines ~77 cipher, ~103 sage).

The vLLM cipher entry currently reads:

```json
        "jzaleski/cipher": {
          "name": "jzaleski/cipher",
          "limit": {
            "context": 262144,
            "input": 229376,
            "output": 32768
          },
          "modalities": {
            "input": [
              "text"
            ],
            "output": [
              "text"
            ]
          }
        }
```

> **NOTE on sampling field names:** opencode's `@ai-sdk/openai-compatible`
> provider passes `options` to the AI SDK. `temperature` and `topP` are standard
> AI-SDK settings. `top_k`, `min_p`, `presence_penalty`, `repetition_penalty`
> are non-standard for the OpenAI chat schema and are forwarded as extra body
> fields. We add them using the OpenAI-style snake_case body keys
> (`top_k`, `min_p`, `presence_penalty`, `repetition_penalty`) plus the standard
> `temperature` and `top_p`. Task 5 (A.3) empirically verifies which actually
> reach vLLM and documents the result.

- [ ] **Step 1: Add sampling options to the vLLM cipher entry**

Use the Edit tool. Replace this exact block (the vLLM cipher model body, the one under `"vLLM (server - jzaleski/cipher)"`):

```json
        "jzaleski/cipher": {
          "name": "jzaleski/cipher",
          "limit": {
            "context": 262144,
            "input": 229376,
            "output": 32768
          },
          "modalities": {
            "input": [
              "text"
            ],
            "output": [
              "text"
            ]
          }
        }
      }
    },
    "vLLM (server - jzaleski/sage)": {
```

with:

```json
        "jzaleski/cipher": {
          "name": "jzaleski/cipher",
          "limit": {
            "context": 131072,
            "input": 114688,
            "output": 16384
          },
          "options": {
            "temperature": 1.0,
            "top_p": 0.95,
            "presence_penalty": 1.5,
            "repetition_penalty": 1.0,
            "top_k": 40,
            "min_p": 0.01
          },
          "modalities": {
            "input": [
              "text"
            ],
            "output": [
              "text"
            ]
          }
        }
      }
    },
    "vLLM (server - jzaleski/sage)": {
```

> The vLLM context is lowered to 131072 here too, matching the server's new
> `max-model-len` (Task 1). Same proportional sublimits.

- [ ] **Step 2: Add sampling options to the vLLM sage entry**

Use the Edit tool. Replace this exact block (the vLLM sage model body — it is the LAST `jzaleski/sage` block in the file, immediately before the closing of the `provider` object and the `"plugin"` key):

```json
        "jzaleski/sage": {
          "name": "jzaleski/sage",
          "limit": {
            "context": 262144,
            "input": 229376,
            "output": 32768
          },
          "modalities": {
            "input": [
              "text"
            ],
            "output": [
              "text"
            ]
          }
        }
      }
    }
  },
  "plugin": [],
```

with:

```json
        "jzaleski/sage": {
          "name": "jzaleski/sage",
          "limit": {
            "context": 131072,
            "input": 114688,
            "output": 16384
          },
          "options": {
            "temperature": 1.0,
            "top_p": 0.95,
            "presence_penalty": 1.5,
            "repetition_penalty": 1.0,
            "top_k": 20,
            "min_p": 0.0
          },
          "modalities": {
            "input": [
              "text"
            ],
            "output": [
              "text"
            ]
          }
        }
      }
    }
  },
  "plugin": [],
```

- [ ] **Step 3: Lower context on the llama.cpp-server cipher entry**

Use the Edit tool. Replace this exact block (under `"llama.cpp (server - jzaleski/cipher)"`):

```json
        "jzaleski/cipher": {
          "name": "jzaleski/cipher",
          "limit": {
            "context": 262144,
            "input": 229376,
            "output": 32768
          },
          "modalities": {
            "input": [
              "text",
              "image"
            ],
            "output": [
              "text"
            ]
          }
        }
      }
    },
    "llama.cpp (server - jzaleski/sage)": {
```

with:

```json
        "jzaleski/cipher": {
          "name": "jzaleski/cipher",
          "limit": {
            "context": 131072,
            "input": 114688,
            "output": 16384
          },
          "modalities": {
            "input": [
              "text",
              "image"
            ],
            "output": [
              "text"
            ]
          }
        }
      }
    },
    "llama.cpp (server - jzaleski/sage)": {
```

- [ ] **Step 4: Lower context on the llama.cpp-server sage entry**

Use the Edit tool. Replace this exact block (under `"llama.cpp (server - jzaleski/sage)"`, the one whose `baseURL` is `server-hostname-or-ip` and modalities include `image`, immediately before `"vLLM (server - jzaleski/cipher)"`):

```json
        "jzaleski/sage": {
          "name": "jzaleski/sage",
          "limit": {
            "context": 262144,
            "input": 229376,
            "output": 32768
          },
          "modalities": {
            "input": [
              "text",
              "image"
            ],
            "output": [
              "text"
            ]
          }
        }
      }
    },
    "vLLM (server - jzaleski/cipher)": {
```

with:

```json
        "jzaleski/sage": {
          "name": "jzaleski/sage",
          "limit": {
            "context": 131072,
            "input": 114688,
            "output": 16384
          },
          "modalities": {
            "input": [
              "text",
              "image"
            ],
            "output": [
              "text"
            ]
          }
        }
      }
    },
    "vLLM (server - jzaleski/cipher)": {
```

- [ ] **Step 5: Validate JSON**

Run: `jq . home/.config/opencode/opencode.json > /dev/null && echo OK`
Expected: `OK`

- [ ] **Step 6: Confirm no 262144 values remain and vLLM options landed**

Run: `jq '[.. | objects | select(has("context")) | .context] | unique' home/.config/opencode/opencode.json`
Expected: `[81920, 131072]` (local stays 81920; everything else now 131072; no 262144)

Run: `jq '.provider["vLLM (server - jzaleski/cipher)"].models["jzaleski/cipher"].options' home/.config/opencode/opencode.json`
Expected:
```json
{
  "temperature": 1,
  "top_p": 0.95,
  "presence_penalty": 1.5,
  "repetition_penalty": 1,
  "top_k": 40,
  "min_p": 0.01
}
```

Run: `jq '.provider["vLLM (server - jzaleski/sage)"].models["jzaleski/sage"].options.top_k' home/.config/opencode/opencode.json`
Expected: `20`

- [ ] **Step 7: Commit**

```bash
git add home/.config/opencode/opencode.json
git commit -m "feat(opencode): vLLM cipher/sage sampling options; sync server context to 131072"
```

---

### Task 4: Documentation sync — README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the server-mode context default (line ~157)**

Use the Edit tool. Replace this exact line:

```
- Context size: 262144 tokens
```

with:

```
- Context size: 131072 tokens
```

> There is exactly one occurrence of `- Context size: 262144 tokens` (the server-mode
> block at line ~157). The local-mode block uses a different value. If the Edit tool
> reports multiple matches, include the surrounding lines `- KV cache quantization: q8_0 (K and V)` (above) and `- Batch size: 4096 / Ubatch size: 1024` (below) to disambiguate.

- [ ] **Step 2: Update the vLLM "Configuration" bullets to mention concurrency cap**

Use the Edit tool. Replace this exact line:

```
- Qwen3.6 runs with prefix caching **disabled** on Metal.
```

with:

```
- Qwen3.6 runs with prefix caching **disabled** on Metal — this is mandatory:
  core vLLM disables prefix caching for hybrid (SDPA + GDN) models. The
  full-prefill cost per request is inherent, not a misconfiguration.
- `max-model-len` is 131072 and `max-num-seqs` is 16 (moderate concurrency for
  occasional parallel sub-agent dispatch; avoids over-reserving hybrid GDN state).
```

- [ ] **Step 3: Update the architecture diagram server-context labels (line ~312)**

Use the Edit tool. Replace this exact block:

```
│  │ Server Cipher  │  │ │ Server Sage    │
│  │ remote:8080    │  │ │ remote:8080    │
│  │ 262K context   │  │ │ 262K context   │
```

with:

```
│  │ Server Cipher  │  │ │ Server Sage    │
│  │ remote:8080    │  │ │ remote:8080    │
│  │ 131K context   │  │ │ 131K context   │
```

- [ ] **Step 4: Update the provider table rows (lines ~325-328)**

Use the Edit tool. Replace this exact block:

```
| llama.cpp (server - jzaleski/cipher) | `server-hostname-or-ip:8080` | jzaleski/cipher | 262,144 | 229,376 | 32,768 | text+image in, text out |
| llama.cpp (server - jzaleski/sage) | `server-hostname-or-ip:8080` | jzaleski/sage | 262,144 | 229,376 | 32,768 | text+image in, text out |
| vLLM (server - jzaleski/cipher) | `localhost:8080` | jzaleski/cipher | 262,144 | 229,376 | 32,768 | text in, text out |
| vLLM (server - jzaleski/sage) | `localhost:8080` | jzaleski/sage | 262,144 | 229,376 | 32,768 | text in, text out |
```

with:

```
| llama.cpp (server - jzaleski/cipher) | `server-hostname-or-ip:8080` | jzaleski/cipher | 131,072 | 114,688 | 16,384 | text+image in, text out |
| llama.cpp (server - jzaleski/sage) | `server-hostname-or-ip:8080` | jzaleski/sage | 131,072 | 114,688 | 16,384 | text+image in, text out |
| vLLM (server - jzaleski/cipher) | `localhost:8080` | jzaleski/cipher | 131,072 | 114,688 | 16,384 | text in, text out |
| vLLM (server - jzaleski/sage) | `localhost:8080` | jzaleski/sage | 131,072 | 114,688 | 16,384 | text in, text out |
```

- [ ] **Step 5: Update the Performance section context line (line ~404)**

Use the Edit tool. Replace this exact line:

```
- Context size: 81920 tokens (local), 262144 tokens (server)
```

with:

```
- Context size: 81920 tokens (local), 131072 tokens (server)
```

- [ ] **Step 6: Verify no stale server-context values remain**

Run: `grep -nE "262144|262,144|262K" README.md`
Expected: no output (exit code 1). If any line is returned, it was missed — fix it.

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs(readme): server context 131072, vLLM concurrency + prefix-caching notes"
```

---

### Task 5: AGENTS.md sync + A.3 sampling verification

**Files:**
- Modify: `AGENTS.md`

This task also performs the A.3 empirical verification. The verification is
runtime-dependent (requires the vLLM server running) and may not be possible in
the worker's environment; handle both cases explicitly below.

- [ ] **Step 1: Update the vLLM provider context values in AGENTS.md**

Use the Edit tool. Replace this exact block:

```
- **llama.cpp (server - jzaleski/cipher)**: `server-hostname-or-ip:8080`, 262K context
- **llama.cpp (server - jzaleski/sage)**: `server-hostname-or-ip:8080`, 262K context
```

with:

```
- **llama.cpp (server - jzaleski/cipher)**: `server-hostname-or-ip:8080`, 131K context
- **llama.cpp (server - jzaleski/sage)**: `server-hostname-or-ip:8080`, 131K context
```

- [ ] **Step 2: Update the Performance "Context size" line in AGENTS.md**

Use the Edit tool. Replace this exact line:

```
- Context size: 81920 tokens (local), 262144 tokens (server)
```

with:

```
- Context size: 81920 tokens (local), 131072 tokens (server)
```

- [ ] **Step 3: Add a vLLM sampling/prefix-caching subsection**

Use the Edit tool. In the `## Performance` section, replace this exact line:

```
- KV cache quantization: q4_0 (local), q8_0 (server)
```

with:

```
- KV cache quantization: q4_0 (local), q8_0 (server)
- vLLM `max-num-seqs` is capped at 16 (moderate concurrency); `enable-prefix-caching`
  is mandatorily `false` (core vLLM disables prefix caching for hybrid Qwen3.6 —
  see `vllm/config/model.py` `is_prefix_caching_supported`).
- On vLLM, `jzaleski/cipher` and `jzaleski/sage` are ONE checkpoint differentiated
  only by **client-side** per-request sampling set in `opencode.json` (`options`).
  A non-opencode client (raw curl / web UI) hitting vLLM directly gets the model's
  `generation_config.json` defaults, not the tuned cipher/sage values. (llama.cpp
  still applies its per-alias sampling server-side via the INI presets.)
```

- [ ] **Step 4: A.3 verification — attempt the live check**

First determine whether the vLLM server is reachable:

Run: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/v1/models`

- If it prints `200`: the server is up. Proceed to Step 5.
- If it prints `000` / connection refused / anything else: the server is NOT
  running in this environment. SKIP to Step 6 (document as unverified) — do NOT
  attempt to start the server yourself.

- [ ] **Step 5: A.3 verification — inspect forwarded sampling (only if server is up)**

The goal is to learn which of `top_k`, `min_p`, `presence_penalty`,
`repetition_penalty`, `temperature`, `top_p` vLLM actually receives/honors.
Issue a direct request that sets distinctive values and observe behavior, then
issue the same via opencode if possible. At minimum, confirm the server accepts
these fields without error:

Run:
```bash
curl -s http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"jzaleski/sage","messages":[{"role":"user","content":"Say hi in one word."}],"max_tokens":5,"top_k":20,"min_p":0.0,"presence_penalty":1.5,"repetition_penalty":1.0,"temperature":1.0,"top_p":0.95}' \
  -w "\nHTTP %{http_code}\n"
```
Expected: `HTTP 200` and a short completion. A 200 confirms vLLM accepts the
snake_case sampling fields in the request body (vLLM's OpenAI-compatible server
supports `top_k`, `min_p`, `repetition_penalty` as extra fields). Record the
observed HTTP status and whether any field was rejected with a 400/422.

> Note: This curl confirms the SERVER accepts the fields. Whether opencode's
> provider forwards them is a separate concern; if you cannot run opencode here,
> document that the server-acceptance is confirmed and opencode-forwarding is to
> be confirmed by the user at runtime.

- [ ] **Step 6: Record the A.3 outcome in AGENTS.md**

Use the Edit tool. Immediately AFTER the bullet block added in Step 3 (the one
ending `...via the INI presets.)`), the LAST added bullet line is:

```
  still applies its per-alias sampling server-side via the INI presets.)
```

Insert one of the following directly after it.

If Step 5 returned HTTP 200:

```
- A.3 verification (vLLM, server up): the vLLM OpenAI endpoint accepts the
  snake_case sampling fields (`top_k`, `min_p`, `presence_penalty`,
  `repetition_penalty`, `temperature`, `top_p`) in the request body (HTTP 200).
  Confirm at runtime that opencode forwards them by checking server request logs.
```

If Step 4 indicated the server was NOT reachable:

```
- A.3 verification (vLLM): NOT verified in this environment (server not running).
  The `options` keys are set per the OpenAI-style body schema; confirm at runtime
  that vLLM receives them (inspect server request logs while using opencode).
```

- [ ] **Step 7: Commit**

```bash
git add AGENTS.md
git commit -m "docs(agents): vLLM client-side sampling, prefix-caching, context updates"
```

---

## Parallel Dispatch Analysis

### Batch 1 (independent — dispatch together):
- **Task 1** (`conf/vllm-server.yaml`)
- **Task 2** (`conf/router-server.ini`)
- **Task 3** (`home/.config/opencode/opencode.json`)
- **Task 4** (`README.md`)
- **Task 5** (`AGENTS.md`)

  Rationale: Each task modifies a **distinct file** with no shared mutable state
  and no cross-file code dependencies (config-only). The values are fixed
  constants defined in this plan, not derived from another task's output, so
  there is no ordering requirement. All five can be dispatched in a single batch.

### Notes:
- Task 5's A.3 verification is runtime-dependent but self-contained (it only
  reads the server over HTTP and edits `AGENTS.md`); it does not depend on any
  other task's file changes.
- No Batch 2 needed.

---

## Self-Review

**Spec coverage:**
- A.1 (dual aliases) — already in working tree; reaffirmed/validated in Task 1 Step 5. ✓
- A.2 (vLLM client-side sampling) — Task 3 Steps 1-2. ✓
- A.3 (verification gate) — Task 5 Steps 4-6. ✓
- B.1 (vLLM max-num-seqs + max-model-len) — Task 1 Steps 2. ✓
- B.2 (llama.cpp server ctx-size; local untouched) — Task 2 (local INI deliberately not in plan). ✓
- C (docs: vllm-server.yaml comments, README, AGENTS.md) — Task 1 Steps 1&3, Task 4, Task 5. ✓
- opencode.json llama.cpp-server limit.context sync — Task 3 Steps 3-4. ✓
- Out-of-scope respected: no Task touches `conf/router-local.ini` or llama.cpp INI sampling. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N". Every edit shows exact before/after text and exact verification commands with expected output. ✓

**Type/value consistency:** Context triple is uniformly `131072 / 114688 / 16384` across Task 3 (opencode) and Task 4 (README table) and the design's stated convention. `max-num-seqs: 16`, `max-model-len: 131072`, `enable-prefix-caching: false` consistent between Task 1 and the Task 5 AGENTS.md text. Sampling values (cipher `top_k 40`/`min_p 0.01`, sage `top_k 20`/`min_p 0.0`, shared `temp 1.0`/`top_p 0.95`/`presence_penalty 1.5`/`repetition_penalty 1.0`) consistent across Task 1 comment, Task 3 options, and README sampling table (already present, unchanged). ✓
