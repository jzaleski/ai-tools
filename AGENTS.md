# AGENTS.md

Guidelines for agentic coding tools in this repository.

## Project Overview

Shell scripts for running local LLMs using `llama-server`.
Supports four model tiers — low (Qwen3.6-35B-A3B Q4_K_XL, 32K ctx), medium (Qwen3.6-35B-A3B Q6_K_XL, 64K ctx), high (Qwen3.6-27B Q8_K_XL, 128K ctx), long (Qwen3.6-35B-A3B Q6_K_XL, 256K ctx). Every tier loads an F16 multimodal projector (`--mmproj`, auto-downloaded) so image input works on all tiers. Bind address is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN).

**No code repositories** - utilities/config only.

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **data.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
- **product.md**: Work-shaping persona — runs the triage skill to classify and route an inbound request, the scope skill to capture a stakeholder's requirements as a right-sized artifact, the refine skill to mature it (with engineering) into a ticket-ready brief, and the handoff skill to package it into a liftable engineering hand-off; produces artifacts, never writes code or hands off automatically

Workflow skills are vendored locally under `home/.config/opencode/skills/`. The engineering lifecycle uses researcher, planner, coder, reviewer, and finisher; the data pipeline uses ingest, analyze, and report; the product funnel uses triage, scope, refine, and handoff. No external plugin dependencies.

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
│   ├── run-model                          # Direct llama-server launcher (single model + mmproj, --tier low|medium|high|long)
│   └── run-router                         # Router server (llama.cpp, multi-model + mmproj; HOST env toggles bind)
├── templates/                             # llama-server INI preset templates
│   └── llama-cpp.ini.template             # Router preset (low: 32K, medium: 64K, high: 128K, long: 256K ctx; per-tier mmproj for vision)
├── home/                                  # Dotfiles and config files to symlink
│   ├── .config/opencode/
│   │   ├── agents/                        # Agent definitions (data, engineer, product)
│   │   ├── skills/                        # Vendored workflow skills (analyze, coder, finisher, handoff, ingest, planner, refine, report, researcher, reviewer, scope, triage)
│   │   └── opencode.json                  # Provider, agent, MCP configuration
│   ├── .local/lib/opencode.sh             # Opencode wrapper (session persistence, cache reset)
│   └── .opencoderc                        # Shell alias: opencode → ~/.local/lib/opencode.sh
```

---

## Build/Test Commands

Scripts in `bin/` bind to `127.0.0.1` by default; set `HOST=0.0.0.0` to expose on the LAN. `run-model` takes an optional `--tier` flag (low/medium/high/long, default medium):

```bash
./bin/run-router                           # multi-model router, localhost (8080)
HOST=0.0.0.0 ./bin/run-router              # multi-model router, exposed on LAN
# Clients select tier via: ?model=jzaleski/low  jzaleski/medium  jzaleski/high  jzaleski/long

./bin/run-model                            # single model, medium tier, localhost (127.0.0.1:8080)
./bin/run-model --tier low                 # single model, low tier
./bin/run-model --tier high                # single model, high tier
./bin/run-model --tier long                # single model, long-context tier
HOST=0.0.0.0 ./bin/run-model --tier high   # single model, high tier, exposed on LAN
```

Test with: `bash -x ./bin/run-router` or `bash -x ./bin/run-model`

---

## Code Style Guidelines

### Bash Scripts

- **Shebang**: `#!/usr/bin/env bash`
- **Functions**: Use `run_<tier>()` helpers (e.g. `run_low()`, `run_high()`) plus a `main()` for the router, as needed
- **Tier Detection**: Parse the `--tier` flag with a `for arg in "$@"` loop; dispatch to the appropriate function
- **Variable Quoting**: Always quote expansions `"${VAR:-default}"`
- **Path Resolution**: Use `$(dirname $0)/..` for relative paths

### Configuration Files

- Environment Variables: Use `${VAR:-default}` syntax

### Documentation

- Keep `README.md` updated
- Document all environment variables with defaults
- Include usage examples and ASCII diagrams

### Naming Conventions

- Scripts: `run-{component}`
- Bind toggle: `HOST` env var (`127.0.0.1` default / `0.0.0.0` for LAN)
- Ports: 8080 (all scripts)
- Aliases: `jzaleski/{tier}`

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
│       │ jzaleski/low    │        │
│       │ jzaleski/medium │        │
│       │ jzaleski/high   │        │
│       │ jzaleski/long   │        │
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
│ │ Data         │ │
│ │ [pipeline:   │ │
│ │  ingest →    │ │
│ │  analyze →   │ │
│ │  report]     │ │
│ └──────────────┘ │
│                  │
│ ┌──────────────┐ │
│ │ Product      │ │
│ │ [funnel:     │ │
│ │  triage →    │ │
│ │  scope →     │ │
│ │  refine →    │ │
│ │  handoff]    │ │
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
- **llama.cpp (local)**: `localhost:8080` — per-tier context (low: 32K, medium: 64K, high: 128K, long: 256K); models: `jzaleski/low` (Qwen3.6-35B-A3B Q4_K_XL), `jzaleski/medium` (Qwen3.6-35B-A3B Q6_K_XL), `jzaleski/high` (Qwen3.6-27B Q8_K_XL), `jzaleski/long` (Qwen3.6-35B-A3B Q6_K_XL)
- **llama.cpp (server)**: `server-hostname-or-ip:8080` — same four aliases and contexts; reach this endpoint by launching with `HOST=0.0.0.0`

Each provider specifies model limits for context window, input tokens, and output tokens. Users should replace `server-hostname-or-ip` with their actual server hostname or IP address.

### Disabled Providers & Built-in Agents

`opencode.json` disables the default `opencode` and `openai` providers via `disabled_providers`. The built-in `build` and `plan` agents are also disabled — only the three custom agents (`data`, `engineer`, `product`) are active.

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
- KV cache quantization is tier-specific: low=q4_0, medium=q4_0, high=q8_0, long=q4_0
- Context size is tier-specific: low=32K, medium=64K, high=128K, long=256K
- Batch/ubatch is tier-specific and scales inversely with context for steady latency on Apple Silicon: low & medium=2048/512, high & long=1024/256
- Sampling defaults are tuned for coding and tool-calling: `temp=0.7`, `top-k=0` (disabled), `top-p=0.95`, `min-p=0.02`, `presence-penalty=0.2`

## Troubleshooting

**Model not loading**: Verify RAM (16GB+), GPU/VRAM, model name and quantization.

**Connection failures**: Verify llama-server running.

**Performance issues**: Enable flash attention, reduce context size, adjust quantization.

## What to Avoid

- Do not modify model defaults without clear reason — quantization levels and context sizes are tuned for specific hardware profiles
- Do not change port allocations without updating all dependent configurations
- Do not skip `set -e` error handling in shell scripts
