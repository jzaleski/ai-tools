# AGENTS.md

Guidelines for agentic coding tools in this repository.

## Project Overview

Shell scripts and Docker configurations for running local LLMs using `llama-server`.
Supports coding assistance (Qwen3-Coder-Next local, MiniMax-M2.5 server) and general advising (Qwen3.5-35B-A3B/Qwen3.5-122B-A10B).

**No code repositories** - utilities/config only.

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **build.md**: Build agent with full tool access for implementing changes
- **plan.md**: Planning agent for analysis and implementation planning (no file modifications)

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance.

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
│   ├── run-open-webui.sh                   # Open WebUI Docker wrapper
│   ├── run-openclaw.sh                     # OpenClaw model (GLM-4.7-Flash)
│   └── run-openclaw-experimental.sh        # Experimental openclaw model (stub)
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
./bin/run-openclaw.sh                       # Local mode
./bin/run-openclaw.sh --server              # Server mode
./bin/run-openclaw-experimental.sh          # Local mode - Not implemented
./bin/run-openclaw-experimental.sh --server # Server mode - Not implemented
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
- Ports: 8080 (WebUI), 8081 (coder), 8082 (advisor), 8083 (openclaw)
- Aliases: `jzaleski/{component}`

---

## Environment Variables

| Variable | Description | Default (Local) | Default (Server) |
|----------|-------------|-----------------|------------------|
| `MODEL_PROVIDER` | HuggingFace org | `unsloth` | `unsloth` |
| `MODEL_NAME` | Model name (no -GGUF) | `Qwen3-Coder-Next` (coder), `Qwen3.5-35B-A3B` (advisor), `GLM-4.7-Flash` (openclaw) | `MiniMax-M2.5` (coder), `Qwen3.5-122B-A10B` (advisor), `GLM-4.7-Flash` (openclaw) |
| `MODEL_QUANTIZATION` | Quantization level | `Q4_K_M` | `Q8_0` |
| `TEMP` | Sampling temperature | `1.0` | `1.0` |
| `PORT` | Network port | `8081` (coder), `8082` (advisor), `8083` (openclaw) | `8081` (coder), `8082` (advisor), `8083` (openclaw) |
| `CTX_SIZE` | Context window | `65536` (coder), `65536` (advisor) | `196608` (coder), `262144` (advisor) |
| `MIN_P` | Nucleus min | `0.01` | `0.01` |
| `TOP_K` | Top-K limit | `40` (coder), `20` (advisor), `20` (openclaw) | `40` (coder), `20` (advisor), `20` (openclaw) |
| `REPEAT_PENALTY` | Repeat penalty | `1.0` | `1.0` |
| `PRESENCE_PENALTY` | Presence penalty | `1.5` | `1.5` |
| `TOP_P` | Nucleus top-p | `0.95` | `0.95` |
| `ALIAS` | Model alias | `jzaleski/coder`, `jzaleski/advisor`, `jzaleski/openclaw` | `jzaleski/coder`, `jzaleski/advisor`, `jzaleski/openclaw` |
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
│  OpenClaw Model  │ (Port 8083)
│   GLM-4.7-Flash  │
│   GLM-4.7-Flash  │
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
