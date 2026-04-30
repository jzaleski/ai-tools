# AGENTS.md

Guidelines for agentic coding tools in this repository.

## Project Overview

Shell scripts and Docker configurations for running local LLMs using `llama-server`.
Supports coding assistance (Qwen3.6-35B-A3B local, MiniMax-M2.7 server) and general advising (Qwen3.6-35B-A3B local and server).

**No code repositories** - utilities/config only.

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **architect.md**: Full lifecycle engineer — ensures AGENTS.md exists (generating it if needed), manages branches, runs SuperPowers skills (brainstorming → planning → implementation) to deliver complete work
- **implement.md**: Default build agent with full tool access for implementing changes — leaves all changes in the working tree, escalates complex work to Architect
- **analyze.md**: Data analyst agent — ingests data in any format (PDF, XLSX, CSV, TSV, JSON, etc.), extracts and normalizes it into reusable artifacts, analyzes it, and produces a report in the user-specified format

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `implement`.

---

## Project Structure

```
.
├── bin/                                   # Main execution scripts
│   ├── bootstrap.sh                       # System setup and configuration bootstrap
│   ├── run-cipher.sh                      # Cipher model (Qwen3.6-35B-A3B local, MiniMax-M2.7 server)
│   ├── run-sage.sh                        # Sage model (Qwen3.6-35B-A3B local and server)
│   └── run-open-webui.sh                  # Open WebUI Docker wrapper
├── scripts/                               # Bootstrap scripts (executed by bin/bootstrap.sh)
├── home/                                  # Dotfiles and config files to symlink
├── docker-compose-files/
│   └── open-webui.yml                     # Docker Compose configuration for Open WebUI
```

---

## Build/Test Commands

Scripts in `bin/` support **local** and **server** modes:

```bash
./bin/run-cipher.sh                        # Local mode
./bin/run-cipher.sh --server               # Server mode
./bin/run-sage.sh                          # Local mode
./bin/run-sage.sh --server                 # Server mode
./bin/run-open-webui.sh                    # Local mode
./bin/run-open-webui.sh --server           # Server mode
```

Test with: `bash -x ./bin/run-cipher.sh` or `bash -x ./bin/run-sage.sh`

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
- Ports: 8080 (WebUI), 8081 (cipher), 8082 (sage)
- Aliases: `jzaleski/{component}`

---

## Environment Variables

| Variable | Description | Default (Local) | Default (Server) |
|----------|-------------|-----------------|------------------|
| `MODEL_PROVIDER` | HuggingFace org | `unsloth` | `unsloth` |
| `MODEL_NAME` | Model name (no -GGUF) | `Qwen3.6-35B-A3B` (cipher), `Qwen3.6-35B-A3B` (sage) | `MiniMax-M2.7` (cipher), `Qwen3.6-35B-A3B` (sage) |
| `MODEL_QUANTIZATION` | Quantization level | `UD-Q4_K_XL` (cipher), `UD-Q4_K_XL` (sage) | `Q8_0` (cipher), `UD-Q8_K_XL` (sage) |
| `TEMP` | Sampling temperature | `1.0` (cipher), `1.0` (sage) | `1.0` (cipher), `1.0` (sage) |
| `PORT` | Network port | `8081` (cipher), `8082` (sage) | `8081` (cipher), `8082` (sage) |
| `CTX_SIZE` | Context window (tokens) | `81920` (cipher), `81920` (sage) | `196608` (cipher), `262144` (sage) |
| `MIN_P` | Nucleus min (0.0 disables) | `0.01` (cipher), `0.0` (sage) | `0.01` (cipher), `0.0` (sage) |
| `TOP_K` | Top-K limit (0 or 0.0 disables) | `40` (cipher), `20` (sage) | `40` (cipher), `20` (sage) |
| `REPEAT_PENALTY` | Repeat penalty (1.0 = no penalty) | `1.0` | `1.0` |
| `PRESENCE_PENALTY` | Presence penalty | `1.5` (cipher), `1.5` (sage) | `1.5` (cipher), `1.5` (sage) |
| `TOP_P` | Nucleus top-p (cumulative prob threshold) | `0.95` | `0.95` |
| `ALIAS` | Model alias | `jzaleski/cipher`, `jzaleski/sage` | `jzaleski/cipher`, `jzaleski/sage` |
| `HOST` | Host address | `127.0.0.1` | `0.0.0.0` |
| `FLASH_ATTN` | Flash attention | `on` | `on` |
| `N_GPU_LAYERS` | GPU layers to offload (-1 = all) | `-1` | `-1` |
| `WEBUI_AUTH` | WebUI authentication | `False` | `True` |
| `SAGE_MODEL_PORT` | Sage model port for WebUI | `8082` | `8082` |
| `IMAGE` | Docker image for WebUI | `ghcr.io/open-webui/open-webui:main` | `ghcr.io/open-webui/open-webui:main` |

---

## Architecture

```
┌──────────────────┐
│   Cipher Model   │ (Port 8081)
│   MiniMax-M2.7   │
│     (server)     │
└──────────────────┘
```

```
┌──────────────────┐
│    Sage Model    │ (Port 8082)
│  Qwen3.6-35B-A3B │
│ (local & server) │
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
│ │ Implement    │ │ (default)
│ │ [full tools] │ │
│ └──────────────┘ │
│                  │
│ ┌──────────────┐ │
│ │ Architect    │ │
│ │ [lifecycle]  │ │
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
- **llama.cpp (server - jzaleski/cipher)**: `server-hostname-or-ip:8081`, 196K context
- **llama.cpp (server - jzaleski/sage)**: `server-hostname-or-ip:8082`, 262K context

Each provider specifies model limits for context window, input tokens, and output tokens. Users should replace `server-hostname-or-ip` with their actual server hostname or IP address.

---

## Performance

- GPU acceleration enabled with flash attention by default
- Use Q4-Q6 quantization for memory-constrained environments
- Context size: 81920 (cipher local), 196608 (cipher server), 81920 (sage local), 262144 (sage server)

## Docker Compose

```bash
docker compose -f docker-compose-files/open-webui.yml up
docker compose -f docker-compose-files/open-webui.yml down
```

## Troubleshooting

**Model not loading**: Verify RAM (16GB+), GPU/VRAM, model name and quantization.

**Connection failures**: Verify llama-server running, check `SAGE_MODEL_PORT`, ensure Docker host access.

**Performance issues**: Enable flash attention, reduce context size, adjust quantization.

## What to Avoid

- Do not modify model defaults without clear reason — quantization levels and context sizes are tuned for specific hardware profiles
- Do not change port allocations without updating all dependent configurations
- Do not enable authentication in local mode unless explicitly required
- Do not skip `set -e` error handling in shell scripts
