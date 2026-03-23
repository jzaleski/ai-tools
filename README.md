# AI Tools

Utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. It includes support for multiple models with different use cases - coding assistance and general advising.

Models are loaded from HuggingFace and quantized for efficient local inference.

## Project Structure

```
.
├── bin/                       # Main execution scripts
│   ├── bootstrap.sh           # System setup and configuration bootstrap
│   ├── run-coder.sh           # Coder model server (GLM-4.7-Flash/Qwen3-Coder-Next)
│   ├── run-coder-experimental.sh  # Experimental coder (MiniMax-M2.5, server-only)
│   ├── run-advisor.sh         # Advisor model server (gpt-oss-20b/gpt-oss-120b)
│   ├── run-advisor-experimental.sh # Experimental advisor (stub, not implemented)
│   └── run-open-webui.sh      # Open WebUI Docker wrapper
├── scripts/                   # Bootstrap scripts (executed by bin/bootstrap.sh)
├── home/                      # Dotfiles and config files to symlink
├── overrides/                 # Override files for home directory
├── docker-compose-files/
│   └── open-webui.yml         # Docker Compose configuration for Open WebUI
├── .default-node-version      # Default node version
├── .default-npm-version       # Default npm version
├── .default-opencode-version  # Default opencode-ai version
└── .bootstrapignore           # Files to skip during bootstrap (git-ignored)
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
| `.default-npm-version` | npm version | 11.9.0 |
| `.default-opencode-version` | opencode-ai version | 1.2.27 |

These versions are managed and installed via the bootstrap system

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **build.md**: Build agent with full tool access for implementing changes
- **plan.md**: Planning agent for analysis and implementation planning (no file modifications)

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance.

## Environment Variables

You can override default settings via environment variables. The same variables apply to both local and server modes. Environment defaults differ between local and server modes as shown in the Components section.

**Common Variables:**
- `MODEL_PROVIDER`: Provider/organization name for the model (default: unsloth)
- `MODEL_NAME`: Name of the model to load (no -GGUF suffix, defaults to local/server mode below)
- `MODEL_QUANTIZATION`: Full quantization specification (default: Q4_K_M for local, Q4_K_M+ for server)
- `HOST`: Network interface address to bind the server to (default: 127.0.0.1 for local, 0.0.0.0 for server)
- `PORT`: Network port for the server to listen on for incoming connections (default: 8081 for coder, 8082 for advisor, 8080 for WebUI)
- `ALIAS`: Custom name to register the model with llama-server (default: jzaleski/coder or jzaleski/advisor)
- `FLASH_ATTN`: Boolean flag to enable flash attention mechanism for faster processing on supported hardware (default: on)
- `N_GPU_LAYERS`: Number of layers to offload to GPU (-1 for all layers, default: -1)
- `CTX_SIZE`: Maximum number of tokens the model can process in a single context window (default: 65536 for local, 65536+ for server)
- `MIN_P`: Threshold for nucleus sampling to exclude low-probability tokens (0.0-1.0)
- `REPEAT_PENALTY`: Factor applied to penalize repeated tokens (1.0 is no penalty)
- `TEMP`: Controls randomness and creativity in model responses
- `TOP_K`: Limit on the number of most likely tokens to consider during generation (0 or 0.0 disables top-k sampling)
- `TOP_P`: Controls nucleus sampling - cumulative probability threshold for token selection (0.95 default)

## Components

### run-coder.sh
Runs the default model for coding assistance. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Model: `unsloth/GLM-4.7-Flash-GGUF:Q4_K_M`
- Alias: `jzaleski/coder`
- Host: 127.0.0.1
- Port: 8081
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 65536 tokens
- Min P: 0.01
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 40
- Top P: 0.95

**Server Mode Defaults:**
- Model: `unsloth/Qwen3-Coder-Next-GGUF:Q8_0`
- Alias: `jzaleski/coder`
- Host: 0.0.0.0
- Port: 8081
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 262144 tokens
- Min P: 0.01
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 40
- Top P: 0.95

### run-coder-experimental.sh
Runs the experimental model for coding assistance. Supports only server mode via `--server` flag.

**Server Mode Defaults:**
- Model: `unsloth/MiniMax-M2.5-GGUF:Q8_0`
- Alias: `jzaleski/coder-experimental`
- Host: 0.0.0.0
- Port: 9081
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 196608 tokens
- Min P: 0.01
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 40
- Top P: 0.95

### run-advisor.sh
Runs the default model for general advising. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Model: `unsloth/gpt-oss-20b-GGUF:Q4_K_M`
- Alias: `jzaleski/advisor`
- Host: 127.0.0.1
- Port: 8082
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 65536 tokens
- Min P: 0.0
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 0.0
- Top P: 1.0

**Server Mode Defaults:**
- Model: `unsloth/gpt-oss-120b-GGUF:Q8_0`
- Alias: `jzaleski/advisor`
- Host: 0.0.0.0
- Port: 8082
- Flash attention: enabled
- GPU layers: -1 (All)
- Context size: 65536 tokens
- Min P: 0.0
- Repeat penalty: 1.0
- Temperature: 1.0
- Top K: 0.0
- Top P: 1.0

### run-advisor-experimental.sh
Runs the experimental model for general advising. Currently a stub - both local and server modes are not implemented. 

### run-open-webui.sh
Starts Open WebUI interface using Docker. Supports both local and server modes via `--server` flag.

**Local Mode Defaults:**
- Port: 8080
- Auth: disabled
- Uses advisor model on port 8082

**Server Mode Defaults:**
- Port: 8080
- Auth: enabled
- Uses advisor model on port 8082

**Environment Variables:**
- `WEBUI_AUTH`: Enable authentication in WebUI (default: False for local, True for server)
- `ADVISOR_MODEL_PORT`: Custom advisor model port (default: 8082)
- `IMAGE`: Docker image to use (default: ghcr.io/open-webui/open-webui:main)

## Usage

### Running Individual Models

```bash
# Run coding model (local mode)
./bin/run-coder.sh

# Run coding model (server mode)
./bin/run-coder.sh --server

# Run experimental coding model (local mode -- not implemented)
./bin/run-coder-experimental.sh

# Run experimental coding model (server mode)
./bin/run-coder-experimental.sh --server

# Run advisor model (local mode)
./bin/run-advisor.sh

# Run advisor model (server mode)
./bin/run-advisor.sh --server

# Run experimental advisor model (local mode - not implemented)
./bin/run-advisor-experimental.sh

# Run experimental advisor model (server mode - not implemented)
./bin/run-advisor-experimental.sh --server

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
│   gpt-oss-20b /  │
│   gpt-oss-120b   │
└──────────────────┘
```

```
┌──────────────────┐
│   Coder Model    │ (Port 8081)
│  GLM-4.7-Flash   │
│ Qwen3-Coder-Next │
└──────────────────┘
```

```
┌──────────────────────────────┐
│  Coder Model (Experimental)  │ (Port 9081)
│         MiniMax-M2.5         │
│        (server-only)         │
└──────────────────────────────┘
```

## Performance Tips

- GPU acceleration enabled with flash attention by default
- Use Q4 quantization for memory-constrained environments
- Context size standardized to 65536+ tokens
- For coding tasks, use run-coder.sh with GLM-4.7-Flash (local) or Qwen3-Coder-Next (server)
- For complex reasoning, use run-advisor.sh with gpt-oss-20b (local) or gpt-oss-120b (server)

## Troubleshooting

**Bootstrap issues:**
- Check `.bootstrapignore` for files causing conflicts
- Run with `ASSUME_YES=true` for non-interactive mode

**Model not loading:**
- Ensure you have enough RAM
- Verify model name and quantization

**Slow inference:**
- Enable flash attention
- Reduce context size
- Adjust quantization level

**WebUI connection issues:**
- Verify advisor model is running on configured port
- Check firewall settings
- Ensure Docker can reach host.docker.internal

**Quality issues:**
- Adjust `MIN_P` and `TOP_K` values based on desired response style (0 or 0.0 disables these sampling methods)
- For more creative responses, increase `TEMP` and `TOP_P` on advisor model

**Memory issues:**
- Reduce `CTX_SIZE` for smaller context windows
- Use lower quantization (recommend Q4 as the minimum to balance accuracy and
  speed)
