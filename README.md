# AI Tools

Model-files and utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. It includes support for multiple models with different use cases - coding assistance and general advising.

The system has been migrated from Ollama Modelfiles to llama-server binaries for better performance and flexibility.

## Prerequisites

- Docker (for Open WebUI)
- llama-server (included in scripts)
- At least 16GB RAM (for 20B models)
- GPU support recommended for better performance

## Components

### run-coder.sh
Runs a model for coding assistance. Supports two modes:
- **Fast mode** (default): Uses GLM-4.7-Flash for rapid responses
- **Standard mode**: Uses Qwen3.5-397B-A17B for higher quality

**Default Configuration:**
- Model: `unsloth/GLM-4.7-Flash-GGUF:Q5_K_M` (fast mode)
- Port: 8081
- Context size: 32768 tokens
- Temperature: 0.7
- Top P: 0.95
- Min P: 0.01 (fast mode)
- Threads: 32
- GPU layers: All

### run-advisor.sh
Runs a GPT-OSS model for general advising.

**Default Configuration:**
- Model: `unsloth/gpt-oss-120B-GGUF:Q5_K_M`
- Port: 8082
- Context size: 16384 tokens
- Temperature: 1.0
- Top P: 1.0
- Threads: 32
- GPU layers: All

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
FAST="true" \
./bin/run-coder.sh
```

**Common Variables:**
- `MODEL_VERSION`: Model version to use
- `QUANT`: Quantization level (4-8)
- `TEMP`: Temperature setting
- `PORT`: Server port
- `CTX_SIZE`: Context window size
- `N_GPU_LAYERS`: GPU layers (-1 for all)
- `THREADS`: Number of CPU threads (default: 32)
- `FAST`: Enable fast mode (true/false) - affects model selection and parameters
- `MODEL_FAMILY`: Model family for adaptive configuration
- `MIN_P`: Minimum p value for nucleus sampling
- `TOP_K`: Top-k sampling value
- `REPEAT_PENALTY`: Repetition penalty
- `FLASH_ATTN`: Enable flash attention (default: on)

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

## Advanced Features

### Model Family Support
The system supports multiple model families with adaptive configurations:
- **GLM**: Optimized for coding assistance with fast inference
- **Qwen**: Higher quality models for complex reasoning
- **GPT-OSS**: General purpose advising models

### Persona Tuning
Both the coder and advisor have been tuned with specific parameters:
- Coder: Balanced temperature (0.7), high top-p (0.95), low min-p (0.01 in fast mode)
- Advisor: High temperature (1.0), maximum top-p (1.0) for creative responses

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
│  GPT-OSS 120B   │
└─────────────────┘
```

```
┌─────────────────┐
│    Coder Model  │ (Port 8081)
│  GLM-4.7-Flash  │
│  or Qwen3.5     │
└─────────────────┘
```

## Performance Tips

- Enable GPU layers for faster inference: `N_GPU_LAYERS=-1`
- Use quantization level 4-5 for balance between speed and quality
- Adjust context size based on your use case
- Enable flash attention for better performance on supported hardware
- For coding tasks, use fast mode (`FAST=true`) with GLM-4.7-Flash for rapid responses
- For complex reasoning, use standard mode (`FAST=false`) with Qwen3.5-397B-A17B
- Adjust threads based on CPU cores for optimal performance
- Set `MIN_P` to 0.01 in fast mode for better response quality

## Troubleshooting

**Model not loading:**
- Ensure you have enough RAM
- Check GPU availability if using GPU layers
- Verify model name and version
- Check that FAST mode is set correctly based on available models

**Slow inference:**
- Enable GPU acceleration
- Reduce quantization level
- Decrease context size
- Enable flash attention
- Adjust THREADS based on CPU capacity

**WebUI connection issues:**
- Verify advisor model is running on configured port
- Check firewall settings
- Ensure Docker can reach host.docker.internal
- Verify OPENAI_API_BASE_URL is correctly set in docker-compose-files/open-webui.yml

**Quality issues:**
- For coding tasks, ensure FAST=true for GLM-4.7-Flash
- Adjust MIN_P and TOP_K values based on desired response style
- For more creative responses, increase TEMP and TOP_P on advisor model

**Memory issues:**
- Reduce CTX_SIZE for smaller context windows
- Use lower quantization (Q4 instead of Q5)
- Set N_GPU_LAYERS to a specific value instead of -1
