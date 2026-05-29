# AI Tools

Utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. It includes support for coding assistance (Qwen3.6-35B-A3B local and server) and general advising (Qwen3.6-35B-A3B local and server).

Models are loaded from HuggingFace and quantized for efficient local inference.

## Project Structure

```
.
├── bin/                            # Main execution scripts
│   ├── bootstrap                   # System setup and configuration bootstrap
│   ├── install-dependencies        # Installs/upgrades Homebrew base packages
│   ├── configure-node              # Clones/updates nodenv, installs Node.js and npm
│   ├── configure-opencode          # Installs opencode-ai and configures shell init
│   ├── configure-vllm              # Installs vllm-metal; symlinks venv to ~/.venvs/vllm
│   └── run-router                  # Router server (llama.cpp or vLLM via --experimental)
├── conf/                           # llama-server INI presets + vLLM YAML config
│   ├── router-local.ini            # Router preset: local profile (Q4, q4_0 KV, 81K ctx, 127.0.0.1)
│   ├── router-server.ini           # Router preset: server profile (Q8, q8_0 KV, 262K ctx, 0.0.0.0)
│   └── vllm-server.yaml            # vLLM server config (vllm serve --config)
├── home/                           # Dotfiles and config files to symlink
│   ├── .config/opencode/           # Opencode configuration and agent definitions
│   │   ├── agents/
│   │   │   ├── analyze.md          # Data analyst agent
│   │   │   └── engineer.md         # Adaptive software engineer (default)
│   │   ├── skills/                 # Vendored workflow skills (no external plugins)
│   │   │   ├── coder/              # Sub-agent implementer (TDD, self-review)
│   │   │   ├── finisher/           # Verify, merge/PR, cleanup
│   │   │   ├── planner/            # Task decomposition + independence analysis
│   │   │   ├── researcher/         # Design & discovery (approval-gated)
│   │   │   └── reviewer/           # Spec compliance + code quality review
│   │   └── opencode.json           # Opencode provider and agent configuration
│   ├── .local/lib/
│   │   └── opencode.sh             # Opencode wrapper script (session persistence, cache reset)
│   └── .opencoderc                 # Shell alias: opencode → ~/.local/lib/opencode.sh
├── .default-node-version           # Default node version
├── .default-npm-version            # Default npm version
├── .default-opencode-version       # Default opencode-ai version
├── .default-python-version         # Default Python version (vllm-metal venv)
└── .default-vllm-metal-version     # Default vllm-metal release tag (reference)
```

## Bootstrap System

The project includes a bootstrap system for setting up your development environment:

```bash
# Run bootstrap (will prompt before overwriting)
bin/bootstrap

# Run bootstrap non-interactively (overwrite without prompt)
ASSUME_YES=true bin/bootstrap
```

The bootstrap script:
- Initializes and updates git submodules if present (none currently)
- Copies files from `home/` to your `$HOME` directory
- Runs an explicit ordered array of scripts from `bin/`

### Bootstrap Scripts

Scripts run in the order defined in the `bin_scripts` array in `bin/bootstrap`:

| Script | Purpose |
|--------|---------|
| `bin/install-dependencies` | Installs Homebrew (if missing) and installs/upgrades: `ag`, `btop`, `curl`, `git`, `jq`, `htop`, `llama.cpp`, `nvtop`, `ollama`, `openssl`, `readline`, `sqlite`, `wget`, `zsh` |
| `bin/configure-node` | Clones/updates `nodenv` to `~/.nodenv` and the `node-build` plugin; installs Node.js (from `.default-node-version`) and npm (from `.default-npm-version`) |
| `bin/configure-opencode` | Installs `opencode-ai` version from `.default-opencode-version` via npm; appends `.opencoderc` sourcing to `~/.bashrc` and `~/.zshrc` |
| `bin/configure-vllm` | Installs vllm-metal via the official install script (`~/.venv-vllm-metal/`) and symlinks it to `~/.venvs/vllm` (native arm64 Python 3.12.x) |

To run only a subset of scripts, use `BOOTSTRAP_SCRIPTS`:
```bash
BOOTSTRAP_SCRIPTS="configure-node,configure-opencode" bin/bootstrap
```
To skip specific scripts, use `BOOTSTRAP_SKIP`:
```bash
BOOTSTRAP_SKIP="install-dependencies" bin/bootstrap
```

## Prerequisites

- At least 16GB RAM for 20B+ models
- GPU support (recommended)

## Tool Versions

The project tracks specific versions of key development tools in version files:

| File | Description | Default |
|------|-------------|---------|
| `.default-node-version` | Node.js version for nodenv | 24.15.0 |
| `.default-npm-version` | npm version | 11.12.1 |
| `.default-opencode-version` | opencode-ai version | 1.15.12 |
| `.default-python-version` | Python version for the vllm-metal venv | 3.12.12 |
| `.default-vllm-metal-version` | vllm-metal release tag (reference) | v0.2.0-20260528-103004 |

These versions are managed and installed via the bootstrap system.

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **analyze.md**: Data pipeline orchestrator — coordinates composable ingest workers for parallel multi-format data extraction, normalization, analysis, and reporting
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `engineer`.

### Local Skills

Workflow skills are vendored locally under `home/.config/opencode/skills/` — no external plugin dependencies:

| Skill | Purpose |
|-------|---------|
| `researcher` | Design & discovery — clarifying questions, approach proposals, spec writing with user approval gate |
| `planner` | Task decomposition with exact file paths, code, commands, and parallel-dispatch independence analysis |
| `coder` | Sub-agent implementer — TDD, self-review, structured status reporting |
| `reviewer` | Dual-mode review — spec compliance (did they build what was asked?) then code quality |
| `finisher` | Verify tests, detect workspace state, present merge/PR options, execute with cleanup |

## Environment Variables

You can override default settings via environment variables. The same variables apply to both local and server modes.

**Common Variables:**
- `HOST`: Network interface address to bind the server to (default: 127.0.0.1 for local, 0.0.0.0 for server)
- `PORT`: Network port for the server to listen on (default: 8080)

**vLLM Backend Variables** (apply with `--experimental`):
- `VLLM_METAL_MEMORY_FRACTION`: Memory tuning for the Metal backend (default: `auto`); use instead of `--gpu-memory-utilization`
- `VLLM_VENV`: Override the vLLM virtual environment path (default: `~/.venvs/vllm`)

## Components

### run-router
Starts a single llama-server in [router mode](https://github.com/ggml-org/llama.cpp/blob/master/docs/preset.md), loading all models defined in the appropriate INI preset file. Clients route to a specific model via `?model=jzaleski/cipher` or `?model=jzaleski/sage`. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Preset: `conf/router-local.ini`
- Host: 127.0.0.1
- Port: 8080
- Quantization: UD-Q4_K_XL (both models)
- KV cache quantization: q4_0 (K and V)
- Context size: 81920 tokens
- Batch size: 2048 / Ubatch size: 512

**Server Mode Defaults:**
- Preset: `conf/router-server.ini`
- Host: 0.0.0.0
- Port: 8080
- Quantization: UD-Q8_K_XL (both models)
- KV cache quantization: q8_0 (K and V)
- Context size: 262144 tokens
- Batch size: 4096 / Ubatch size: 1024

**Environment Variables:**
- `HOST`: Override bind address
- `PORT`: Override listen port (default: 8080)

## Usage

```bash
# Start router (llama.cpp, local mode — both models on localhost:8080)
./bin/run-router

# Start router (llama.cpp, server mode — both models on 0.0.0.0:8080)
./bin/run-router --server

# Start router (vLLM, local mode — STUB, exits non-zero: "vLLM local mode not yet supported — use --server")
./bin/run-router --experimental

# Start router (vLLM, server mode — single model on 0.0.0.0:8080)
./bin/run-router --server --experimental
```

The `--server` and `--experimental` flags are order-independent. The `--experimental` flag selects the vLLM backend instead of llama.cpp; see [vLLM Backend](#vllm-backend) below.

Clients select a model via the `model` query parameter or request body field:

```bash
curl http://localhost:8080/v1/chat/completions?model=jzaleski/cipher ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/sage   ...
```

## Architecture

The router listens on port 8080. The backend is selected at launch time via the
`--experimental` flag: llama.cpp (default) **or** vLLM. Only one backend runs at
a time — vLLM is a drop-in replacement on the same port. Opencode's 6 provider
endpoints (4 llama.cpp + 2 vLLM) connect to whichever backend is currently
serving on port 8080.

```
                  ┌─────────────────────────┐
                  │   ./bin/run-router       │
                  │   [--experimental?]      │
                  └────────────┬────────────┘
                  default      │      --experimental
              ┌────────────────┴────────────────┐
              ▼                                  ▼
┌──────────────────────────┐      ┌──────────────────────────┐
│   llama.cpp (router)     │      │   vLLM (vllm serve)      │
│   Port 8080              │      │   Port 8080              │
│   --models-preset        │      │   --config vllm-server   │
│                          │      │                          │
│  ┌────────┐ ┌────────┐   │      │  ┌────────────────────┐  │
│  │cipher  │ │sage    │   │      │  │Qwen3.6-35B-A3B-FP8 │  │
│  │(Qwen)  │ │(Qwen)  │   │      │  │(single model)      │  │
│  └────────┘ └────────┘   │      │  └────────────────────┘  │
└────────────┬─────────────┘      └────────────┬─────────────┘
             └───────────── OR ─────────────────┘
                            │
                            ▼  (port 8080)
              ┌─────────────────────────────┐
              │   Opencode — 6 providers    │
              │   4 llama.cpp + 2 vLLM      │
              └─────────────────────────────┘
```

## vLLM Backend

The `--experimental` flag swaps the llama.cpp router for a [vLLM](https://github.com/vllm-project/vllm)
server on the same port (8080). It is a **drop-in replacement** — run only one
backend at a time (llama.cpp **or** vLLM). Local mode (`--experimental` without
`--server`) is currently a stub and exits non-zero with the message
`vLLM local mode not yet supported — use --server`; use `--server --experimental`
to run vLLM.

**Install:**
- Installed via `bin/configure-vllm`, which runs the official vllm-metal
  `install.sh` script.
- The installer creates a bundled venv at `~/.venv-vllm-metal/`; `configure-vllm`
  then exposes it under the canonical path `~/.venvs/vllm` via a symlink.
- A native arm64 Python 3.12.x is required.

**Configuration:**
- Config lives in `conf/vllm-server.yaml`, using the native `vllm serve --config`
  YAML format. Keys are the long-form CLI flags. The `host`/`port` values passed
  by `run-router` take precedence over anything in the YAML file.
- Model: `Qwen/Qwen3.6-35B-A3B-FP8`.
- vllm-metal is **text-only** (no vision support).
- Qwen3.6 runs with prefix caching **disabled** on Metal.

**Environment Variables:**
- `VLLM_METAL_MEMORY_FRACTION` — Memory tuning for the Metal backend (default:
  `auto`). Use this instead of `--gpu-memory-utilization`.
- `VLLM_VENV` — Override the virtual environment path (default:
  `~/.venvs/vllm`).

**Known Issues:**
- At startup vLLM logs a benign warning:
  `Found ulimit of 2048 and failed to automatically increase ... current limit
  exceeds maximum limit`. This is a `vllm-metal` limitation: its plugin
  registration lowers `RLIMIT_NOFILE` to `(2048, 4096)` in native code, *after*
  any shell `ulimit` raise, so it cannot be fixed from `run-router` or the
  launching shell. It is cosmetic for normal single-user / comparison workloads
  (the actual "Too many open files" risk only arises under very high concurrent
  connection counts). A real fix requires an upstream `vllm-metal` change.

### Sampling Profiles

Under vLLM the server serves a single model; `jzaleski/cipher` and
`jzaleski/sage` become **per-request, client-side sampling profiles**:

| Profile | min_p | top_k | temperature | top_p | presence_penalty | repetition_penalty |
|---------|-------|-------|-------------|-------|------------------|--------------------|
| jzaleski/cipher | 0.01 | 40 | 1.0 | 0.95 | 1.5 | 1.0 |
| jzaleski/sage | 0.0 | 20 | 1.0 | 0.95 | 1.5 | 1.0 |

## Opencode Agent Architecture

The opencode system provides a multi-agent workflow with role-specific capabilities:

```
┌──────────────────────┐
│    Opencode CLI      │
│                      │
│  ┌────────────────┐  │
│  │ Engineer       │◄─┼── default agent
│  │ [adaptive:     │  │
│  │  triage →      │  │
│  │  direct /      │  │
│  │  dispatch /    │  │
│  │  lifecycle]    │  │
│  └────────────────┘  │
│                      │
│  ┌────────────────┐  │
│  │ Analyze        │  │
│  │ [data/report]  │  │
│  └────────────────┘  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│    LLM Providers     │
│                      │
│  ┌────────────────┐  │ ┌────────────────┐
│  │ Local Cipher   │  │ │ Local Sage     │
│  │ localhost:8080 │  │ │ localhost:8080 │
│  │ 81K context    │  │ │ 81K context    │
│  └────────────────┘  │ └────────────────┘
│                      │
│  ┌────────────────┐  │ ┌────────────────┐
│  │ Server Cipher  │  │ │ Server Sage    │
│  │ remote:8080    │  │ │ remote:8080    │
│  │ 262K context   │  │ │ 262K context   │
│  └────────────────┘  │ └────────────────┘
└──────────────────────┘
```

### Provider Configuration

The opencode configuration (`~/.config/opencode/opencode.json`) defines 6 provider endpoints (4 llama.cpp + 2 vLLM):

| Provider | Endpoint | Model | Context | Input | Output | Modalities |
|----------|----------|-------|---------|-------|--------|------------|
| llama.cpp (local - jzaleski/cipher) | `localhost:8080` | jzaleski/cipher | 81,920 | 73,728 | 8,192 | text+image in, text out |
| llama.cpp (local - jzaleski/sage) | `localhost:8080` | jzaleski/sage | 81,920 | 73,728 | 8,192 | text+image in, text out |
| llama.cpp (server - jzaleski/cipher) | `server-hostname-or-ip:8080` | jzaleski/cipher | 262,144 | 229,376 | 32,768 | text+image in, text out |
| llama.cpp (server - jzaleski/sage) | `server-hostname-or-ip:8080` | jzaleski/sage | 262,144 | 229,376 | 32,768 | text+image in, text out |
| vLLM (server - jzaleski/cipher) | `localhost:8080` | jzaleski/cipher | 262,144 | 229,376 | 32,768 | text in, text out |
| vLLM (server - jzaleski/sage) | `localhost:8080` | jzaleski/sage | 262,144 | 229,376 | 32,768 | text in, text out |

**Note:** The 4 llama.cpp providers support image input via the opencode provider configuration. The 2 vLLM providers are **text-only** (vllm-metal has no vision support) and point at `localhost:8080`.

### Agent Roles

| Agent | Mode | Capabilities | Output Style |
|-------|------|--------------|--------------|
| engineer | primary (default) | Adaptive scope triage — handles trivial changes directly (Path A), dispatches parallel coders for multi-file work (Path B), or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger/ambiguous features (Path C) | Path A/B: working tree (may commit if clearly safe on Path A); Path C: feature branch with commits/PR |
| analyze | primary | Data pipeline orchestration — parallel ingestion of multi-format inputs, normalization, analysis, report generation | Report in user-specified format |

### Disabled Built-in Agents

The `build` and `plan` agents that ship with opencode are disabled in `opencode.json` — only the two custom agents above are active.

### Plugins

None. All workflow skills are vendored locally under `home/.config/opencode/skills/`. This architecture has zero external plugin dependencies — if any third-party project disappears tomorrow, the agents continue working identically.

### MCP Integrations

The following MCP integrations are configured but **disabled by default**:

| Integration | URL | Notes |
|-------------|-----|-------|
| Jira | `https://mcp.atlassian.com/v1/mcp` | Enable in `opencode.json` to use |
| Vercel | `https://mcp.vercel.com/v1/mcp` | Enable in `opencode.json` to use |

### Usage

```bash
# Run opencode with default agent (engineer)
opencode "your question or task"

# Specify a different agent
opencode --agent engineer "implement this feature"
opencode --agent analyze "analyze this data file"
```

### Opencode Wrapper Script

The project includes `home/.local/lib/opencode.sh`, a wrapper script for the opencode CLI that manages model history, cache state, and session persistence. It is aliased to the `opencode` command via `home/.opencoderc`, which is sourced from `~/.bashrc` and `~/.zshrc` by the bootstrap system.

```bash
# Via alias after bootstrap
opencode [options] [query]

# Direct invocation
~/.local/lib/opencode.sh [options] [query]
```

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

### Configuration Notes

- `autoupdate`: disabled (manual updates only)
- `default_agent`: `engineer` (full tool access for general work)
- Server providers use `server-hostname-or-ip` placeholder - replace with actual hostname/IP
- Input/output token limits set to optimize for local inference constraints

## Performance Tips

- GPU acceleration enabled with flash attention by default
- Use Q4 quantization for memory-constrained environments
- KV cache is quantized to reduce memory footprint: q4_0 (local), q8_0 (server)
- Context size: 81920 tokens (local), 262144 tokens (server)

## Troubleshooting

**Bootstrap issues:**
- Run with `ASSUME_YES=true` for non-interactive mode

**Model not loading:**
- Ensure you have enough RAM
- Verify model name and quantization

**Slow inference:**
- Enable flash attention
- Reduce context size
- Adjust quantization level

**Quality issues:**
- Adjust `MIN_P` and `TOP_K` values based on desired response style (0 or 0.0 disables these sampling methods)
- For more creative responses, increase `TEMP` and `TOP_P`

**Memory issues:**
- Reduce `CTX_SIZE` for smaller context windows
- Use lower quantization (recommend Q4 as the minimum to balance accuracy and speed)
