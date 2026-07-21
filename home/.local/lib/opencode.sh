#!/usr/bin/env bash
#
# opencode wrapper script
#
# This script wraps the opencode CLI to provide additional functionality:
#   1. Persists the last session ID to .last-opencode-session in the repo root
#   2. Resumes sessions via --continue by reading the persisted session ID
#   3. Resets opencode history/cache on new sessions (configurable via env vars)
#   4. Reads default --model/--agent values from .opencode-config (JSON) in
#      the repo root if present, applied only when not already passed on
#      the command line
#
# The session persistence enables resuming sessions even after moving the repo
# to a different location on the filesystem, which is useful when working across
# multiple repositories.

# =============================================================================
# BINARY VALIDATION
# =============================================================================
# Ensure all required binaries are available before proceeding. Each check
# exits with an error if the binary cannot be located in PATH.

cat_cmd=$(which cat 2> /dev/null || echo -n);
if [ -z "$cat_cmd" ]; then
  echo "Could not locate the \"cat\" binary";
  exit 1;
fi

git_cmd=$(which git 2> /dev/null || echo -n);
if [ -z "$git_cmd" ]; then
  echo "Could not locate the \"git\" binary";
  exit 1;
fi

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

sqlite3_cmd=$(which sqlite3 2> /dev/null || echo -n);
if [ -z "$sqlite3_cmd" ]; then
  echo "Could not locate the \"sqlite3\" binary";
  exit 1;
fi

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================
# Configure behavior via environment variables. Default values are used if
# the variables are not set.
#
# RESET_OPENCODE_HISTORY:
#   - "true" (default): Clear model history on new sessions
#   - "false": Preserve model history across sessions (ignored for --continue)
#
# RESET_OPENCODE_MODELS_CACHE:
#   - "true" (default): Clear models cache on new sessions
#   - "false": Preserve models cache across sessions (ignored for --continue)

reset_opencode_history=${RESET_OPENCODE_HISTORY:-"true"};
reset_opencode_models_cache=${RESET_OPENCODE_MODELS_CACHE:-"true"};

# =============================================================================
# HISTORY/CACHE RESET LOGIC
# =============================================================================
# Force reset of history and cache when continuing a session. This ensures
# a clean state when resuming, regardless of the environment variable settings.
# The regex matches: --continue, -s, or --session

if [ "$reset_opencode_history" != "true" ] && [[ "$1" =~ "^(--continue|-s|--session)$" ]]; then
  reset_opencode_history="true";
fi

if [ "$reset_opencode_models_cache" != "true" ] && [[ "$1" =~ "^(--continue|-s|--session)$" ]]; then
  reset_opencode_models_cache="true";
fi

# =============================================================================
# SESSION PERSISTENCE CONFIGURATION
# =============================================================================
# Determine where to store the session ID file. We use the git repo root if
# available, falling back to the current directory if not in a git repo.
# This allows the session file to travel with the repo when moved.

opencode_db_file="$HOME/.local/share/opencode/opencode.db";
opencode_session_file="$(${git_cmd} rev-parse --show-toplevel 2> /dev/null || pwd)/.last-opencode-session";

# =============================================================================
# SESSION RESUMPTION (--continue HANDLING)
# =============================================================================
# When --continue is invoked, we read the persisted session ID from the file
# and convert it to --session <id>. This allows resuming sessions even after
# the repo has been moved to a different filesystem location.
#
# Flow:
#   1. Check if --continue was passed
#   2. Check if .last-opencode-session file exists
#   3. Read the session ID from the file
#   4. Replace --continue with --session <id> in the argument list

if [[ "$1" == "--continue" ]] && [[ -e "$opencode_session_file" ]]; then
  session_id=$(${cat_cmd} "$opencode_session_file" 2> /dev/null);
  if [[ -n "$session_id" ]]; then
    # Remove --continue from args and replace with --session <id>
    shift;
    set -- --session "$session_id" "$@";
  fi
fi

# =============================================================================
# MODEL HISTORY RESET
# =============================================================================
# Clear the recent model history and variant selection. This ensures a fresh
# model selection state for each new session. The model history file tracks
# recently used models and the current variant selection.

opencode_model_history_file="$HOME/.local/state/opencode/model.json";
if [ "$reset_opencode_history" = "true" ] && [ -e "$opencode_model_history_file" ]; then
  opencode_model_history_temp_file="$opencode_model_history_file.tmp";
  ${jq_cmd} '.recent = []' "$opencode_model_history_file" > "$opencode_model_history_temp_file" && \
    ${jq_cmd} '.variant = {}' "$opencode_model_history_temp_file" > "$opencode_model_history_file";
fi

# =============================================================================
# MODELS CACHE RESET
# =============================================================================
# Remove the models cache file if it exists. This forces opencode to fetch
# fresh model information from the providers on the next session.

opencode_models_cache_file="$HOME/.cache/opencode/models.json";
if [ "$reset_opencode_models_cache" = "true" ] && [ -e "$opencode_models_cache_file" ]; then
  rm "$opencode_models_cache_file";
fi

# =============================================================================
# DEFAULT MODEL/AGENT CONFIGURATION
# =============================================================================
# Read default --model and --agent values from .opencode-config (JSON) in the
# repo root (or pwd) if it exists, and append them to the opencode arguments
# for any flag not already specified on the command line. Invalid JSON is
# reported as a warning to stderr and otherwise ignored (the underlying
# opencode command still runs normally, falling through to CLI flags and
# opencode.json defaults).

opencode_config_file="$(${git_cmd} rev-parse --show-toplevel 2> /dev/null || pwd)/.opencode-config";

has_model_arg=0;
has_agent_arg=0;
for arg in "$@"; do
  if [[ "$arg" == "--model" ]] || [[ "$arg" == "-m" ]]; then
    has_model_arg=1;
  fi
  if [[ "$arg" == "--agent" ]]; then
    has_agent_arg=1;
  fi
done

if [[ -e "$opencode_config_file" ]]; then
  if ${jq_cmd} empty "$opencode_config_file" 2> /dev/null; then
    opencode_config_model=$(${jq_cmd} -r '.model // empty' "$opencode_config_file" 2> /dev/null);
    opencode_config_agent=$(${jq_cmd} -r '.agent // empty' "$opencode_config_file" 2> /dev/null);

    if [[ "$has_model_arg" -eq 0 ]] && [[ -n "$opencode_config_model" ]]; then
      set -- "$@" --model "$opencode_config_model";
    fi

    if [[ "$has_agent_arg" -eq 0 ]] && [[ -n "$opencode_config_agent" ]]; then
      set -- "$@" --agent "$opencode_config_agent";
    fi
  else
    echo "Warning: .opencode-config contains invalid JSON, ignoring" >&2;
  fi
fi

# =============================================================================
# EXECUTE OPENCODE
# =============================================================================
# Run the actual opencode command with all arguments (potentially modified
# if --continue was converted to --session above).

${opencode_cmd} "$@";

# =============================================================================
# SESSION PERSISTENCE (POST-EXECUTION)
# =============================================================================
# After opencode exits, query the database for the most recent session in the
# current directory and persist it to .last-opencode-session. This enables
# future --continue calls to find the session even if the repo is moved.
#
# The session table stores: id, directory, time_created, etc.
# We query by directory to find sessions for this specific repo.

if [[ -e "$opencode_db_file" ]]; then
  session_id=$(${sqlite3_cmd} "$opencode_db_file" "SELECT id FROM session WHERE directory = '$(pwd)' ORDER BY time_created DESC LIMIT 1;" 2> /dev/null);
  if [[ -n "$session_id" ]]; then
    echo "$session_id" > "$opencode_session_file";
  fi
fi
