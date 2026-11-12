#!/usr/bin/env bash
#
# opencode wrapper script (OpenCode 2.x)
#
# This script wraps the opencode CLI to provide additional functionality:
#   1. Always runs with a private server (--standalone) instead of the shared
#      background service, so concurrent sessions across projects stay isolated
#      and each one sees its own environment (see #3)
#   2. Starts every session clean: clears recent models, favorite models, and
#      saved variant selections (configurable via RESET_OPENCODE_HISTORY)
#   3. Reads default model/agent values from .opencode-config (JSON) files and
#      passes them to OpenCode via OPENCODE_CONFIG_CONTENT. Files are layered,
#      closest wins: ~/.opencode-config < <repo-root>/.opencode-config <
#      <current-dir>/.opencode-config
#   4. Persists the last session ID to .last-opencode-session in the repo root
#      and resumes it via --continue, which keeps working even after the repo
#      is moved to a different location on the filesystem
#
# Why OPENCODE_CONFIG_CONTENT: the OpenCode 2.x TUI no longer accepts --model or
# --agent. Config content is read by the server, which is why --standalone
# matters: a private server inherits this process's environment, whereas the
# shared background service would not.
#
# .opencode-config format (all keys optional):
#   { "model": "provider/model", "agent": "agent-name" }
#
# Precedence (lowest to highest): .opencode-config files, a pre-existing
# OPENCODE_CONFIG_CONTENT, then --model/--agent passed on the command line.
#
# Subcommand handling:
#   (none)      full treatment (#1-#4)
#   run, mini   #1-#3; their native --model/--agent flags still win
#   others      passed through to opencode untouched

# jq programs below use jq's own $variables inside single quotes.
# shellcheck disable=SC2016

# =============================================================================
# BINARY VALIDATION
# =============================================================================

jq_cmd=$(command -v jq 2> /dev/null || echo -n);
if [ -z "$jq_cmd" ]; then
  echo "Could not locate the \"jq\" binary" >&2;
  exit 1;
fi

opencode_cmd=$(command -v opencode 2> /dev/null || echo -n);
if [ -z "$opencode_cmd" ]; then
  echo "Could not locate the \"opencode\" binary" >&2;
  exit 1;
fi

# Optional: only used to locate the repo root.
git_cmd=$(command -v git 2> /dev/null || echo -n);

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================
# RESET_OPENCODE_HISTORY:
#   - "true" (default): clear recent models, favorites, and variant selections
#   - "false": preserve them across sessions

reset_opencode_history=${RESET_OPENCODE_HISTORY:-"true"};

# =============================================================================
# ARGUMENT CLASSIFICATION
# =============================================================================
# Find the subcommand (if any) and the optional directory positional. Flags
# that take a separate value are skipped along with their value so the value
# is never mistaken for a positional.

subcommands=" upgrade update uninstall acp api debug auth mcp plugin models stats mini run session service reload pair serve ";
value_flags=" --session -s --prompt --server --log-level --completions --model -m --agent ";

mode="tui";
subcommand_index=-1;
target_dir="$PWD";

args=("$@");
i=0;
while [ "$i" -lt "${#args[@]}" ]; do
  arg=${args[$i]};
  if [[ "$arg" == "--" ]]; then
    break;
  elif [[ "$value_flags" == *" $arg "* ]]; then
    i=$((i + 1));
  elif [[ "$arg" != -* ]]; then
    if [[ "$subcommands" == *" $arg "* ]]; then
      subcommand_index=$i;
      case "$arg" in
        run|mini) mode="$arg" ;;
        *)        mode="passthrough" ;;
      esac
    elif [ -d "$arg" ]; then
      target_dir=$(cd "$arg" && pwd);
    fi
    break;
  fi
  i=$((i + 1));
done

if [ "$mode" = "passthrough" ]; then
  exec "$opencode_cmd" "$@";
fi

# =============================================================================
# PATHS
# =============================================================================

repo_root="";
if [ -n "$git_cmd" ]; then
  repo_root=$("$git_cmd" -C "$target_dir" rev-parse --show-toplevel 2> /dev/null || echo -n);
fi

opencode_session_file="${repo_root:-$target_dir}/.last-opencode-session";
opencode_model_state_file="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/model.json";

# =============================================================================
# ARGUMENT REWRITING
# =============================================================================
# For the TUI: --model/--agent are stripped and folded into config content, and
# --continue/-c becomes --session <persisted-id> when one is available (if not,
# OpenCode's native --continue is used). For run/mini, arguments are untouched.
# Either way, --standalone is added unless --standalone or --server is present.

cli_model="";
cli_agent="";
has_standalone_arg=0;
has_server_url_arg=0;
new_args=();
i=0;
while [ "$i" -lt "${#args[@]}" ]; do
  arg=${args[$i]};
  next=${args[$((i + 1))]:-};

  if [[ "$arg" == "--" ]]; then
    new_args+=("${args[@]:$i}");
    break;
  fi

  case "$arg" in
    --standalone)         has_standalone_arg=1 ;;
    --server|--server=*)  has_server_url_arg=1 ;;
  esac

  if [ "$mode" = "tui" ]; then
    case "$arg" in
      --model|-m) cli_model=$next; i=$((i + 2)); continue ;;
      --model=*)  cli_model=${arg#--model=}; i=$((i + 1)); continue ;;
      --agent)    cli_agent=$next; i=$((i + 2)); continue ;;
      --agent=*)  cli_agent=${arg#--agent=}; i=$((i + 1)); continue ;;
      --continue|-c)
        if [ -s "$opencode_session_file" ]; then
          session_id=$(< "$opencode_session_file");
          if [ -n "$session_id" ]; then
            new_args+=(--session "$session_id");
            i=$((i + 1));
            continue;
          fi
        fi
        ;;
    esac
  fi

  new_args+=("$arg");
  i=$((i + 1));
done

if [ "$has_standalone_arg" -eq 0 ] && [ "$has_server_url_arg" -eq 0 ]; then
  if [ "$subcommand_index" -ge 0 ]; then
    # Insert right after the subcommand so it is never swallowed by a
    # positional message (e.g. `opencode run "..."`).
    new_args=("${new_args[@]:0:$((subcommand_index + 1))}" --standalone "${new_args[@]:$((subcommand_index + 1))}");
  else
    new_args=(--standalone "${new_args[@]}");
  fi
fi

# =============================================================================
# CONFIG CONTENT (MODEL/AGENT)
# =============================================================================
# Layer .opencode-config files (home < repo root < target dir; duplicates
# skipped), then any pre-existing OPENCODE_CONFIG_CONTENT, then CLI flags.
# Invalid files are reported to stderr and ignored.

config_content='{}';

merge_config() { # $1 = JSON object to merge over config_content
  config_content=$("$jq_cmd" -cn --argjson a "$config_content" --argjson b "$1" '$a * $b');
}

seen_config_files=" ";
for config_dir in "$HOME" "$repo_root" "$target_dir"; do
  [ -n "$config_dir" ] || continue;
  config_file="$config_dir/.opencode-config";
  [ -f "$config_file" ] || continue;
  config_real=$(cd "$config_dir" && pwd -P)/.opencode-config;
  [[ "$seen_config_files" == *" $config_real "* ]] && continue;
  seen_config_files+="$config_real ";

  if layer=$("$jq_cmd" -ce '
      if type != "object" then error("not an object") else . end
      | {model: .model, default_agent: .agent}
      | with_entries(select(.value | type == "string" and length > 0))
    ' "$config_file" 2> /dev/null); then
    merge_config "$layer";
  else
    echo "Warning: $config_file contains invalid JSON, ignoring" >&2;
  fi
done

if [ -n "${OPENCODE_CONFIG_CONTENT:-}" ]; then
  if "$jq_cmd" -e 'type == "object"' <<< "$OPENCODE_CONFIG_CONTENT" > /dev/null 2>&1; then
    merge_config "$OPENCODE_CONFIG_CONTENT";
  else
    echo "Warning: OPENCODE_CONFIG_CONTENT is not a JSON object, ignoring" >&2;
  fi
fi

if [ -n "$cli_model" ]; then
  merge_config "$("$jq_cmd" -cn --arg v "$cli_model" '{model: $v}')";
fi
if [ -n "$cli_agent" ]; then
  merge_config "$("$jq_cmd" -cn --arg v "$cli_agent" '{default_agent: $v}')";
fi

if [ "$config_content" != '{}' ]; then
  export OPENCODE_CONFIG_CONTENT="$config_content";
fi

# =============================================================================
# MODEL STATE RESET
# =============================================================================
# Clear recent models, favorites, and variant selections so each session starts
# clean. Other keys are preserved. Written via a temp file + mv so a failed jq
# never truncates the state file.

if [ "$reset_opencode_history" = "true" ] && [ -f "$opencode_model_state_file" ]; then
  model_state_tmp=$(mktemp "$opencode_model_state_file.XXXXXX") && \
    if "$jq_cmd" '.recent = [] | .favorite = [] | .variant = {}' "$opencode_model_state_file" > "$model_state_tmp"; then
      mv "$model_state_tmp" "$opencode_model_state_file";
    else
      rm -f "$model_state_tmp";
    fi
fi

# =============================================================================
# EXECUTE OPENCODE
# =============================================================================

if [ "$mode" != "tui" ]; then
  exec "$opencode_cmd" "${new_args[@]}";
fi

"$opencode_cmd" "${new_args[@]}";
opencode_status=$?;

# =============================================================================
# SESSION PERSISTENCE (POST-EXECUTION)
# =============================================================================
# Ask OpenCode for the project's most recently updated top-level session in the
# target directory and persist its ID, enabling future --continue calls. Skipped
# when connected to an explicit --server (its sessions may live elsewhere).

if [ "$has_server_url_arg" -eq 0 ]; then
  target_dir_physical=$(cd "$target_dir" && pwd -P);
  session_id=$(cd "$target_dir" && "$opencode_cmd" session list --format json --standalone 2> /dev/null | \
    "$jq_cmd" -r --arg l "$target_dir" --arg p "$target_dir_physical" \
      '[.[] | select(.directory == $l or .directory == $p)] | first | .id // empty' 2> /dev/null);
  if [ -n "$session_id" ]; then
    echo "$session_id" > "$opencode_session_file";
  fi
fi

exit "$opencode_status";
