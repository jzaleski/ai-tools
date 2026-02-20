#!/usr/bin/env bash

set -e;

llama-server \
  -hf "unsloth/gpt-oss-${MODEL_VERSION:-"120b"}-GGUF:Q${QUANT:-5}_K_${PARAMETERS:-"M"}" \
  --alias ${ALIAS:-"jzaleski/advisor"} \
  --host ${HOST:-"0.0.0.0"} \
  --port ${PORT:-"8082"} \
  --ctx-size ${CTX_SIZE:-"16384"} \
  --fit ${FIT:-"on"} \
  --flash-attn ${FLASH_ATTN:-"on"} \
  --jinja \
  --kv-unified \
  --min-p ${MIN_P:-"0.0"} \
  --n-gpu-layers ${N_GPU_LAYERS:-"99"} \
  --temp ${TEMP:-"1.0"} \
  --threads ${THREADS:-"32"} \
  --top-k ${TOP_K:-"0.0"} \
  --top-p ${TOP_P:-"1.0"};
