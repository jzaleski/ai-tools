#!/usr/bin/env bash
# Test harness for home/.local/lib/opencode.sh using a stub `opencode` binary.
# Usage: bash tests/test_opencode_wrapper.sh  (WRAPPER=<path> to test another copy)
set -u
# Isolate from any wrapper-exported config in the calling shell.
unset OPENCODE_CONFIG_CONTENT OPENCODE_CLI_CONFIG_CONTENT

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${WRAPPER:-$repo_root/home/.local/lib/opencode.sh}"
work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/home/.local/state/opencode" "$work/repo/sub" "$work/plain"
git -C "$work/repo" init -q

# Stub opencode: logs argv + OPENCODE_CONFIG_CONTENT, answers `session list`.
cat > "$work/bin/opencode" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "session" && "$2" == "list" ]]; then
  printf '[{"id":"ses_other","directory":"/elsewhere"},{"id":"ses_new","directory":"%s"}]\n' "$(pwd -P)";
  exit 0;
fi
printf '%s\n' "$@" > "$STUB_LOG.args";
printf '%s' "${OPENCODE_CONFIG_CONTENT-<unset>}" > "$STUB_LOG.env";
printf '%s' "${OPENCODE_CLI_CONFIG_CONTENT-<unset>}" > "$STUB_LOG.cli_env";
exit "${STUB_EXIT:-0}";
EOF
chmod +x "$work/bin/opencode"

pass=0; fail=0
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass=$((pass+1)); echo "ok   - $1";
  else fail=$((fail+1)); echo "FAIL - $1"; echo "       expected: $(printf %q "$2")"; echo "       actual:   $(printf %q "$3")"; fi
}
run() { # dir, args...
  local dir=$1; shift
  rm -f "$work/log.args" "$work/log.env" "$work/log.cli_env"
  (cd "$dir" && HOME="$work/home" XDG_STATE_HOME= PATH="$work/bin:$PATH" STUB_LOG="$work/log" bash "$script" "$@")
}
args() { tr '\n' ' ' < "$work/log.args" | sed 's/ $//'; }
env_json() { jq -cS . < "$work/log.env" 2>/dev/null || cat "$work/log.env"; }
cli_env_json() { jq -cS . < "$work/log.cli_env" 2>/dev/null || cat "$work/log.cli_env"; }

# 1. Home config only -> model/default_agent via env, --standalone injected
echo '{"model":"p/home-model","agent":"home-agent"}' > "$work/home/.opencode-config"
run "$work/plain"
check "home config -> env" '{"default_agent":"home-agent","model":"p/home-model"}' "$(env_json)"
check "default cli config -> tabs off" '{"tabs":{"mode":"off"}}' "$(cli_env_json)"
check "standalone injected (tui)" "--standalone" "$(args)"

# 2. Repo root overrides home (layered), cwd overrides repo root
echo '{"model":"p/repo-model"}' > "$work/repo/.opencode-config"
run "$work/repo/sub"
check "repo overrides model, home agent kept" '{"default_agent":"home-agent","model":"p/repo-model"}' "$(env_json)"
echo '{"agent":"sub-agent"}' > "$work/repo/sub/.opencode-config"
run "$work/repo/sub"
check "cwd overrides agent" '{"default_agent":"sub-agent","model":"p/repo-model"}' "$(env_json)"
rm "$work/repo/sub/.opencode-config"

# 3. CLI --model/--agent stripped from tui args and moved into env
run "$work/repo" --model p/cli -m p/cli2 --agent=cli-agent
check "cli flags -> env" '{"default_agent":"cli-agent","model":"p/cli2"}' "$(env_json)"
check "cli flags stripped" "--standalone" "$(args)"

# 4. Pre-existing OPENCODE_CONFIG_CONTENT merged (file < env < cli)
OPENCODE_CONFIG_CONTENT='{"model":"p/env","snapshots":false}' run "$work/repo" --agent a1
check "env merged" '{"default_agent":"a1","model":"p/env","snapshots":false}' "$(env_json)"
OPENCODE_CLI_CONFIG_CONTENT='{"theme":{"mode":"dark"}}' run "$work/repo"
check "cli env merged over default" '{"tabs":{"mode":"off"},"theme":{"mode":"dark"}}' "$(cli_env_json)"

# 5. --server suppresses --standalone; explicit --standalone not duplicated
run "$work/repo" --server http://x
check "--server respected" "--server http://x" "$(args)"
run "$work/repo" --standalone
check "no duplicate standalone" "--standalone" "$(args)"

# 6. Session persistence + --continue mapping
check "session persisted (repo root)" "ses_new" "$(cat "$work/repo/.last-opencode-session" 2>/dev/null)"
run "$work/repo" --continue
check "--continue -> --session" "--standalone --session ses_new" "$(args)"
rm -f "$work/plain/.last-opencode-session"; run "$work/plain" -c
check "-c passthrough without session file" "--standalone -c" "$(args)"

# 7. Favorites / recent / variant reset, other keys preserved
echo '{"recent":[{"a":1}],"favorite":[{"b":2}],"variant":{"x":"y"},"keep":1}' > "$work/home/.local/state/opencode/model.json"
run "$work/repo"
check "model.json reset" '{"favorite":[],"keep":1,"recent":[],"variant":{}}' "$(jq -cS . "$work/home/.local/state/opencode/model.json")"
check "no tmp files left" "" "$(ls "$work/home/.local/state/opencode" | grep -v '^model.json$')"
echo '{"recent":[{"a":1}],"favorite":[{"b":2}],"variant":{}}' > "$work/home/.local/state/opencode/model.json"
(cd "$work/repo" && RESET_OPENCODE_HISTORY=false HOME="$work/home" XDG_STATE_HOME= PATH="$work/bin:$PATH" STUB_LOG="$work/log" bash "$script")
check "reset opt-out" '[{"b":2}]' "$(jq -c .favorite "$work/home/.local/state/opencode/model.json")"

# 8. run/mini keep native --model, get config + --standalone after subcommand
run "$work/repo" run --model p/x "hello world"
check "run args" "run --standalone --model p/x hello world" "$(args)"
check "run env from files" '{"default_agent":"home-agent","model":"p/repo-model"}' "$(env_json)"

# 9. Other subcommands pass through untouched
run "$work/repo" service status
check "service passthrough" "service status" "$(args)"
check "service no env" "<unset>" "$(cat "$work/log.env")"
check "service no cli env" "<unset>" "$(cat "$work/log.cli_env")"

# 10. Directory positional drives config lookup
run "$work/plain" "$work/repo"
check "dir arg -> repo config" '{"default_agent":"home-agent","model":"p/repo-model"}' "$(env_json)"
check "dir arg kept" "--standalone $work/repo" "$(args)"

# 11. Invalid JSON warns and is skipped
echo '{bad' > "$work/repo/.opencode-config"
warn=$(run "$work/repo" 2>&1 >/dev/null)
check "invalid json skipped" '{"default_agent":"home-agent","model":"p/home-model"}' "$(env_json)"
[[ "$warn" == *"invalid JSON"* ]] && check "invalid json warns" 1 1 || check "invalid json warns" "warning" "$warn"
rm "$work/repo/.opencode-config"

# 12. --prompt value is not mistaken for a directory/subcommand
run "$work/repo" --agent product --prompt "run this"
check "--prompt kept" "--standalone --prompt run this" "$(args)"
check "--prompt agent -> env" "product" "$(jq -r .default_agent < "$work/log.env")"

# 13. Exit code propagated
STUB_EXIT=3 run "$work/plain"; check "exit code" 3 "$?"

echo; echo "$pass passed, $fail failed"; [[ $fail -eq 0 ]]
