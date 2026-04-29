#!/usr/bin/env bash

jq_cmd=$(which jq 2> /dev/null || echo -n);
if [ -z "$jq_cmd" ]; then
  echo "Could not locate the \"jq\" binary";
  exit 1;
fi

opencode_cmd=$(which opencode 2> /dev/null || echo -n);
if [ -z "$opencode_cmd" ]; then
  echo "Could not locate the \"opencode\" binary";
  exit 1;
fi

reset_opencode_history=${RESET_OPENCODE_HISTORY:-"true"};
if [ "$reset_opencode_history" != "true" ] && [[ "$1" =~ "^(--continue|-s|--session)$" ]]; then
  reset_opencode_history="true";
fi

opencode_model_history_file="$HOME/.local/state/opencode/model.json";
if [ "$reset_opencode_history" = "true" ] && [ -e "$opencode_model_history_file" ]; then
  opencode_model_history_temp_file="$opencode_model_history_file.tmp";
  ${jq_cmd} '.recent = []' "$opencode_model_history_file" > "$opencode_model_history_temp_file" && \
    ${jq_cmd} '.variant = {}' "$opencode_model_history_temp_file" > "$opencode_model_history_file";
fi

reset_opencode_models_cache=${RESET_OPENCODE_MODELS_CACHE:-"true"};
if [ "$reset_opencode_models_cache" != "true" ] && [[ "$1" =~ "^(--continue|-s|--session)$" ]]; then
  reset_opencode_models_cache="true";
fi

opencode_models_cache_file="$HOME/.cache/opencode/models.json";
if [ "$reset_opencode_models_cache" = "true" ] && [ -e "$opencode_models_cache_file" ]; then
  rm "$opencode_models_cache_file";
fi

${opencode_cmd} "$@";
