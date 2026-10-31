# Design Document: Standardize Model Aliases (`multi`) and Server Wrapper Consistency

**Date:** 2026-10-31  
**Status:** Draft for Review  
**Topic:** Standardize model aliases and CLI purpose names by renaming `multimodal` / `jzaleski/multimodal` to `multi` / `jzaleski/multi`, and unify environment variable hierarchy (`HOST`, `PORT`, `WHISPER_*`) and CLI flag handling across server wrappers.

---

## 1. Intent and the Why

1. **Model Alias Consistency:** The repository unifies model hosting around purpose-oriented aliases (`jzaleski/text`, `jzaleski/multimodal`, `jzaleski/transcription`). However, `multimodal` stood out as an awkward descriptor: it strictly described input capabilities (text + image) rather than its actual role in the workflow. Qwen3.8 Flash Next is the broad, versatile workhorse used for multimodal input, reasoning, and complex tasks, whereas Mistral 24B (`text`) and Whisper (`transcription`) serve as targeted specialists. Standardizing on `multi` (`jzaleski/multi`) provides a clean, punchy, and direct identifier that captures its multi-faceted, versatile nature without generic ambiguity.

2. **Server Wrapper Consistency:** To ensure uniform behavior across wrapper scripts and standalone servers, `whisper_server.py` and `bin/run-model` (transcription purpose) must adhere to a consistent environment variable precedence hierarchy (`WHISPER_*` specific overrides > `HOST`/`PORT` general overrides > default) and matching CLI short flags (`-H` for host, `-p` for port, `-m` for model, `-d` for device).

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- **Standardize Alias:** Rename the Qwen3.8 Flash Next model alias from `jzaleski/multimodal` to `jzaleski/multi`.
- **Align CLI Purpose & Flags:** In `bin/run-model`, rename the positional purpose `multimodal` to `multi` and the shorthand flag `--multimodal` to `--multi`.
- **Clean Break (No Backward Compatibility):** Discontinue `--multimodal` and `multimodal` as CLI options per explicit design decision.
- **Unify Environment Precedence for Whisper Server & Wrapper:**
  - Host: `WHISPER_HOST` -> `HOST` -> `127.0.0.1`
  - Port: `WHISPER_PORT` -> `PORT` -> `8765`
  - Model: `WHISPER_MODEL` -> `turbo`
  - Device: `WHISPER_DEVICE` -> hardware detection (or `auto` in `run-model`)
- **Unify CLI Flags across Server Wrappers:**
  - Support matching flags `-H/--host`, `-p/--port`, `-m/--model`, `-d/--device` across both `bin/run-model` and `lib/whisper_server.py`.
- **Update Opencode Provider Configuration:** Update `home/.config/opencode/opencode.json` to expose `jzaleski/multi` with port 8081 and text+image input modalities.
- **Update Test Suite:**
  - Update all CLI test harness assertions in `tests/test_run_model.sh` to test `multi`, `--multi`, `--purpose multi`, and `jzaleski/multi`.
  - Add tests for `HOST` / `PORT` fallback in Whisper server unit tests (`tests/test_whisper_server.py`) and short flags (`-H`, `-p`, `-m`, `-d`).
  - Add tests in `tests/test_run_model.sh` verifying `WHISPER_HOST`, `WHISPER_PORT`, `WHISPER_MODEL`, `WHISPER_DEVICE`, and `-d/--device`.
- **Synchronize Documentation & Agent Guidelines:** Update `README.md` and `AGENTS.md` (architecture diagrams, curl examples, alias tables, environment variables, and descriptions).

### Non-Goals
- Changing port allocations (port 8081 remains allocated for `multi`, 8080 for `text`, 8765 for `transcription`).
- Modifying underlying model weights, quantizations, sampling parameters, or context window defaults.
- Renaming `jzaleski/text` or `jzaleski/transcription`.

### Anti-Goals
- Maintaining legacy alias fallbacks or aliases for `multimodal` that add dead code paths.

---

## 3. Constraints

- **POSIX Shell & Bash Portability:** `bin/run-model` and `tests/test_run_model.sh` must remain compatible with macOS/Linux bash with `set -e`.
- **Python Compatibility:** `lib/whisper_server.py` must support standard library `argparse` without external argument parsing dependencies.
- **Test Integrity:** All test assertions in `tests/test_run_model.sh` and `tests/test_whisper_server.py` must pass cleanly.
- **Opencode Schema:** `home/.config/opencode/opencode.json` must remain valid JSON adhering to opencode provider requirements.

---

## 4. Approaches Considered

### Approach 1: Role / Workload Taxonomy (`jzaleski/general`)
- Name based on general workhorse vs. specialist.
- **Tradeoff:** `general` felt too vague or corporate and lacked distinction.

### Approach 2: Omni / Greek Root (`jzaleski/omni` or `jzaleski/poly`)
- Name based on broad versatility with classical roots.
- **Tradeoff:** `poly` and `omni` were attractive, but `multi` was chosen as more direct and grounded.

### Approach 3: Direct Prefix (`jzaleski/multi` & `multi`) + Server Parity (Selected)
- Short, punchy, and instantly communicates versatility across modalities and tasks while pairing cleanly with `jzaleski/text` and `jzaleski/transcription`.
- CLI syntax: `bin/run-model multi` or `bin/run-model --multi`.
- Environment and flag parity ensures identical mental models when configuring or running any server component.
- **Tradeoff:** Requires updating references across CLI, tests, opencode configs, and docs, but provides a clean break with zero technical debt.

---

## 5. Architecture & Changes by Component

### 5.1 CLI: `bin/run-model`
- **Help text:**
  - Update usage: `bin/run-model [text|multi|transcription] [options]`
  - Update purpose description: `multi: Qwen3.8 Flash Next with mmproj (port 8081, alias jzaleski/multi)`
  - Update shorthand options: `-m, --multi: Run multi model (alias jzaleski/multi)` (replacing `-m, --multimodal`)
  - Update device flag help: `-d, --device <device>`
- **Argument Parsing:**
  - Positional argument matching: `multi) purpose="multi" ;;` (removing `multimodal`)
  - Flag matching: `-m|--multi) purpose="multi" ;;` (removing `--multimodal`)
  - Device flag matching: `-d|--device)`
  - Purpose validation: validate against `text|multi|transcription`.
- **Environment & Precedence Handling (Transcription):**
  - When purpose is `transcription`:
    - `host="${host_cli_set:+$host}"`; if unset, evaluate `${WHISPER_HOST:-${HOST:-"127.0.0.1"}}`
    - `port="${port_cli_set:+$port}"`; if unset, evaluate `${WHISPER_PORT:-${PORT:-8765}}`
    - `model="${model_cli_set:+$model}"`; if unset, evaluate `${WHISPER_MODEL:-"turbo"}`
    - `device="${device_cli_set:+$device}"`; if unset, evaluate `${WHISPER_DEVICE:-"auto"}`
- **Execution Block:**
  - Check `if [[ "${purpose}" == "multi" ]]; then`
  - Set `alias_name="jzaleski/multi"`

### 5.2 Standalone Server: `lib/whisper_server.py`
- **Argument Parsing:**
  - `parser.add_argument("-H", "--host", default=os.getenv("WHISPER_HOST") or os.getenv("HOST") or "127.0.0.1", ...)`
  - `parser.add_argument("-p", "--port", type=int, default=int(os.getenv("WHISPER_PORT") or os.getenv("PORT") or "8765"), ...)`
  - `parser.add_argument("-m", "--model", default=os.getenv("WHISPER_MODEL") or "turbo", ...)`
  - `parser.add_argument("-d", "--device", default=get_default_device(), ...)`

### 5.3 Test Harness: `tests/test_run_model.sh` & `tests/test_whisper_server.py`
- `tests/test_run_model.sh`:
  - Test purpose `multi`: `run_model multi --dry-run`
  - Assert alias output contains `jzaleski/multi`
  - Assert flag `--purpose multi`
  - Assert shorthand `--multi` and `-m`
  - Assert `-d` flag for device
  - Assert `WHISPER_HOST` and `WHISPER_PORT` overrides in transcription dry run
- `tests/test_whisper_server.py`:
  - Test `HOST` and `PORT` general fallback when `WHISPER_HOST`/`WHISPER_PORT` are not set
  - Test `WHISPER_HOST` takes precedence over `HOST`
  - Test `WHISPER_PORT` takes precedence over `PORT`
  - Test short flags `-H`, `-p`, `-m`, `-d` in `parse_args`

### 5.4 Configuration: `home/.config/opencode/opencode.json`
- Rename model key `"jzaleski/multimodal"` to `"jzaleski/multi"`.
- Update `name`: `"jzaleski/multi"`.

### 5.5 Documentation: `README.md` and `AGENTS.md`
- Update all model alias lists, port assignment tables, ASCII architecture diagrams, environment variable tables, and curl example commands from `jzaleski/multimodal` / `multimodal` to `jzaleski/multi` / `multi`.
- Document `WHISPER_HOST`, `WHISPER_PORT`, `WHISPER_MODEL`, and general `HOST`/`PORT` fallbacks.

---

## 6. Error Handling and Testing Approach

- **Verification Commands:**
  - `bash tests/test_run_model.sh`: Must pass all assertions cleanly.
  - `python3 -m unittest discover -s tests`: Must pass all tests including new arg parsing and env override tests.
  - `./bin/run-model multi --dry-run`: Verify dry-run command outputs `llama-server` with `--alias jzaleski/multi` and port 8081.
  - `jq . home/.config/opencode/opencode.json >/dev/null`: Validate JSON syntax.

---

## 7. Builder Check & Decisions

### Already Answered
- **Model Name:** `jzaleski/multi`.
- **CLI Purpose & Shorthand:** `multi` and `--multi` (with `-m`).
- **Backward Compatibility:** No backward compatibility for `multimodal` or `--multimodal`.
- **Whisper Overrides:** Specific `WHISPER_*` overrides take precedence over generic `HOST`/`PORT`, which take precedence over defaults.
- **Short Flags:** `-H`, `-p`, `-m`, `-d` supported across both `whisper_server.py` and `bin/run-model`.

### Minor (Author's Call)
- **Flag tracking in `run-model`:** Use explicit booleans or non-empty checks to ensure CLI flags always take precedence over environment variables.
- **Historical documentation:** Historical plan and spec files (`docs/specs/2026-10-29-*` and `docs/plans/2026-10-29-*`) remain untouched as historical records; current living docs (`README.md`, `AGENTS.md`) are fully updated.

### Theirs (Open User Decisions)
- None remaining. All naming choices, CLI flags, env hierarchy, and compatibility decisions have been settled.
