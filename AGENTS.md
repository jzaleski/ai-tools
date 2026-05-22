# AGENTS.md

Guidelines for agentic coding tools in this repository.

## Project Overview

Shell scripts for running local LLMs using `llama-server`.
Supports coding assistance (Qwen3.6-35B-A3B local and server) and general advising (Qwen3.6-35B-A3B local and server).

**No code repositories** - utilities/config only.

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **analyze.md**: Data pipeline orchestrator — coordinates composable ingest workers for parallel multi-format data extraction, normalization, analysis, and reporting
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features

Workflow skills are vendored locally under `home/.config/opencode/skills/` (researcher, planner, coder, reviewer, finisher). No external plugin dependencies.

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `engineer`.

---

## Project Structure

```
.
├── bin/                                   # Main execution scripts
│   ├── bootstrap                          # System setup and configuration bootstrap
│   ├── install-dependencies               # Installs/upgrades Homebrew base packages
│   ├── configure-node                     # Clones/updates nodenv, installs Node.js and npm
│   ├── configure-opencode                 # Installs opencode-ai and configures shell init
│   ├── run-cipher                         # Cipher model (Qwen3.6-35B-A3B local and server)
│   └── run-sage                           # Sage model (Qwen3.6-35B-A3B local and server)
├── home/                                  # Dotfiles and config files to symlink
│   ├── .config/opencode/
│   │   ├── agents/                        # Agent definitions (analyze, engineer)
│   │   ├── skills/                        # Vendored workflow skills (coder, finisher, planner, researcher, reviewer)
│   │   └── opencode.json                  # Provider, agent, MCP configuration
│   ├── .local/lib/opencode.sh             # Opencode wrapper (session persistence, cache reset)
│   └── .opencoderc                        # Shell alias: opencode → ~/.local/lib/opencode.sh
```

---

## Build/Test Commands

Scripts in `bin/` support **local** and **server** modes:

```bash
./bin/run-cipher                           # Local mode
./bin/run-cipher --server                  # Server mode
./bin/run-sage                             # Local mode
./bin/run-sage --server                    # Server mode
```

Test with: `bash -x ./bin/run-cipher` or `bash -x ./bin/run-sage`

---

## Code Style Guidelines

### Bash Scripts

- **Shebang**: `#!/usr/bin/env bash`
- **Functions**: Use `run_local()` and `run_server()`
- **Mode Detection**: `if [[ "${1:-}" == "--server" ]]; then run_server; else run_local; fi`
- **Variable Quoting**: Always quote expansions `"${VAR:-default}"`
- **Path Resolution**: Use `$(dirname $0)/..` for relative paths

### Configuration Files

- Environment Variables: Use `${VAR:-default}` syntax

### Documentation

- Keep `README.md` updated
- Document all environment variables with defaults
- Include usage examples and ASCII diagrams

### Naming Conventions

- Scripts: `run-{component}.sh`
- Modes: `local` / `server`
- Ports: 8081 (cipher), 8082 (sage)
- Aliases: `jzaleski/{component}`

---

## Environment Variables

| Variable | Description | Default (Local) | Default (Server) |
|----------|-------------|-----------------|------------------|
| `MODEL_PROVIDER` | HuggingFace org | `unsloth` | `unsloth` |
| `MODEL_NAME` | Model name (no -GGUF) | `Qwen3.6-35B-A3B` (cipher), `Qwen3.6-35B-A3B` (sage) | `Qwen3.6-35B-A3B` (cipher), `Qwen3.6-35B-A3B` (sage) |
| `MODEL_QUANTIZATION` | Quantization level | `UD-Q4_K_XL` (cipher), `UD-Q4_K_XL` (sage) | `UD-Q8_K_XL` (cipher), `UD-Q8_K_XL` (sage) |
| `TEMP` | Sampling temperature | `1.0` (cipher), `1.0` (sage) | `1.0` (cipher), `1.0` (sage) |
| `PORT` | Network port | `8081` (cipher), `8082` (sage) | `8081` (cipher), `8082` (sage) |
| `CTX_SIZE` | Context window (tokens) | `81920` (cipher), `81920` (sage) | `262144` (cipher), `262144` (sage) |
| `MIN_P` | Nucleus min (0.0 disables) | `0.01` (cipher), `0.0` (sage) | `0.01` (cipher), `0.0` (sage) |
| `TOP_K` | Top-K limit (0 or 0.0 disables) | `40` (cipher), `20` (sage) | `40` (cipher), `20` (sage) |
| `REPEAT_PENALTY` | Repeat penalty (1.0 = no penalty) | `1.0` | `1.0` |
| `PRESENCE_PENALTY` | Presence penalty | `1.5` (cipher), `1.5` (sage) | `1.5` (cipher), `1.5` (sage) |
| `TOP_P` | Nucleus top-p (cumulative prob threshold) | `0.95` | `0.95` |
| `ALIAS` | Model alias | `jzaleski/cipher`, `jzaleski/sage` | `jzaleski/cipher`, `jzaleski/sage` |
| `HOST` | Host address | `127.0.0.1` | `0.0.0.0` |
| `FLASH_ATTN` | Flash attention | `on` | `on` |
| `N_GPU_LAYERS` | GPU layers to offload (-1 = all) | `-1` | `-1` |
| `BATCH_SIZE` | Batch size for inference | `2048` (cipher), `2048` (sage) | `4096` (cipher), `4096` (sage) |
| `UBATCH_SIZE` | Ubatch size for inference | `512` (cipher), `512` (sage) | `1024` (cipher), `1024` (sage) |

---

## Architecture

```
┌──────────────────┐
│   Cipher Model   │ (Port 8081)
│  Qwen3.6-35B-A3B │
│ (local & server) │
└──────────────────┘
```

```
┌──────────────────┐
│    Sage Model    │ (Port 8082)
│  Qwen3.6-35B-A3B │
│ (local & server) │
└──────────────────┘
```

---

## Opencode Agent Architecture

```
┌──────────────────┐
│   Opencode CLI   │
│                  │
│ ┌──────────────┐ │
│ │ Engineer     │ │ (default)
│ │ [adaptive:   │ │
│ │  triage →    │ │
│ │  direct /    │ │
│ │  dispatch /  │ │
│ │  lifecycle]  │ │
│ └──────────────┘ │
│                  │
│ ┌──────────────┐ │
│ │ Analyze      │ │
│ │ [data/report]│ │
│ └──────────────┘ │
└─────────┬────────┘
          │
          ▼
┌──────────────────┐
│    LLM Provider  │
│                  │
│ ┌──────────────┐ │ ┌───────────────┐
│ │ Local Cipher │ │ │ Local Sage    │
│ │ Port 8081    │ │ │ Port 8082     │
│ └──────────────┘ │ └───────────────┘
│                  │
│ ┌──────────────┐ │ ┌───────────────┐
│ │ Server Cipher│ │ │ Server Sage   │
│ │ (remote)     │ │ │ (remote)      │
│ └──────────────┘ │ └───────────────┘
└──────────────────┘
```

The opencode configuration defines 4 provider endpoints:
- **llama.cpp (local - jzaleski/cipher)**: `localhost:8081` — Qwen3.6-35B-A3B, 81K context
- **llama.cpp (local - jzaleski/sage)**: `localhost:8082` — Qwen3.6-35B-A3B, 81K context
- **llama.cpp (server - jzaleski/cipher)**: `server-hostname-or-ip:8081`, 262K context
- **llama.cpp (server - jzaleski/sage)**: `server-hostname-or-ip:8082`, 262K context

Each provider specifies model limits for context window, input tokens, and output tokens. Users should replace `server-hostname-or-ip` with their actual server hostname or IP address.

### Disabled Providers & Built-in Agents

`opencode.json` disables the default `opencode` and `openai` providers via `disabled_providers`. The built-in `build` and `plan` agents are also disabled — only the two custom agents (`analyze`, `engineer`) are active.

### MCP Integrations

MCP integrations are declared in `opencode.json` but **disabled by default**:

| Integration | URL |
|-------------|-----|
| Jira | `https://mcp.atlassian.com/v1/mcp` |
| Vercel | `https://mcp.vercel.com/v1/mcp` |

Toggle `enabled: true` in `opencode.json` to activate.

### Opencode Wrapper

`home/.local/lib/opencode.sh` wraps the `opencode` CLI to add session persistence and cache reset behavior. It is aliased via `home/.opencoderc`, which is sourced from `~/.bashrc` and `~/.zshrc` by the bootstrap system.

- Persists the last session ID to `.last-opencode-session` in the git repo root
- Resumes via `--continue` / `-s` / `--session` using the persisted ID
- Resets model history and clears model cache on fresh sessions (configurable via `RESET_OPENCODE_HISTORY`, `RESET_OPENCODE_MODELS_CACHE`)
- Required binaries (all installed via bootstrap): `cat`, `git`, `jq`, `opencode`, `sqlite3`

---

## Bootstrap System

The bootstrap system sets up the local development environment:

```bash
bin/bootstrap                               # Interactive
ASSUME_YES=true bin/bootstrap               # Non-interactive
```

Bootstrap scripts are defined as an explicit ordered array in `bin/bootstrap` and live alongside it in `bin/`:

| Script | Purpose |
|--------|---------|
| `bin/install-dependencies` | Installs Homebrew (if missing) and base packages (`ag`, `btop`, `curl`, `git`, `jq`, `htop`, `llama.cpp`, `nvtop`, `ollama`, `openssl`, `readline`, `sqlite`, `wget`, `zsh`) |
| `bin/configure-node` | Clones/updates `nodenv` and the `node-build` plugin; installs Node.js (from `.default-node-version`) and npm (from `.default-npm-version`) |
| `bin/configure-opencode` | Installs `opencode-ai` (from `.default-opencode-version`); appends `.opencoderc` sourcing to `~/.bashrc` and `~/.zshrc` |

To run only a subset of scripts, use `BOOTSTRAP_SCRIPTS`:
```bash
BOOTSTRAP_SCRIPTS="configure-node,configure-opencode" bin/bootstrap
```
To skip specific scripts, use `BOOTSTRAP_SKIP`:
```bash
BOOTSTRAP_SKIP="install-dependencies" bin/bootstrap
```

### Tool Versions

Pinned versions live in top-level dotfiles:

| File | Tool |
|------|------|
| `.default-node-version` | Node.js (nodenv) |
| `.default-npm-version` | npm |
| `.default-opencode-version` | opencode-ai |

---

## Performance

- GPU acceleration enabled with flash attention by default
- Use Q4-Q6 quantization for memory-constrained environments
- Context size: 81920 (cipher local), 262144 (cipher server), 81920 (sage local), 262144 (sage server)

## Troubleshooting

**Model not loading**: Verify RAM (16GB+), GPU/VRAM, model name and quantization.

**Connection failures**: Verify llama-server running.

**Performance issues**: Enable flash attention, reduce context size, adjust quantization.

## What to Avoid

- Do not modify model defaults without clear reason — quantization levels and context sizes are tuned for specific hardware profiles
- Do not change port allocations without updating all dependent configurations
- Do not skip `set -e` error handling in shell scripts
