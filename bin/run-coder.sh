#!/usr/bin/env bash

set -e;

run_local() {
  llama-server \
    -hf "${MODEL_PROVIDER:-"unsloth"}/${MODEL_NAME:-"Qwen3-Coder-Next"}-GGUF:${MODEL_QUANTIZATION:-"Q4_K_M"}" \
    --alias ${ALIAS:-"jzaleski/coder"} \
    --host ${HOST:-"127.0.0.1"} \
    --port ${PORT:-"8081"} \
    --flash-attn ${FLASH_ATTN:-"on"} \
    --jinja \
    --n-gpu-layers "${N_GPU_LAYERS:-"-1"}" \
    --ctx-size ${CTX_SIZE:-"65536"} \
    --min-p ${MIN_P:-"0.01"} \
    --presence-penalty "${PRESENCE_PENALTY:-"1.5"}" \
    --repeat-penalty ${REPEAT_PENALTY:-"1.0"} \
    --temp ${TEMP:-"1.0"} \
    --top-k ${TOP_K:-"40"} \
    --top-p ${TOP_P:-"0.95"};
}

run_server() {
  llama-server \
    -hf "${MODEL_PROVIDER:-"unsloth"}/${MODEL_NAME:-"MiniMax-M2.5"}-GGUF:${MODEL_QUANTIZATION:-"Q8_0"}" \
    --alias ${ALIAS:-"jzaleski/coder"} \
    --host ${HOST:-"0.0.0.0"} \
    --port ${PORT:-"8081"} \
    --flash-attn ${FLASH_ATTN:-"on"} \
    --jinja \
    --n-gpu-layers "${N_GPU_LAYERS:-"-1"}" \
    --ctx-size ${CTX_SIZE:-"196608"} \
    --min-p ${MIN_P:-"0.01"} \
    --presence-penalty "${PRESENCE_PENALTY:-"1.5"}" \
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
