#!/usr/bin/env bash

set -e;

run_local() {
  echo "Error: Not Implemented!" >&2;
  exit 1;
}

run_server() {
  echo "Error: Not Implemented!" >&2;
  exit 1;
}

# Default to local mode if no flag provided
if [[ "${1:-}" == "--server" ]]; then
  run_server
else
  run_local
fi
