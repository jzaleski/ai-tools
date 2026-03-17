#!/usr/bin/env bash

set -e;

run_local() {
  echo "Error: Not Implemented!" >&2;
  exit 1;
}

run_server() {
  llama-server \
    -hf "${MODEL_PROVIDER:-"unsloth"}/${MODEL_NAME:-"MiniMax-M2.5"}-GGUF:${MODEL_QUANTIZATION:-"Q8_0"}" \
    --alias ${ALIAS:-"jzaleski/coder-experimental"} \
    --host ${HOST:-"0.0.0.0"} \
    --port ${PORT:-"9081"} \
    --flash-attn ${FLASH_ATTN:-"on"} \
    --jinja \
    --n-gpu-layers "${N_GPU_LAYERS:-"-1"}" \
    --ctx-size ${CTX_SIZE:-"196608"} \
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
