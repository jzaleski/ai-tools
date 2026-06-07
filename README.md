# AI Tools

Utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. It supports four model tiers — low (Qwen3.6-35B-A3B Q4_K_XL, 32K ctx), medium (Qwen3.6-35B-A3B Q6_K_XL, 64K ctx), high (Qwen3.6-27B Q8_K_XL, 128K ctx), and long (Qwen3.6-35B-A3B Q4_K_XL, 256K ctx for long agent sessions). The tier axis runs from speed (low) to quality (high) within the Qwen3.6 family; `long` is a large-context sibling of `low`. Bind address is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN). Tiers are stable; the models behind them can rotate without changing client-facing aliases.

Models are loaded from HuggingFace and quantized for efficient local inference.

## Project Structure

```
.
├── bin/                            # Main execution scripts
│   ├── bootstrap                   # System setup and configuration bootstrap
│   ├── install-dependencies        # Installs/upgrades Homebrew base packages
│   ├── configure-git               # Configures global git settings (core.excludesfile)
│   ├── configure-node              # Clones/updates nodenv, installs Node.js and npm
│   ├── configure-opencode          # Installs opencode-ai and configures shell init
│   ├── download-model              # Downloads a single GGUF file from Hugging Face via curl
│   ├── run-model                   # Direct llama-server launcher (single model, --tier low|medium|high|long)
│   └── run-router                  # Router server (llama.cpp, multi-model; HOST env toggles bind)
├── templates/                      # llama-server INI preset templates
│   └── llama-cpp.ini.template      # Router preset (low: 32K, medium: 64K, high: 128K, long: 256K ctx)
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
└── .default-opencode-version       # Default opencode-ai version
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
| `bin/install-dependencies` | Installs Homebrew (if missing) and installs/upgrades: `ag`, `btop`, `curl`, `git`, `jq`, `htop`, `llama.cpp`, `nvtop`, `openssl`, `readline`, `sqlite`, `wget`, `zsh` |
| `bin/configure-git` | Configures global git settings — sets `core.excludesfile` to `~/.gitignore` if not already set |
| `bin/configure-node` | Clones/updates `nodenv` to `~/.nodenv` and the `node-build` plugin; installs Node.js (from `.default-node-version`) and npm (from `.default-npm-version`) |
| `bin/configure-opencode` | Installs `opencode-ai` version from `.default-opencode-version` via npm; appends `.opencoderc` sourcing to `~/.bashrc` and `~/.zshrc` |

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
| `.default-opencode-version` | opencode-ai version | 1.15.13 |

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

You can override default settings via environment variables.

**Common Variables:**
- `HOST`: Network interface address to bind the server to (default: `127.0.0.1`; set `0.0.0.0` to expose on the LAN)
- `PORT`: Network port for the server to listen on (default: 8080)

## Components

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

## Usage

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

Clients select a model via the `model` query parameter or request body field:

```bash
curl http://localhost:8080/v1/chat/completions?model=jzaleski/low    ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/medium ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/high   ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/long   ...
```

## Architecture

The router listens on port 8080 and serves all four tiers. Alternatively, `run-model` bypasses the router and starts a single llama-server directly. Both bind to `127.0.0.1` unless `HOST=0.0.0.0` is set.

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
│  │ Local          │  │ │ Server         │
│  │ localhost:8080 │  │ │ remote:8080    │
│  │ per-tier ctx   │  │ │ per-tier ctx   │
│  └────────────────┘  │ └────────────────┘
└──────────────────────┘
```

### Provider Configuration

The opencode configuration (`~/.config/opencode/opencode.json`) defines 2 provider endpoints:

Both providers expose the same four tiers with identical per-tier limits; they
differ only in endpoint (the server provider is the same models reached by
launching with `HOST=0.0.0.0`).

| Provider | Endpoint | Model | Context | Input | Output | Modalities |
|----------|----------|-------|---------|-------|--------|------------|
| llama.cpp (local) | `localhost:8080` | jzaleski/low | 32,768 | 28,672 | 4,096 | text+image in, text out |
| llama.cpp (local) | `localhost:8080` | jzaleski/medium | 65,536 | 57,344 | 8,192 | text+image in, text out |
| llama.cpp (local) | `localhost:8080` | jzaleski/high | 131,072 | 114,688 | 16,384 | text in, text out |
| llama.cpp (local) | `localhost:8080` | jzaleski/long | 262,144 | 229,376 | 32,768 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/low | 32,768 | 28,672 | 4,096 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/medium | 65,536 | 57,344 | 8,192 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/high | 131,072 | 114,688 | 16,384 | text in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/long | 262,144 | 229,376 | 32,768 | text+image in, text out |

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

| Integration | Type | Command / URL | Notes |
|-------------|------|---------------|-------|
| Jira | remote | `https://mcp.atlassian.com/v1/mcp` | Enable in `opencode.json` to use |
| Playwright | local | `npx @playwright/mcp@latest` | Enable in `opencode.json` to use |
| Vercel | remote | `https://mcp.vercel.com/v1/mcp` | Enable in `opencode.json` to use |

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
- KV cache quantization is tier-specific: low=q4_0, medium=q4_0, high=q8_0, long=q4_0
- Context size is tier-specific: low=32K, medium=64K, high=128K, long=256K
- Batch/ubatch scales inversely with context for steady latency on Apple Silicon: low & medium=2048/512, high & long=1024/256
- Sampling defaults are tuned for coding and tool-calling: `temp=0.7`, `top-k=0` (disabled), `top-p=0.95`, `min-p=0.02`, `presence-penalty=0.2`

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
- Sampling defaults are tuned for coding/tool-calling: `temp=0.7`, `top-k=0` (disabled), `top-p=0.95`, `min-p=0.02`, `presence-penalty=0.2`
- For more creative/diverse responses, increase `temp` and `top-p`, or raise `presence-penalty`
- For more deterministic output, lower `temp` (e.g. `0.4–0.6`)

**Memory issues:**
- Reduce `CTX_SIZE` for smaller context windows
- Use lower quantization (recommend Q4 as the minimum to balance accuracy and speed)
