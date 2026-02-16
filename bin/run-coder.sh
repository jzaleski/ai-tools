#!/usr/bin/env bash

set -e;

MODEL=${MODEL:-"unsloth/GLM-${MODEL_VERSION:-"4.7-Flash"}-GGUF:Q${QUANT:-5}_K_${PARAMETERS:-"M"}"};
ALIAS=${ALIAS:-"jzaleski/coder"};

HOST=${HOST:-"0.0.0.0"};
PORT=${PORT:-"8081"};

CTX_SIZE=${CTX_SIZE:-"65536"};
FIT=${FIT:-"on"};
FLASH_ATTN=${FLASH_ATTN:-"on"};
MIN_P=${MIN_P:-"0.01"};
N_GPU_LAYERS=${N_GPU_LAYERS:-"-1"};
REPEAT_PENALTY=${REPEAT_PENALTY:-"1.0"}
TEMP=${TEMP:-"0.55"};
TOP_K=${TOP_K:-"30"};
TOP_P=${TOP_P:-"0.9"};

llama-server \
  -hf ${MODEL} \
  --alias ${ALIAS} \
  --host ${HOST} \
  --port ${PORT} \
  --jinja \
  --kv-unified \
  --mlock \
  --ctx-size ${CTX_SIZE} \
  --fit ${FIT} \
  --flash-attn ${FLASH_ATTN} \
  --min-p ${MIN_P} \
  --n-gpu-layers ${N_GPU_LAYERS} \
  --repeat-penalty ${REPEAT_PENALTY} \
  --temp ${TEMP} \
  --top-k ${TOP_K} \
  --top-p ${TOP_P};
