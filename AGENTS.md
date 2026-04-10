# AGENTS.md

Guidelines for agentic coding tools in this repository.

## Project Overview

Shell scripts and Docker configurations for running local LLMs using `llama-server`.
Supports coding assistance (Qwen3-Coder-Next local, MiniMax-M2.5 server) and general advising (Qwen3.5-35B-A3B/Qwen3.5-122B-A10B).

**No code repositories** - utilities/config only.

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **architect.md**: Planning and analysis agent — no file modifications, terse bullet-point output
- **implement.md**: Default build agent with full tool access for implementing changes
- **scribe.md**: Content and prose agent — documentation, READMEs, changelogs, specs, and copy

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `architect`.

---

## Project Structure

```
.
├── bin/                                    # Main execution scripts
│   ├── bootstrap.sh                        # System setup and configuration bootstrap
│   ├── run-coder.sh                        # Coder model (Qwen3-Coder-Next local, MiniMax-M2.5 server)
│   ├── run-coder-experimental.sh           # Expirmental coder model (stub)
│   ├── run-advisor.sh                      # Advisor model (Qwen3.5-9B/Qwen3.5-122B-A10B)
│   ├── run-advisor-experimental.sh         # Experimental advisor model (stub)
│   └── run-open-webui.sh                   # Open WebUI Docker wrapper
├── scripts/                                # Bootstrap scripts (executed by bin/bootstrap.sh)
├── home/                                   # Dotfiles and config files to symlink
├── docker-compose-files/
│   └── open-webui.yml                      # Docker Compose configuration for Open WebUI
```

---

## Build/Test Commands

Scripts in `bin/` support **local** and **server** modes:

```bash
./bin/run-coder.sh                          # Local mode
./bin/run-coder.sh --server                 # Server mode
./bin/run-coder-experimental.sh             # Local mode - Not implemented
./bin/run-coder-experimental.sh --server    # Server mode - Not implemented
./bin/run-advisor.sh                        # Local mode
./bin/run-advisor.sh --server               # Server mode
./bin/run-advisor-experimental.sh           # Local mode - Not implemented
./bin/run-advisor-experimental.sh --server  # Server mode - Not implemented
./bin/run-open-webui.sh                     # Local mode
./bin/run-open-webui.sh --server            # Server mode
```

Test with: `bash -x ./bin/run-coder.sh` or `bash -x ./bin/run-advisor.sh`

---

## Code Style Guidelines

### Bash Scripts

- **Shebang**: `#!/usr/bin/env bash`
- **Functions**: Use `run_local()` and `run_server()`
- **Mode Detection**: `if [[ "${1:-}" == "--server" ]]; then run_server; else run_local; fi`
- **Variable Quoting**: Always quote expansions `"${VAR:-default}"`
- **Path Resolution**: Use `$(dirname $0)/..` for relative paths

### Configuration Files

- Docker Compose: Use `snake_case` naming
- Environment Variables: Use `${VAR:-default}` syntax

### Documentation

- Keep `README.md` updated
- Document all environment variables with defaults
- Include usage examples and ASCII diagrams

### Naming Conventions

- Scripts: `run-{component}.sh`
- Modes: `local` / `server`
- Ports: 8080 (WebUI), 8081 (coder), 8082 (advisor)
- Aliases: `jzaleski/{component}`

---

## Environment Variables

| Variable | Description | Default (Local) | Default (Server) |
|----------|-------------|-----------------|------------------|
| `MODEL_PROVIDER` | HuggingFace org | `unsloth` | `unsloth` |
| `MODEL_NAME` | Model name (no -GGUF) | `Qwen3-Coder-Next` (coder), `Qwen3.5-35B-A3B` (advisor) | `MiniMax-M2.5` (coder), `Qwen3.5-122B-A10B` (advisor) |
| `MODEL_QUANTIZATION` | Quantization level | `Q4_K_M` | `Q8_0` |
| `TEMP` | Sampling temperature | `1.0` | `1.0` |
| `PORT` | Network port | `8081` (coder), `8082` (advisor) | `8081` (coder), `8082` (advisor) |
| `CTX_SIZE` | Context window | `65536` (coder), `65536` (advisor) | `196608` (coder), `262144` (advisor) |
| `MIN_P` | Nucleus min | `0.01` | `0.01` |
| `TOP_K` | Top-K limit | `40` (coder), `20` (advisor) | `40` (coder), `20` (advisor) |
| `REPEAT_PENALTY` | Repeat penalty | `1.0` | `1.0` |
| `PRESENCE_PENALTY` | Presence penalty | `1.5` | `1.5` |
| `TOP_P` | Nucleus top-p | `0.95` | `0.95` |
| `ALIAS` | Model alias | `jzaleski/coder`, `jzaleski/advisor` | `jzaleski/coder`, `jzaleski/advisor` |
| `HOST` | Host address | `127.0.0.1` | `0.0.0.0` |
| `FLASH_ATTN` | Flash attention | `on` | `on` |
| `N_GPU_LAYERS` | GPU layers to offload | `-1` | `-1` |
| `WEBUI_AUTH` | WebUI authentication | `False` | `True` |
| `ADVISOR_MODEL_PORT` | Advisor model port for WebUI | `8082` | `8082` |
| `IMAGE` | Docker image for WebUI | `ghcr.io/open-webui/open-webui:main` | `ghcr.io/open-webui/open-webui:main` |

---

## Architecture

```
┌──────────────────┐
│    Coder Model   │ (Port 8081)
│ Qwen3-Coder-Next │
│      (local)     │
└──────────────────┘
```

```
┌──────────────────┐
│   Advisor Model  │ (Port 8082)
│ Qwen3.5-35B-A3B  │
│ Qwen3.5-122B-A10B│
└──────────────────┘
```

```
┌──────────────────┐
│    Open WebUI    │ (Port 8080)
│                  │
│   ┌──────────┐   │
│   │  Client  │   │
│   └─────┬────┘   │
└─────────┼────────┘
          │
          ▼
┌──────────────────┐
│   Advisor Model  │ (Port 8082)
│    Qwen3.5-9B    │
│ Qwen3.5-122B-A10B│
└──────────────────┘
```

---

## Opencode Agent Architecture

```
┌────────────────────┐
│   Opencode CLI     │
│                    │
│ ┌──────────────┐   │
│ │ Architect    │   │ (default)
│ │ [plan only]  │   │
│ └──────────────┘   │
│                    │
│ ┌──────────────┐   │
│ │ Implement    │   │
│ │ [full tools] │   │
│ └──────────────┘   │
│                    │
│ ┌──────────────┐   │
│ │ Scribe       │   │
│ │ [docs only]  │   │
│ └──────────────┘   │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│    LLM Provider    │
│                    │
│ ┌──────────────┐   │ ┌───────────────┐
│ │ Local Coder  │   │ │ Local Advisor │
│ │ Port 8081    │   │ │ Port 8082     │
│ └──────────────┘   │ └───────────────┘
│                    │
│ ┌──────────────┐   │ ┌───────────────┐
│ │ Server Coder │   │ │ Server Advisor│
│ │ (remote)     │   │ │ (remote)      │
│ └──────────────┘   │ └───────────────┘
└────────────────────┘
```

The opencode configuration defines 4 provider endpoints:
- **llama.cpp (local - coder - stable)**: `localhost:8081` — Qwen3-Coder-Next, 65K context
- **llama.cpp (local - advisor - stable)**: `localhost:8082` — Qwen3.5-35B-A3B, 65K context
- **llama.cpp (server - coder - stable)**: `server-hostname-or-ip:8081`, 196K context
- **llama.cpp (server - advisor - stable)**: `server-hostname-or-ip:8082`, 262K context

Each provider specifies model limits for context window, input tokens, and output tokens. Users should replace `server-hostname-or-ip` with their actual server hostname or IP address.

---

## Performance

- GPU acceleration enabled with flash attention by default
- Use Q4-Q6 quantization for memory-constrained environments
- Context size: 65536 (coder local), 196608 (coder server), 65536 (advisor local), 262144 (advisor server)

## Docker Compose

```bash
docker compose -f docker-compose-files/open-webui.yml up
docker compose -f docker-compose-files/open-webui.yml down
```

## Troubleshooting

**Model not loading**: Verify RAM (16GB+), GPU/VRAM, model name and quantization.

**Connection failures**: Verify llama-server running, check `ADVISOR_MODEL_PORT`, ensure Docker host access.

**Performance issues**: Enable flash attention, reduce context size, adjust quantization.

## What to Avoid

- Do not modify model defaults without clear reason — quantization levels and context sizes are tuned for specific hardware profiles
- Do not change port allocations without updating all dependent configurations
- Do not enable authentication in local mode unless explicitly required
- Do not skip `set -e` error handling in shell scripts
