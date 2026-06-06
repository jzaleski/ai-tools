# AGENTS.md

Guidelines for agentic coding tools in this repository.

## Project Overview

Shell scripts for running local LLMs using `llama-server`.
Supports three model tiers — low (Qwen3.6-35B-A3B Q4_K_XL), medium (Qwen3.6-35B-A3B Q6_K_XL), high (Qwen3.6-27B Q8_K_XL) — each available in local and server modes.

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
│   ├── configure-git                      # Configures global git settings (core.excludesfile)
│   ├── configure-node                     # Clones/updates nodenv, installs Node.js and npm
│   ├── configure-opencode                 # Installs opencode-ai and configures shell init
│   ├── download-model                     # Downloads a single GGUF file from Hugging Face via curl
│   ├── run-local                          # Direct llama-server launcher (local mode, no router)
│   ├── run-router                         # Router server (llama.cpp, local and server modes)
│   └── run-server                         # Direct llama-server launcher (server mode, no router)
├── templates/                             # llama-server INI preset templates
│   ├── llama-cpp-local.ini.template       # Router preset: local profile (low: 32K, medium: 64K, high: 128K ctx)
│   └── llama-cpp-server.ini.template      # Router preset: server profile (low: 64K, medium: 128K, high: 256K ctx)
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

Scripts in `bin/` support **local** and **server** modes, each with an optional `--tier` flag that selects the model tier (low/medium/high):

```bash
./bin/run-router                           # llama.cpp, local mode (8080)
./bin/run-router --server                  # llama.cpp, server mode (8080)
# Clients select tier via: ?model=jzaleski/low  ?model=jzaleski/medium  ?model=jzaleski/high

./bin/run-local                            # direct llama-server, local mode, medium tier (127.0.0.1:8080)
./bin/run-local --tier low                 # direct llama-server, local mode, low tier
./bin/run-local --tier high                # direct llama-server, local mode, high tier
./bin/run-server                           # direct llama-server, server mode, medium tier (0.0.0.0:8080)
./bin/run-server --tier low                # direct llama-server, server mode, low tier
./bin/run-server --tier high               # direct llama-server, server mode, high tier
```

Test with: `bash -x ./bin/run-router` or `bash -x ./bin/run-local`

---

## Code Style Guidelines

### Bash Scripts

- **Shebang**: `#!/usr/bin/env bash`
- **Functions**: Use `run_local()`, `run_server()`, and tier-dispatch helpers as needed
- **Mode Detection**: Parse `--server` and `--tier` flags with a `for arg in "$@"` loop; dispatch to the appropriate function
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
- Ports: 8080 (all scripts)
- Aliases: `jzaleski/{component}`

---

## Environment Variables

| Variable | Description | Default (Local) | Default (Server) |
|----------|-------------|-----------------|------------------|
| `HOST` | Host address | `127.0.0.1` | `0.0.0.0` |
| `PORT` | Network port | `8080` | `8080` |

Model-specific parameters (quantization, context size, sampling settings, etc.) are configured in the INI preset files under `templates/`.

---

## Architecture

```
┌──────────────────────────────────┐
│         Router Server            │ (Port 8080)
│        --models-preset           │
│                                  │
│       ┌─────────────────┐        │
│       │jzaleski/low/   │        │
│       │medium/high     │        │
│       └─────────────────┘        │
└──────────────────────────────────┘
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
│ │ Local        │ │ │ Server        │
│ │ Port 8080    │ │ │ (remote)      │
│ └──────────────┘ │ └───────────────┘
└──────────────────┘
```

The opencode configuration defines 2 provider endpoints:
- **llama.cpp (local)**: `localhost:8080` — per-tier context (low: 64K, medium: 64K, high: 64K); models: `jzaleski/low` (Qwen3.6-35B-A3B Q4_K_XL), `jzaleski/medium` (Qwen3.6-35B-A3B Q6_K_XL), `jzaleski/high` (Qwen3.6-27B Q8_K_XL)
- **llama.cpp (server)**: `server-hostname-or-ip:8080` — per-tier context (low: 256K, medium: 256K, high: 256K); same three aliases

Each provider specifies model limits for context window, input tokens, and output tokens. Users should replace `server-hostname-or-ip` with their actual server hostname or IP address.

### Disabled Providers & Built-in Agents

`opencode.json` disables the default `opencode` and `openai` providers via `disabled_providers`. The built-in `build` and `plan` agents are also disabled — only the two custom agents (`analyze`, `engineer`) are active.

### MCP Integrations

MCP integrations are declared in `opencode.json` but **disabled by default**:

| Integration | Type | Command / URL |
|-------------|------|---------------|
| Jira | remote | `https://mcp.atlassian.com/v1/mcp` |
| Playwright | local | `npx @playwright/mcp@latest` |
| Vercel | remote | `https://mcp.vercel.com/v1/mcp` |

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
| `bin/install-dependencies` | Installs Homebrew (if missing) and base packages (`ag`, `btop`, `curl`, `git`, `jq`, `htop`, `llama.cpp`, `nvtop`, `openssl`, `readline`, `sqlite`, `wget`, `zsh`) |
| `bin/configure-git` | Configures global git settings — sets `core.excludesfile` to `~/.gitignore` if not already set |
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
- KV cache quantization is tier-specific: local: all tiers=q4_0; server: low=q4_0, medium=q4_0, high=q8_0
- Context size is tier-specific — local: low=64K, medium=64K, high=64K; server: low=256K, medium=256K, high=256K
- Sampling defaults are tuned for coding and tool-calling: `temp=0.7`, `top-k=0` (disabled), `top-p=0.95`, `min-p=0.02`, `presence-penalty=0.2`

## Troubleshooting

**Model not loading**: Verify RAM (16GB+), GPU/VRAM, model name and quantization.

**Connection failures**: Verify llama-server running.

**Performance issues**: Enable flash attention, reduce context size, adjust quantization.

## What to Avoid

- Do not modify model defaults without clear reason — quantization levels and context sizes are tuned for specific hardware profiles
- Do not change port allocations without updating all dependent configurations
- Do not skip `set -e` error handling in shell scripts
