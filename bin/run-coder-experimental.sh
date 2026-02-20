#!/usr/bin/env bash

set -e;

llama-server \
  -hf "Qwen/${MODEL_VERSION:-"Qwen3-Coder-Next"}-GGUF:Q${QUANT:-5}_K_${PARAMETERS:-"M"}" \
  --alias ${ALIAS:-"jzaleski/coder-experimental"} \
  --host ${HOST:-"0.0.0.0"} \
  --port ${PORT:-"8081"} \
  --ctx-size ${CTX_SIZE:-"65536"} \
  --fit ${FIT:-"on"} \
  --flash-attn ${FLASH_ATTN:-"on"} \
  --jinja \
  --kv-unified \
  --n-gpu-layers ${N_GPU_LAYERS:-"99"} \
  --repeat-penalty ${REPEAT_PENALTY:-"1.0"} \
  --temp ${TEMP:-"1.0"} \
  --threads ${THREADS:-"32"} \
  --top-k ${TOP_K:-"40"} \
  --top-p ${TOP_P:-"0.95"};
