#!/usr/bin/env bash

set -e;

ADVISOR_MODEL_PORT=${ADVISOR_MODEL_PORT:-"8082"};
IMAGE=${IMAGE:-"ghcr.io/open-webui/open-webui:main"};
PORT=${PORT:-"8080"};

docker pull ${IMAGE} && \
  docker compose -f $(dirname $0)/../docker-compose-files/open-webui.yml up;
