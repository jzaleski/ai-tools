# AI Tools

Utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. It includes support for coding assistance (Qwen3.6-35B-A3B local and server) and general advising (Qwen3.6-35B-A3B local and server). Experimental profiles swap in the Qwopus3.6-35B-A3B-v1 model with tuned sampling parameters.

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
│   ├── run-local                   # Direct llama-server launcher (local mode, no router)
│   ├── run-router                  # Router server (llama.cpp, local and server modes)
│   └── run-server                  # Direct llama-server launcher (server mode, no router)
├── conf/                           # llama-server INI presets
│   ├── llama-cpp-local.ini         # Router preset: local profile (Q4, q4_0 KV, 81K ctx, 127.0.0.1)
│   ├── llama-cpp-local-experimental.ini   # Router preset: local experimental profile (Q4_K_M, 81K ctx)
│   ├── llama-cpp-server.ini        # Router preset: server profile (Q8, q8_0 KV, 262K ctx, 0.0.0.0)
│   └── llama-cpp-server-experimental.ini  # Router preset: server experimental profile (Q8_0, 262K ctx)
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

You can override default settings via environment variables. The same variables apply to both local and server modes.

**Common Variables:**
- `HOST`: Network interface address to bind the server to (default: 127.0.0.1 for local, 0.0.0.0 for server)
- `PORT`: Network port for the server to listen on (default: 8080)

## Components

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

## Usage

```bash
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

Clients select a model via the `model` query parameter or request body field:

```bash
curl http://localhost:8080/v1/chat/completions?model=jzaleski/local  ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/server ...
```

## Architecture

The router listens on port 8080 and is selected at launch time via flags. Alternatively, `run-local` and `run-server` bypass the router and start llama-server directly.

```
┌──────────────────────────┐   ┌──────────────┐   ┌───────────────┐
│   ./bin/run-router        │   │ ./bin/run-   │   │ ./bin/run-    │
│   (router mode)           │   │ local        │   │ server        │
└────────────┬──────────────┘   └──────┬───────┘   └───────┬───────┘
             │                         │                   │
   ┌──────────┴──────────┐    ┌────────┴────────┐  ┌───────┴────────┐
   │  llama.cpp (router) │    │  llama.cpp      │  │  llama.cpp     │
   │  Port 8080          │    │  127.0.0.1:8080 │  │  0.0.0.0:8080  │
   │  --models-preset    │    │  (direct)       │  │  (direct)      │
   │                     │    └─────────────────┘  └────────────────┘
   │ ┌──────────────────┐ │
   │ │jzaleski/local    │ │
   │ │(or /server)      │ │
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
│  │ 81K context    │  │ │ 262K context   │
│  └────────────────┘  │ └────────────────┘
└──────────────────────┘
```

### Provider Configuration

The opencode configuration (`~/.config/opencode/opencode.json`) defines 2 provider endpoints:

| Provider | Endpoint | Model | Context | Input | Output | Modalities |
|----------|----------|-------|---------|-------|--------|------------|
| llama.cpp (local) | `localhost:8080` | jzaleski/local | 81,920 | 73,728 | 8,192 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/server | 262,144 | 245,760 | 16,384 | text+image in, text out |

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
