#!/usr/bin/env bash

set -e;

run_local() {
  echo "Error: Not Implemented!" >&2;
  exit 1;
}

run_server() {
  llama-server \
    -hf "${MODEL_PROVIDER:-"unsloth"}/${MODEL_NAME:-"Qwen3-Coder-Next"}-GGUF:${MODEL_QUANTIZATION:-"Q8_0"}" \
    --alias ${ALIAS:-"jzaleski/coder"} \
    --host ${HOST:-"0.0.0.0"} \
    --port ${PORT:-"8081"} \
    --flash-attn ${FLASH_ATTN:-"on"} \
    --jinja \
    --n-gpu-layers "${N_GPU_LAYERS:-"-1"}" \
    --ctx-size ${CTX_SIZE:-"262144"} \
    --min-p ${MIN_P:-"0.01"} \
    --repeat-penalty ${REPEAT_PENALTY:-"1.0"} \
    --temp ${TEMP:-"1.0"} \
    --top-k ${TOP_K:-"40"} \
    --top-p ${TOP_P:-"0.95"};
}

# Default to local mode if no flag provided
if [[ "${1:-}" == "--server" ]]; then
  run_server
else
  run_local
fi
