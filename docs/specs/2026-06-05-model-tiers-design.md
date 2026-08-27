# Design: Model Tiers (low / medium / high)

**Date:** 2026-06-05
**Status:** Approved

---

## Overview

Replace the current `jzaleski/local` + `jzaleski/server` + `--experimental` model naming scheme with three purpose-oriented, deployment-agnostic tiers: `jzaleski/low`, `jzaleski/medium`, and `jzaleski/high`. Tier names are stable over time — the models behind them can rotate without any alias changes on the client side.

The `--experimental` flag and its associated templates and script functions are removed entirely. Experimental models can be added as a named section in either INI template (`[jzaleski/experimental]`) when needed.

---

## Tier Definitions

| Tier | Alias | Purpose |
|---|---|---|
| low | `jzaleski/low` | Fast, lightweight — short tasks, quick iteration |
| medium | `jzaleski/medium` | Balanced — general-purpose daily use |
| high | `jzaleski/high` | Most capable — complex reasoning, long context |

---

## Model Assignments

| Tier | HF Repo | Local quant | Server quant |
|---|---|---|---|
| low | `unsloth/gemma-4-12b-it-GGUF` | `UD-Q4_K_XL` | `UD-Q8_K_XL` |
| medium | `unsloth/Qwen3.6-27B-GGUF` | `UD-Q4_K_XL` | `UD-Q8_K_XL` |
| high | `unsloth/MiniMax-M2.7-GGUF` | `UD-Q4_K_XL` | `UD-Q8_K_XL` |

Model files are downloaded automatically by `run-local` / `run-server` via `require_model` if not present.

---

## Context & Batch Sizes

| Mode | Context | Batch | Ubatch | KV cache |
|---|---|---|---|---|
| local | 131072 (128×1024) | 2048 | 512 | q4_0 |
| server | 262144 (256×1024) | 4096 | 1024 | q8_0 |

These apply uniformly across all three tiers within each mode.

---

## Changes by File

### `templates/llama-cpp-local.ini.template`

Replace the single `[jzaleski/local]` section with three tier sections. Update `ctx-size` to 131072. Remove experimental template file.

```ini
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

### `templates/llama-cpp-server.ini.template`

Same structure, server quants and context size. Remove experimental template file.

```ini
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

### `templates/llama-cpp-local-experimental.ini.template` and `templates/llama-cpp-server-experimental.ini.template`

Deleted.

### `bin/run-router`

- Remove `run_local_experimental` and `run_server_experimental` functions
- Remove `--experimental` flag parsing and dispatch branch
- Update `TEMPLATES_DIR` references (already correct from prior rename)
- No other changes needed — `render_preset` is generic and works unchanged

### `bin/run-local`

Replace `run_local` / `run_local_experimental` / `--experimental` dispatch with three functions `run_low`, `run_medium`, `run_high`, dispatched via a `--tier` flag (default: `medium`). Each function:
- Calls `require_model` with the correct file path and HF repo
- Passes `--alias jzaleski/<tier>` so the model is addressable under its tier name
- Uses local context (131072) and batch sizes

### `bin/run-server`

Same restructure as `run-local` but with server host, context (262144), batch sizes, and `UD-Q8_K_XL` quants.

### `home/.config/opencode/opencode.json`

- Rename `jzaleski/local` → `jzaleski/medium` in the local provider; update context limit to 131072, input to 122880, output to 8192
- Rename `jzaleski/server` → `jzaleski/medium` in the server provider; context stays 262144
- Add `jzaleski/low` and `jzaleski/high` model entries to both providers with appropriate limits:

| Tier | Context | Input | Output |
|---|---|---|---|
| low | 131072 | 122880 | 8192 |
| medium | 131072 | 122880 | 8192 |
| high | 131072 | 122880 | 8192 |

Server variants use context 262144, input 245760, output 16384 for all three tiers.

### `AGENTS.md`

Update model descriptions to reflect new tiers, remove references to experimental profiles, update context sizes.

### `README.md`

Update `conf/` → `templates/`, update model tables, aliases, context sizes, remove experimental references, update usage examples.

---

## Flag Design for `run-local` / `run-server`

```bash
./bin/run-local              # defaults to medium
./bin/run-local --tier low
./bin/run-local --tier medium
./bin/run-local --tier high

./bin/run-server             # defaults to medium
./bin/run-server --tier low
./bin/run-server --tier medium
./bin/run-server --tier high
```

The `run-router` scripts do not need a `--tier` flag — all three tiers are defined in the single INI template and the client selects via `?model=jzaleski/<tier>`.

---

## What is Removed

- `templates/llama-cpp-local-experimental.ini.template`
- `templates/llama-cpp-server-experimental.ini.template`
- `--experimental` flag from `run-local`, `run-server`, `run-router`
- `run_local_experimental`, `run_server_experimental`, `run_local`, `run_server` functions (replaced by `run_low`, `run_medium`, `run_high` in each script)

---

## What is NOT Changed

- `render_preset` logic in `run-router` — works as-is
- `require_model` logic in `run-local` / `run-server` — works as-is
- `tmp/` directory and rendered INI output pattern
- All MCP, plugin, and agent configuration in `opencode.json`
- Sampling parameters (`presence-penalty`, `temp`, `top-k`, etc.) — unchanged
