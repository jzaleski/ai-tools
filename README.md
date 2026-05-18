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
│   ├── run-cipher                  # Cipher model (Qwen3.6-35B-A3B local and server)
│   ├── run-sage                    # Sage model (Qwen3.6-35B-A3B local and server)
│   └── run-open-webui              # Open WebUI Docker wrapper
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
├── docker-compose-files/
│   └── open-webui.yml              # Docker Compose configuration for Open WebUI
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
| `bin/install-dependencies` | Installs Homebrew (if missing) and installs/upgrades: `ag`, `btop`, `curl`, `git`, `jq`, `htop`, `llama.cpp`, `nvtop`, `ollama`, `openssl`, `readline`, `sqlite`, `wget`, `zsh` |
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
- Docker (optional; for Open WebUI)

## Tool Versions

The project tracks specific versions of key development tools in version files:

| File | Description | Default |
|------|-------------|---------|
| `.default-node-version` | Node.js version for nodenv | 24.15.0 |
| `.default-npm-version` | npm version | 11.12.1 |
| `.default-opencode-version` | opencode-ai version | 1.15.4 |

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

You can override default settings via environment variables. The same variables apply to both local and server modes. Environment defaults differ between local and server modes as shown in the Components section.

**Common Variables:**
- `MODEL_PROVIDER`: Provider/organization name for the model (default: unsloth)
- `MODEL_NAME`: Name of the model to load (no -GGUF suffix, defaults to local/server mode below)
- `MODEL_QUANTIZATION`: Full quantization specification (default: UD-Q4_K_XL for local, UD-Q8_K_XL for server)
- `HOST`: Network interface address to bind the server to (default: 127.0.0.1 for local, 0.0.0.0 for server)
- `PORT`: Network port for the server to listen on for incoming connections (default: 8081 for cipher, 8082 for sage, 8080 for WebUI)
- `ALIAS`: Custom name to register the model with llama-server (default: jzaleski/cipher or jzaleski/sage)
- `FLASH_ATTN`: Boolean flag to enable flash attention mechanism for faster processing on supported hardware (default: on)
- `N_GPU_LAYERS`: Number of layers to offload to GPU (-1 for all layers, default: -1 for local, -1 for server)
- `CTX_SIZE`: Maximum number of tokens the model can process in a single context window (default: 81920 for cipher local, 262144 for cipher server, 81920 for sage local, 262144 for sage server)
- `MIN_P`: Threshold for nucleus sampling to exclude low-probability tokens (0.0-1.0)
- `PRESENCE_PENALTY`: Factor applied to penalize repeated tokens (default: 1.5)
- `REPEAT_PENALTY`: Factor applied to penalize repeated tokens (1.0 is no penalty)
- `TEMP`: Controls randomness and creativity in model responses
- `TOP_K`: Limit on the number of most likely tokens to consider during generation (0 or 0.0 disables top-k sampling)
- `TOP_P`: Controls nucleus sampling - cumulative probability threshold for token selection (0.95 default)

## Components

### run-cipher
Runs the cipher model for coding assistance. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Model: `unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL`
- Alias: `jzaleski/cipher`
- Host: 127.0.0.1
- Port: 8081
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 81920 tokens
- Batch size: 2048
- Ubatch size: 512
- Min P: 0.01
- Presence penalty: 1.5
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 40
- Top P: 0.95

**Server Mode Defaults:**
- Model: `unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q8_K_XL`
- Alias: `jzaleski/cipher`
- Host: 0.0.0.0
- Port: 8081
- Flash attention: enabled
- GPU layers: -1
- Context size: 262144 tokens
- Batch size: 4096
- Ubatch size: 1024
- Min P: 0.01
- Presence penalty: 1.5
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 40
- Top P: 0.95

### run-sage
Runs the sage model for general advising. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Model: `unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL`
- Alias: `jzaleski/sage`
- Host: 127.0.0.1
- Port: 8082
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 81920 tokens
- Batch size: 2048
- Ubatch size: 512
- Min P: 0.0
- Presence penalty: 1.5
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 20
- Top P: 0.95

**Server Mode Defaults:**
- Model: `unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q8_K_XL`
- Alias: `jzaleski/sage`
- Host: 0.0.0.0
- Port: 8082
- Flash attention: enabled
- GPU layers: -1
- Context size: 262144 tokens
- Batch size: 4096
- Ubatch size: 1024
- Min P: 0.0
- Presence penalty: 1.5
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 20
- Top P: 0.95

### run-open-webui
Starts Open WebUI interface using Docker. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Port: 8080
- Auth: disabled
- Uses sage model on port 8082

**Server Mode Defaults:**
- Port: 8080
- Auth: enabled
- Uses sage model on port 8082

**Environment Variables:**
- `WEBUI_AUTH`: Enable authentication in WebUI (default: False for local, True for server)
- `SAGE_MODEL_PORT`: Custom sage model port (default: 8082)
- `IMAGE`: Docker image to use (default: ghcr.io/open-webui/open-webui:main)

## Usage

### Running Individual Models

```bash
# Run cipher model (local mode)
./bin/run-cipher

# Run cipher model (server mode)
./bin/run-cipher --server

# Run sage model (local mode)
./bin/run-sage

# Run sage model (server mode)
./bin/run-sage --server

# Start Open WebUI (local mode, auth disabled)
./bin/run-open-webui

# Start Open WebUI (server mode, auth enabled)
./bin/run-open-webui --server
```

## Docker Compose

Open WebUI can also be managed via Docker Compose:

```bash
docker compose -f docker-compose-files/open-webui.yml up
```

Stop with:
```bash
docker compose -f docker-compose-files/open-webui.yml down
```

## Architecture

```
┌────────────────────┐
│     Sage Model     │ (Port 8082)
│   Qwen3.6-35B-A3B  │
│  (local & server)  │
└────────────────────┘
```

```
┌────────────────────┐
│    Cipher Model    │ (Port 8081)
│  Qwen3.6-35B-A3B   │
│  (local & server)  │
└────────────────────┘
```

```
┌────────────────────┐
│     Open WebUI     │ (Port 8080)
│                    │
│    ┌──────────┐    │
│    │  Client  │    │
│    └─────┬────┘    │
└──────────┼─────────┘
           │
           ▼
┌────────────────────┐
│     Sage Model     │ (Port 8082)
│   Qwen3.6-35B-A3B  │
│   (local & server) │
└────────────────────┘
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
│  │ Local Cipher   │  │ │ Local Sage     │
│  │ localhost:8081 │  │ │ localhost:8082 │
│  │ 81K context    │  │ │ 81K context    │
│  └────────────────┘  │ └────────────────┘
│                      │
│  ┌────────────────┐  │ ┌────────────────┐
│  │ Server Cipher  │  │ │ Server Sage    │
│  │ remote:8081    │  │ │ remote:8082    │
│  │ 262K context   │  │ │ 262K context   │
│  └────────────────┘  │ └────────────────┘
└──────────────────────┘
```

### Provider Configuration

The opencode configuration (`~/.config/opencode/opencode.json`) defines 4 provider endpoints:

| Provider | Endpoint | Model | Context | Input | Output | Modalities |
|----------|----------|-------|---------|-------|--------|------------|
| llama.cpp (local - jzaleski/cipher) | `localhost:8081` | jzaleski/cipher | 81,920 | 73,728 | 8,192 | text+image in, text out |
| llama.cpp (local - jzaleski/sage) | `localhost:8082` | jzaleski/sage | 81,920 | 73,728 | 8,192 | text+image in, text out |
| llama.cpp (server - jzaleski/cipher) | `server-hostname-or-ip:8081` | jzaleski/cipher | 262,144 | 229,376 | 32,768 | text+image in, text out |
| llama.cpp (server - jzaleski/sage) | `server-hostname-or-ip:8082` | jzaleski/sage | 262,144 | 229,376 | 32,768 | text+image in, text out |

**Note:** All providers support image input via the opencode provider configuration.

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
- Context size standardized to 81920 tokens for sage and cipher local, 262144 tokens for both servers
- For coding tasks, use run-cipher:
  - Local: Qwen3.6-35B-A3B (efficient local coding)
  - Server: Qwen3.6-35B-A3B (powerful server-side coding)
- For general advising, use run-sage:
  - Local: Qwen3.6-35B-A3B (efficient local reasoning)
  - Server: Qwen3.6-35B-A3B (powerful server-side reasoning)

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

**WebUI connection issues:**
- Verify sage model is running on configured port
- Check firewall settings
- Ensure Docker can reach host.docker.internal

**Quality issues:**
- Adjust `MIN_P` and `TOP_K` values based on desired response style (0 or 0.0 disables these sampling methods)
- For more creative responses, increase `TEMP` and `TOP_P`

**Memory issues:**
- Reduce `CTX_SIZE` for smaller context windows
- Use lower quantization (recommend Q4 as the minimum to balance accuracy and speed)
