# AI Tools

Model-files and utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. It includes support for multiple models with different use cases - coding assistance and general advising.

## Prerequisites

- Docker (for Open WebUI)
- llama-server (included in scripts)
- At least 16GB RAM (for 20B models)
- GPU support recommended for better performance

## Components

### run-coder.sh
Runs a GLM-4.7-Flash model for coding assistance.

**Default Configuration:**
- Model: `unsloth/GLM-4.7-Flash-GGUF:Q5_K_M`
- Port: 8081
- Context size: 65536 tokens
- Temperature: 0.7
- Top P: 0.95

### run-advisor.sh
Runs a GPT-OSS 20B model for general advising.

**Default Configuration:**
- Model: `unsloth/gpt-oss-20B-GGUF:Q5_K_M`
- Port: 8082
- Context size: 16384 tokens
- Temperature: 1.0

### run-open-webui.sh
Starts Open WebUI interface connected to the advisor model.

**Default Configuration:**
- Port: 8080
- Connects to advisor model on port 8082

## Usage

### Running Individual Models

```bash
# Run coding model
./bin/run-coder.sh

# Run advisor model
./bin/run-advisor.sh
```

### Custom Configuration

You can override default settings via environment variables:

```bash
# Run coding model with custom settings
MODEL_VERSION="4.7-Flash" \
QUANT="4" \
TEMP="0.5" \
./bin/run-coder.sh
```

**Common Variables:**
- `MODEL_VERSION`: Model version to use
- `QUANT`: Quantization level (4-8)
- `TEMP`: Temperature setting
- `PORT`: Server port
- `CTX_SIZE`: Context window size
- `N_GPU_LAYERS`: GPU layers (-1 for all)

### Running Open WebUI

```bash
# Start with default settings
./bin/run-open-webui.sh

# Or with custom advisor port
ADVISOR_MODEL_PORT=8083 \
./bin/run-open-webui.sh
```

Access the web interface at `http://localhost:8080`

## Docker Compose

Open WebUI can also be managed via Docker Compose:

```bash
docker compose -f docker-compose-files/open-webui.yml up
```

Stop with:
```bash
docker compose -f docker-compose-files/open-webui.yml down
```

## Model Files

The `model-files` directory contains additional model configurations and utilities.

## Architecture

```
┌─────────────────┐
│   Open WebUI    │ (Port 8080)
│                 │
│  ┌───────────┐  │
│  │  Client   │  │
│  └─────┬─────┘  │
└────────┼────────┘
         │
         ▼
┌─────────────────┐
│  Advisor Model  │ (Port 8082)
│  GPT-OSS 20B    │
└─────────────────┘
```

## Performance Tips

- Enable GPU layers for faster inference: `N_GPU_LAYERS=-1`
- Use quantization level 4-5 for balance between speed and quality
- Adjust context size based on your use case
- Enable flash attention for better performance on supported hardware

## Troubleshooting

**Model not loading:**
- Ensure you have enough RAM
- Check GPU availability if using GPU layers
- Verify model name and version

**Slow inference:**
- Enable GPU acceleration
- Reduce quantization level
- Decrease context size
- Enable flash attention

**WebUI connection issues:**
- Verify advisor model is running on configured port
- Check firewall settings
- Ensure Docker can reach host.docker.internal
