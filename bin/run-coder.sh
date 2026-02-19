#!/usr/bin/env bash

set -e;

FAST=${FAST:-"true"};
if [ "$FAST" = "true" ]; then
  MODEL="unsloth/GLM-${MODEL_VERSION:-"4.7-Flash"}-GGUF:Q${QUANT:-5}_K_${PARAMETERS:-"M"}";
  MODEL_FLAGS=(
    --min-p ${MIN_P:-"0.01"} \
    --repeat-penalty ${REPEAT_PENALTY:-"1.0"} \
    --temp ${TEMP:-"0.7"} \
    --top-p ${TOP_P:-"0.95"}
  );
else
  MODEL="unsloth/${MODEL_VERSION:-"Qwen3.5-397B-A17B"}-GGUF:Q${QUANT:-5}_K_${PARAMETERS:-"M"}";
  MODEL_FLAGS=(
    --min-p ${MIN_P:-"0.0"} \
    --repeat-penalty ${REPEAT_PENALTY:-"1.0"} \
    --temp ${TEMP:-"0.6"} \
    --top-k ${TOP_K:-"20"} \
    --top-p ${TOP_P:-"0.95"}
  );
fi

llama-server \
  -hf ${MODEL} \
  --alias ${ALIAS:-"jzaleski/coder"} \
  --host ${HOST:-"0.0.0.0"} \
  --port ${PORT:-"8081"} \
  --ctx-size ${CTX_SIZE:-"65536"} \
  --fit ${FIT:-"on"} \
  --flash-attn ${FLASH_ATTN:-"on"} \
  --jinja \
  --kv-unified \
  --mlock \
  --n-gpu-layers ${N_GPU_LAYERS:-"-1"} \
  --threads ${THREADS:-"32"} \
  ${MODEL_FLAGS[@]};
