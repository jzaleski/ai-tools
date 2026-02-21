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
Runs a model for coding assistance using GLM-4.7-Flash for rapid responses.

**Default Configuration:**
- Model: `unsloth/GLM-4.7-Flash-GGUF:Q5_K_M`
- Alias: `jzaleski/coder`
- Port: 8081
- Context size: 131072 tokens
- Temperature: 0.7
- Top P: 0.95
- Top K: 40
- Min P: 0.01
- Threads: 32
- GPU layers: 99
- Flash attention: enabled
- Repeat penalty: 1.0

### run-coder-experimental.sh
Runs a model for coding assistance using Qwen3-Coder-Next for higher quality responses.

**Default Configuration:**
- Model: `unsloth/Qwen3-Coder-Next-GGUF:Q8_0`
- Alias: `jzaleski/coder-experimental`
- Port: 8081
- Context size: 262144 tokens
- Temperature: 1.0
- Top P: 0.95
- Top K: 40
- Min P: 0.01
- Threads: 32
- GPU layers: 99
- Flash attention: enabled
- Repeat penalty: 1.0

### run-advisor.sh
Runs a GPT-OSS model for general advising.

**Default Configuration:**
- Model: `unsloth/gpt-oss-120b-GGUF:Q5_K_M`
- Alias: `jzaleski/advisor`
- Port: 8082
- Context size: 16384 tokens
- Temperature: 1.0
- Top P: 1.0
- Top K: 0.0 (disabled)
- Min P: 0.0
- Threads: 32
- GPU layers: 99
- Flash attention: enabled

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

# Run coding model in experimental mode
./bin/run-coder-experimental.sh

# Run advisor model
./bin/run-advisor.sh
```

### Custom Configuration

You can override default settings via environment variables:

```bash
# Run coding model with custom settings
MODEL_NAME="GLM-4.7-Flash" \
MODEL_QUANTIZATION="Q5_K_M" \
TEMP="0.5" \
./bin/run-coder.sh
```

**Common Variables:**
- `MODEL_PROVIDER`: Provider/organization name for the model (default: unsloth)
- `MODEL_NAME`: Name of the model to load (default: GLM-4.7-Flash, Qwen3-Coder-Next, or gpt-oss-120b)
- `MODEL_QUANTIZATION`: Full quantization specification (default: Q5_K_M or Q8_0)
- `QUANT`: Determines the compression level of the model (higher values reduce file size and memory usage)
- `TEMP`: Controls randomness and creativity in model responses (lower values produce more deterministic outputs)
- `PORT`: Network port for the server to listen on for incoming connections
- `CTX_SIZE`: Maximum number of tokens the model can process in a single context window
- `N_GPU_LAYERS`: Number of model layers to offload to GPU for accelerated inference (default: 99)
- `THREADS`: Number of CPU threads allocated for parallel model processing
- `MIN_P`: Threshold for nucleus sampling to exclude low-probability tokens
- `TOP_K`: Limit on the number of most likely tokens to consider during generation (0 disables top-k sampling)
- `REPEAT_PENALTY`: Factor applied to penalize repeated tokens to reduce repetition in output
- `FLASH_ATTN`: Boolean flag to enable flash attention mechanism for faster processing on supported hardware
- `ALIAS`: Custom name to register the model with llama-server
- `HOST`: Network interface address to bind the server to (0.0.0.0 for all interfaces)
- `FIT`: Enable model fit optimization (default: on)
- `KV_UNIFIED`: Enable unified KV cache (default: on)

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
- **GLM**: Optimized for coding assistance with fast inference (GLM-4.7-Flash)
- **Qwen**: Higher quality models for complex reasoning (Qwen3-Coder-Next)
- **GPT-OSS**: General purpose advising models (gpt-oss-120b)

### Persona Tuning
Both the coder and advisor have been tuned with specific parameters:
- Coder: Balanced temperature (0.7), high top-p (0.95), low min-p (0.01), repeat penalty (1.0)
- Advisor: High temperature (1.0), maximum top-p (1.0), min-p (0.0), top-k (0.0 disabled) for creative responses

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
│  or Qwen3-Coder │
└─────────────────┘
```

## Performance Tips

- GPU acceleration is enabled by default with 99 layers offloaded
- Use quantization level 4-5 for balance between speed and quality
- Adjust context size based on your use case
- Enable flash attention for better performance on supported hardware
- For coding tasks, use run-coder.sh for rapid responses with GLM-4.7-Flash
- For complex reasoning, use run-coder-experimental.sh with Qwen-Coder-Next
- Adjust threads based on CPU cores for optimal performance
- Set `MIN_P` to 0.01 in fast mode for better response quality

## Troubleshooting

**Model not loading:**
- Ensure you have enough RAM
- Check GPU availability if using GPU layers
- Verify model name and version
- Check that you're using the correct script (run-coder.sh or run-coder-experimental.sh)

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
- For coding tasks, use run-coder.sh with GLM-4.7-Flash
- For more complex reasoning, use run-coder-experimental.sh with Qwen3-Coder-Next
- Adjust MIN_P and TOP_K values based on desired response style
- For more creative responses, increase TEMP and TOP_P on advisor model

**Memory issues:**
- Reduce CTX_SIZE for smaller context windows
- Use lower quantization (Q4 instead of Q5)
- Set N_GPU_LAYERS to a specific value instead of 99
