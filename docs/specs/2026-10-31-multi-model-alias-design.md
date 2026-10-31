# Design Document: Rename Multimodal Alias to `multi` (`jzaleski/multi`)

**Date:** 2026-10-31  
**Status:** Draft for Review  
**Topic:** Standardize model aliases and CLI purpose names by renaming `multimodal` / `jzaleski/multimodal` to `multi` / `jzaleski/multi`.

---

## 1. Intent and the Why

The repository unifies model hosting around purpose-oriented aliases (`jzaleski/text`, `jzaleski/multimodal`, `jzaleski/transcription`). However, `multimodal` stood out as an awkward descriptor: it strictly described input capabilities (text + image) rather than its actual role in the workflow. 

Qwen3.8 Flash Next is the broad, versatile workhorse used for multimodal input, reasoning, and complex tasks, whereas Mistral 24B (`text`) and Whisper (`transcription`) serve as targeted specialists. Standardizing on `multi` (`jzaleski/multi`) provides a clean, punchy, and direct identifier that captures its multi-faceted, versatile nature without generic ambiguity.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- **Standardize Alias:** Rename the Qwen3.8 Flash Next model alias from `jzaleski/multimodal` to `jzaleski/multi`.
- **Align CLI Purpose & Flags:** In `bin/run-model`, rename the positional purpose `multimodal` to `multi` and the shorthand flag `--multimodal` to `--multi`.
- **Clean Break (No Backward Compatibility):** Discontinue `--multimodal` and `multimodal` as CLI options per explicit design decision.
- **Update Opencode Provider Configuration:** Update `home/.config/opencode/opencode.json` to expose `jzaleski/multi` with port 8081 and text+image input modalities.
- **Update Test Suite:** Update all CLI test harness assertions in `tests/test_run_model.sh` to test `multi`, `--multi`, `--purpose multi`, and `jzaleski/multi`.
- **Synchronize Documentation & Agent Guidelines:** Update `README.md` and `AGENTS.md` (architecture diagrams, curl examples, alias tables, and descriptions).

### Non-Goals
- Changing port allocations (port 8081 remains allocated for `multi`).
- Modifying underlying model weights, quantizations, sampling parameters, or context window defaults (Qwen3.8 Flash Next with mmproj, 64K context).
- Renaming `jzaleski/text` or `jzaleski/transcription`.

### Anti-Goals
- Maintaining legacy alias fallbacks or aliases for `multimodal` that add dead code paths.

---

## 3. Constraints

- **POSIX Shell & Bash Portability:** `bin/run-model` and `tests/test_run_model.sh` must remain compatible with macOS/Linux bash with `set -e`.
- **Test Integrity:** All 52 test assertions in `tests/test_run_model.sh` (or updated equivalent) must pass cleanly.
- **Opencode Schema:** `home/.config/opencode/opencode.json` must remain valid JSON adhering to opencode provider requirements.

---

## 4. Approaches Considered

### Approach 1: Role / Workload Taxonomy (`jzaleski/general`)
- Name based on general workhorse vs. specialist.
- **Tradeoff:** `general` felt too vague or corporate and lacked distinction.

### Approach 2: Omni / Greek Root (`jzaleski/omni` or `jzaleski/poly`)
- Name based on broad versatility with classical roots.
- **Tradeoff:** `poly` and `omni` were attractive, but `multi` was chosen as more direct and grounded.

### Approach 3: Direct Prefix (`jzaleski/multi` & `multi`) (Selected)
- Short, punchy, and instantly communicates versatility across modalities and tasks while pairing cleanly with `jzaleski/text` and `jzaleski/transcription`.
- CLI syntax: `bin/run-model multi` or `bin/run-model --multi`.
- **Tradeoff:** Requires updating references across CLI, tests, opencode configs, and docs, but provides a clean break with zero technical debt.

---

## 5. Architecture & Changes by Component

### 5.1 CLI: `bin/run-model`
- **Help text:**
  - Update usage: `bin/run-model [text|multi|transcription] [options]`
  - Update purpose description: `multi: Qwen3.8 Flash Next with mmproj (port 8081, alias jzaleski/multi)`
  - Update shorthand options: `-m, --multi: Run multi model (alias jzaleski/multi)` (replacing `-m, --multimodal`)
- **Argument Parsing:**
  - Positional argument matching: `multi) purpose="multi" ;;` (removing `multimodal`)
  - Flag matching: `-m|--multi) purpose="multi" ;;` (removing `--multimodal`)
  - Purpose validation: validate against `text|multi|transcription`.
- **Execution Block:**
  - Check `if [[ "${purpose}" == "multi" ]]; then`
  - Set `alias_name="jzaleski/multi"`

### 5.2 Test Harness: `tests/test_run_model.sh`
- Update test cases:
  - Test purpose `multi`: `run_model multi --dry-run`
  - Assert alias output contains `jzaleski/multi`
  - Assert flag `--purpose multi`
  - Assert shorthand `--multi` and `-m`
- Ensure all assertions pass without error.

### 5.3 Configuration: `home/.config/opencode/opencode.json`
- Rename model key `"jzaleski/multimodal"` to `"jzaleski/multi"`.
- Update `name`: `"jzaleski/multi"` (or `"Qwen3.8 Flash Next (Multi)"`).

### 5.4 Documentation: `README.md` and `AGENTS.md`
- Update all model alias lists, port assignment tables, ASCII architecture diagrams, and curl example commands from `jzaleski/multimodal` / `multimodal` to `jzaleski/multi` / `multi`.

---

## 6. Error Handling and Testing Approach

- **Verification Commands:**
  - `bash tests/test_run_model.sh`: Must run 52+ assertions and output `All 52 tests passed!`.
  - `./bin/run-model multi --dry-run`: Verify dry-run command outputs `llama-server` with `--alias jzaleski/multi` and port 8081.
  - `python3 -m unittest discover -s tests`: Ensure Whisper server unit tests continue to pass.
  - `jq . home/.config/opencode/opencode.json >/dev/null`: Validate JSON syntax.

---

## 7. Builder Check & Decisions

### Already Answered
- **Model Name:** `jzaleski/multi`.
- **CLI Purpose & Shorthand:** `multi` and `--multi` (with `-m`).
- **Backward Compatibility:** No backward compatibility for `multimodal` or `--multimodal`.
- **Ports & Settings:** Port remains `8081`, model weights/sampling remain unchanged.

### Minor (Author's Call)
- **Help text descriptions:** Keep descriptions focused on "Qwen3.8 Flash Next with mmproj (port 8081, alias jzaleski/multi)" to maintain symmetry with `text` and `transcription`.
- **Historical documentation:** Historical plan and spec files (`docs/specs/2026-10-29-*` and `docs/plans/2026-10-29-*`) remain untouched as historical records of that specific milestone; current living docs (`README.md`, `AGENTS.md`) are fully updated.

### Theirs (Open User Decisions)
- None remaining. All naming choices, CLI flags, and compatibility decisions have been settled.
