#!/usr/bin/env bash

set -e;

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)";
RUN_MODEL="${REPO_ROOT}/bin/run-model";

PASSED=0;
FAILED=0;

assert_contains() {
  local output="${1}";
  local expected="${2}";
  local description="${3}";

  if echo "${output}" | grep -q -- "${expected}"; then
    echo "  [PASS] ${description}";
    PASSED=$((PASSED + 1));
  else
    echo "  [FAIL] ${description}";
    echo "         Expected to find: '${expected}'";
    echo "         In output: '${output}'";
    FAILED=$((FAILED + 1));
  fi
}

assert_exit_code() {
  local expected="${1}";
  local actual="${2}";
  local description="${3}";

  if [[ "${actual}" -eq "${expected}" ]]; then
    echo "  [PASS] ${description}";
    PASSED=$((PASSED + 1));
  else
    echo "  [FAIL] ${description} (expected ${expected}, got ${actual})";
    FAILED=$((FAILED + 1));
  fi
}

echo "=== Running bin/run-model CLI Test Harness ===";

# Test 1: text --dry-run
echo "Test 1: bin/run-model text --dry-run";
set +e;
output=$("${RUN_MODEL}" text --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "llama-server" "Contains llama-server";
assert_contains "${output}" "Mistral-Small-3.2-24B-Instruct-2506-UD-Q4_K_XL.gguf" "Selects Q4_K_XL Mistral model";
assert_contains "${output}" "jzaleski/text" "Uses alias jzaleski/text";
assert_contains "${output}" "8080" "Uses port 8080";
assert_contains "${output}" "65536" "Uses default ctx-size 65536";
assert_contains "${output}" "2048" "Uses batch-size 2048";
assert_contains "${output}" "1024" "Uses ubatch-size 1024";
assert_contains "${output}" "mlock" "Uses mlock load-mode";
assert_contains "${output}" "--fit off" "Disables auto-fit heuristic";

# Test 2: text -q 6 --dry-run
echo "Test 2: bin/run-model text -q 6 --dry-run";
set +e;
output=$("${RUN_MODEL}" text -q 6 --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
if echo "${output}" | grep -q "Mistral-Small-3.2-24B-Instruct-2506-UD-Q5_K_XL.gguf"; then
  assert_contains "${output}" "Mistral-Small-3.2-24B-Instruct-2506-UD-Q5_K_XL.gguf" "Selects Q5_K_XL Mistral fallback model";
else
  assert_contains "${output}" "Mistral-Small-3.2-24B-Instruct-2506-UD-Q6_K_XL.gguf" "Selects Q6_K_XL Mistral model";
fi

# Test 3: text -q 8 --dry-run
echo "Test 3: bin/run-model text -q 8 --dry-run";
set +e;
output=$("${RUN_MODEL}" text -q 8 --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "Mistral-Small-3.2-24B-Instruct-2506-UD-Q8_K_XL.gguf" "Selects Q8_K_XL Mistral model";

# Test 4: text -c 262144 --dry-run
echo "Test 4: bin/run-model text -c 262144 --dry-run";
set +e;
output=$("${RUN_MODEL}" text -c 262144 --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "--ctx-size 262144" "Overrides ctx-size to 262144";

# Test 5: multi --dry-run
echo "Test 5: bin/run-model multi --dry-run";
set +e;
output=$("${RUN_MODEL}" multi --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "llama-server" "Contains llama-server";
assert_contains "${output}" "Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf" "Selects Qwen3.8 Flash Next Q4 part 1";
assert_contains "${output}" "--mmproj" "Includes --mmproj flag";
assert_contains "${output}" "jzaleski/multi" "Uses alias jzaleski/multi";
assert_contains "${output}" "8080" "Uses default port 8080";
assert_contains "${output}" "65536" "Uses default ctx-size 65536";
assert_contains "${output}" "--jinja" "Includes --jinja flag";
assert_contains "${output}" "--fit off" "Disables auto-fit heuristic";
assert_contains "${output}" "chat-template-kwargs" "Includes default reasoning chat-template-kwargs";

# Test 6: multi -q 6 --dry-run
echo "Test 6: bin/run-model multi -q 6 --dry-run";
set +e;
output=$("${RUN_MODEL}" multi -q 6 --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "Qwen3.8-Flash-Next-UD-Q6_K_XL-00001-of-00006.gguf" "Selects Qwen3.8 Flash Next Q6 part 1";

# Test 7: multi -q 8 --dry-run
echo "Test 7: bin/run-model multi -q 8 --dry-run";
set +e;
output=$("${RUN_MODEL}" multi -q 8 --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "Qwen3.8-Flash-Next-Q8_0-00001-of-00006.gguf" "Selects Qwen3.8 Flash Next Q8 part 1";

# Test 8: transcription --dry-run
echo "Test 8: bin/run-model transcription --dry-run";
set +e;
output=$("${RUN_MODEL}" transcription --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "lib/whisper_server.py" "Executes lib/whisper_server.py";
assert_contains "${output}" "8765" "Uses port 8765";
assert_contains "${output}" "--model turbo" "Uses default model turbo";

# Test 9: invalid_purpose exits with code 1
echo "Test 9: bin/run-model invalid_purpose";
set +e;
output=$("${RUN_MODEL}" invalid_purpose 2>&1);
status=$?;
set -e;
assert_exit_code 1 "${status}" "Rejects invalid purpose with exit code 1";

# Test 10: default purpose omitted (defaults to text)
echo "Test 10: bin/run-model --dry-run (default text)";
set +e;
output=$("${RUN_MODEL}" --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "jzaleski/text" "Defaults to jzaleski/text";
assert_contains "${output}" "Mistral-Small-3.2-24B-Instruct-2506-UD-Q4_K_XL.gguf" "Selects Q4 Mistral model";

# Test 11: unsupported quantization exits with code 1
echo "Test 11: bin/run-model text -q 5 --dry-run";
set +e;
output=$("${RUN_MODEL}" text -q 5 --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 1 "${status}" "Rejects unsupported quantization with exit code 1";

# Test 12: speculative draft model flag propagates
echo "Test 12: bin/run-model text -md /path/to/draft.gguf --dry-run";
set +e;
output=$("${RUN_MODEL}" text -md /path/to/draft.gguf --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "--spec-draft-model /path/to/draft.gguf" "Includes draft model path";
assert_contains "${output}" "--spec-type draft-simple" "Uses default draft-simple spec-type for text";
assert_contains "${output}" "--spec-draft-n-max 5" "Uses default draft-max 5";

# Test 13: --no-speculative disables draft model
echo "Test 13: bin/run-model text --no-speculative -md /path/to/draft.gguf --dry-run";
set +e;
output=$("${RUN_MODEL}" text --no-speculative -md /path/to/draft.gguf --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
if echo "${output}" | grep -q -- "--spec-draft-model"; then
  echo "  [FAIL] Expected --spec-draft-model to be omitted";
  FAILED=$((FAILED + 1));
else
  echo "  [PASS] Omits --spec-draft-model when --no-speculative";
  PASSED=$((PASSED + 1));
fi

# Test 14: transcription custom model and device
echo "Test 14: bin/run-model transcription -m base --device cpu --dry-run";
set +e;
output=$("${RUN_MODEL}" transcription -m base --device cpu --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "--model base" "Overrides model to base";
assert_contains "${output}" "--device cpu" "Overrides device to cpu";

# Test 15: host and port override
echo "Test 15: bin/run-model text -H 0.0.0.0 -p 9999 --dry-run";
set +e;
output=$("${RUN_MODEL}" text -H 0.0.0.0 -p 9999 --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "--host 0.0.0.0" "Overrides host to 0.0.0.0";
assert_contains "${output}" "--port 9999" "Overrides port to 9999";

# Test 16: extra args pass-through via --
echo "Test 16: bin/run-model text --dry-run -- --custom-flag custom-val";
set +e;
output=$("${RUN_MODEL}" text --dry-run -- --custom-flag custom-val 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "--custom-flag custom-val" "Passes through extra args";

# Test 17: explicit --purpose flag
echo "Test 17: bin/run-model --purpose multi --dry-run";
set +e;
output=$("${RUN_MODEL}" --purpose multi --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "jzaleski/multi" "Accepts --purpose multi";

# Test 18: shorthand --multi flag
echo "Test 18: bin/run-model --multi --dry-run";
set +e;
output=$("${RUN_MODEL}" --multi --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "jzaleski/multi" "Accepts shorthand --multi";

# Test 19: multimodal purpose is rejected
echo "Test 19: bin/run-model multimodal --dry-run";
set +e;
output=$("${RUN_MODEL}" multimodal --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 1 "${status}" "Rejects multimodal with exit code 1";

# Test 20: transcription -d cpu --dry-run
echo "Test 20: bin/run-model transcription -d cpu --dry-run";
set +e;
output=$("${RUN_MODEL}" transcription -d cpu --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "--device cpu" "Overrides device to cpu with -d";

# Test 21: WHISPER_HOST=0.0.0.0 WHISPER_PORT=9100 WHISPER_MODEL=small run_model transcription --dry-run
echo "Test 21: WHISPER_HOST=0.0.0.0 WHISPER_PORT=9100 WHISPER_MODEL=small bin/run-model transcription --dry-run";
set +e;
output=$(WHISPER_HOST=0.0.0.0 WHISPER_PORT=9100 WHISPER_MODEL=small "${RUN_MODEL}" transcription --dry-run 2>&1);
status=$?;
set -e;
assert_exit_code 0 "${status}" "Exits with code 0";
assert_contains "${output}" "--host 0.0.0.0" "Uses WHISPER_HOST";
assert_contains "${output}" "--port 9100" "Uses WHISPER_PORT";
assert_contains "${output}" "--model small" "Uses WHISPER_MODEL";

echo "";
echo "=== Test Summary ===";
echo "Passed: ${PASSED}";
echo "Failed: ${FAILED}";

if [[ "${FAILED}" -gt 0 ]]; then
  exit 1;
fi

exit 0;
