#!/usr/bin/env bash

set -e;

SAGE_MODEL_PORT=${SAGE_MODEL_PORT:-"8082"};
IMAGE=${IMAGE:-"ghcr.io/open-webui/open-webui:main"};
PORT=${PORT:-"8080"};

run_local() {
  docker pull ${IMAGE} && \
    WEBUI_AUTH=False docker compose -f $(dirname $0)/../docker-compose-files/open-webui.yml up;
}

run_server() {
  docker pull ${IMAGE} && \
    WEBUI_AUTH=True docker compose -f $(dirname $0)/../docker-compose-files/open-webui.yml up;
}

# Default to local mode if no flag provided
if [[ "${1:-}" == "--server" ]]; then
  run_server
else
  run_local
fi
