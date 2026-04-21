# AI Tools

Utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. It includes support for two primary use cases - coding assistance (server-only) and general advising.

Models are loaded from HuggingFace and quantized for efficient local inference.

## Project Structure

```
.
├── bin/                            # Main execution scripts
│   ├── bootstrap.sh                # System setup and configuration bootstrap
│   ├── run-cipher.sh               # Cipher model (MiniMax-M2.7 server, Qwen3.6-35B-A3B local)
│   ├── run-cipher-experimental.sh  # Experimental cipher model (stub, not implemented)
│   ├── run-sage.sh                 # Sage model (Qwen3.6-35B-A3B local and server)
│   ├── run-sage-experimental.sh    # Experimental sage model (stub, not implemented)
│   └── run-open-webui.sh           # Open WebUI Docker wrapper
├── scripts/                        # Bootstrap scripts (executed by bin/bootstrap.sh)
├── home/                           # Dotfiles and config files to symlink
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
bin/bootstrap.sh

# Run bootstrap non-interactively (overwrite without prompt)
ASSUME_YES=true bin/bootstrap.sh
```

The bootstrap script:
- Initializes and updates git submodules if present (none currently)
- Copies files from `home/` to your `$HOME` directory
- Executes scripts in `scripts/` in sorted order
- Supports `sudo_scripts/` for root-level operations (none currently)

## Prerequisites

- At least 16GB RAM for 20B+ models
- GPU support (recommended)
- Docker (optional; for Open WebUI)

## Tool Versions

The project tracks specific versions of key development tools in version files:

| File | Description | Default |
|------|-------------|---------|
| `.default-node-version` | Node.js version for nodenv | 24.14.0 |
| `.default-npm-version` | npm version | 11.12.0 |
| `.default-opencode-version` | opencode-ai version | 1.14.19 |

These versions are managed and installed via the bootstrap system

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **architect.md**: Planning and analysis agent — no file modifications, terse bullet-point output
- **implement.md**: Default build agent with full tool access for implementing changes
- **scribe.md**: Content and prose agent — documentation, READMEs, changelogs, specs, and copy

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `architect`.

## Environment Variables

You can override default settings via environment variables. The same variables apply to both local and server modes. Environment defaults differ between local and server modes as shown in the Components section.

**Common Variables:**
- `MODEL_PROVIDER`: Provider/organization name for the model (default: unsloth)
- `MODEL_NAME`: Name of the model to load (no -GGUF suffix, defaults to local/server mode below)
- `MODEL_QUANTIZATION`: Full quantization specification (default: Q4_K_M for local, Q8_0 for server)
- `HOST`: Network interface address to bind the server to (default: 127.0.0.1 for local, 0.0.0.0 for server)
- `PORT`: Network port for the server to listen on for incoming connections (default: 8081 for cipher, 8082 for sage, 8080 for WebUI)
- `ALIAS`: Custom name to register the model with llama-server (default: jzaleski/cipher or jzaleski/sage)
- `FLASH_ATTN`: Boolean flag to enable flash attention mechanism for faster processing on supported hardware (default: on)
- `N_GPU_LAYERS`: Number of layers to offload to GPU (-1 for all layers, default: -1 for local, -1 for server)
- `CTX_SIZE`: Maximum number of tokens the model can process in a single context window (default: 65536 for cipher local, 196608 for cipher server, 65536 for sage local, 262144 for sage server)
- `MIN_P`: Threshold for nucleus sampling to exclude low-probability tokens (0.0-1.0)
- `PRESENCE_PENALTY`: Factor applied to penalize repeated tokens (default: 1.5)
- `REPEAT_PENALTY`: Factor applied to penalize repeated tokens (1.0 is no penalty)
- `TEMP`: Controls randomness and creativity in model responses
- `TOP_K`: Limit on the number of most likely tokens to consider during generation (0 or 0.0 disables top-k sampling)
- `TOP_P`: Controls nucleus sampling - cumulative probability threshold for token selection (0.95 default)

## Components

### run-cipher.sh
Runs the cipher model for coding assistance. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Model: `unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M`
- Alias: `jzaleski/cipher`
- Host: 127.0.0.1
- Port: 8081
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 81920 tokens
- Min P: 0.01
- Presence penalty: 1.5
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 40
- Top P: 0.95

**Server Mode Defaults:**
- Model: `unsloth/MiniMax-M2.7-GGUF:Q8_0`
- Alias: `jzaleski/cipher`
- Host: 0.0.0.0
- Port: 8081
- Flash attention: enabled
- GPU layers: -1
- Context size: 196608 tokens
- Min P: 0.01
- Presence penalty: 1.5
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 40
- Top P: 0.95

### run-cipher-experimental.sh
Stub - not implemented. Both local and server modes return an error.

### run-sage.sh
Runs the sage model for general advising. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Model: `unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M`
- Alias: `jzaleski/sage`
- Host: 127.0.0.1
- Port: 8082
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 81920 tokens
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
- Min P: 0.0
- Presence penalty: 1.5
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 20
- Top P: 0.95

### run-sage-experimental.sh
Stub - not implemented. Both local and server modes return an error.

### run-open-webui.sh
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
./bin/run-cipher.sh

# Run cipher model (server mode)
./bin/run-cipher.sh --server

# Run experimental cipher model (local mode - not implemented)
./bin/run-cipher-experimental.sh

# Run experimental cipher model (server mode - not implemented)
./bin/run-cipher-experimental.sh --server

# Run sage model (local mode)
./bin/run-sage.sh

# Run sage model (server mode)
./bin/run-sage.sh --server

# Run experimental sage model (local mode - not implemented)
./bin/run-sage-experimental.sh

# Run experimental sage model (server mode - not implemented)
./bin/run-sage-experimental.sh --server

# Start Open WebUI (local mode, auth disabled)
./bin/run-open-webui.sh

# Start Open WebUI (server mode, auth enabled)
./bin/run-open-webui.sh --server
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
│    MiniMax-M2.7    │
│      (server)      │
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
│  │ Architect      │◄─┼── default agent
│  │ [plan only]    │  │
│  └────────────────┘  │
│                      │
│  ┌────────────────┐  │
│  │ Implement      │  │
│  │ [full tools]   │  │
│  └────────────────┘  │
│                      │
│  ┌────────────────┐  │
│  │ Scribe         │  │
│  │ [docs only]    │  │
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
│  │ 65K context    │  │ │ 80K context    │
│  └────────────────┘  │ └────────────────┘
│                      │
│  ┌────────────────┐  │ ┌────────────────┐
│  │ Server Cipher  │  │ │ Server Sage    │
│  │ remote:8081    │  │ │ remote:8082    │
│  │ 196K context   │  │ │ 262K context   │
│  └────────────────┘  │ └────────────────┘
└──────────────────────┘
```

### Provider Configuration

The opencode configuration (`~/.config/opencode/opencode.json`) defines 4 provider endpoints:

| Provider | Endpoint | Model | Context | Input | Output |
|----------|----------|-------|---------|-------|--------|
| local - cipher - stable | `localhost:8081` | jzaleski/cipher | 65,536 | 57,344 | 8,192 |
| local - sage - stable | `localhost:8082` | jzaleski/sage | 81,920 | 73,728 | 8,192 |
| server - cipher - stable | `server-hostname-or-ip:8081` | jzaleski/cipher | 196,608 | 163,840 | 32,768 |
| server - sage - stable | `server-hostname-or-ip:8082` | jzaleski/sage | 262,144 | 229,376 | 32,768 |

**Modalities supported:**
- Cipher: text in/out only
- Sage: text and image in, text out

### Agent Roles

| Agent | Mode | Capabilities | Output Style |
|-------|------|--------------|--------------|
| architect | primary | Analysis, planning, no modifications | Terse bullets |
| implement | primary | Full tool access, code changes | Implementation-ready |
| scribe | primary | Documentation, prose artifacts | Clean Markdown |

### Usage

```bash
# Run opencode with default agent (architect)
opencode "your question or task"

# Specify a different agent
opencode --agent implement "implement this feature"
opencode --agent scribe "write documentation for this"
opencode --agent architect "plan out the changes needed"
```

### Configuration Notes

- `autoupdate`: disabled (manual updates only)
- `default_agent`: `architect` (optimal for coding workflow)
- Server providers use `server-hostname-or-ip` placeholder - replace with actual hostname/IP
- Input/output token limits set to optimize for local inference constraints

## Performance Tips

- GPU acceleration enabled with flash attention by default
- Use Q4 quantization for memory-constrained environments
- Context size standardized to 81920 tokens for sage and cipher local, 262144 tokens for sage server, 196608 for cipher server
- For coding tasks, use run-cipher.sh:
  - Local: Qwen3.6-35B-A3B (efficient local coding)
  - Server: MiniMax-M2.7 (powerful server-side coding)
- For general advising, use run-sage.sh:
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
