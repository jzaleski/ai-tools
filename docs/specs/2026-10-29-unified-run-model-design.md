# Design Document: Unified Purpose-Oriented `run-model`

**Date:** 2026-10-29  
**Status:** Draft for Review  
**Topic:** Reconcile model hosting into `ai-tools`, retire router and tier abstractions, and unify around purpose-oriented variants in `bin/run-model`.

---

## 1. Intent and the Why

The current architecture in `ai-tools` uses router mode (`bin/run-router`) and abstract tier namespaces (`default/low|medium|high`, `experimental/quark|boson`), with dual ports and complex INI preset template generation. Meanwhile, `backfill-tools` developed independent wrappers (`bin/run-text-generation-server.sh` and `bin/run-whisper-server.sh`) for running workflows.

Abstract tier and particle names add unnecessary cognitive and architectural complexity. This design establishes `ai-tools` as the single repository of record for all local model hosting infrastructure. It removes the router modes and INI presets, consolidates model execution under a single CLI entrypoint (`bin/run-model`), switches to purpose-oriented aliases (`jzaleski/text`, `jzaleski/multimodal`, `jzaleski/transcription`), and adds simple quantization switching (4, 6, 8-bit). This enables `backfill-tools` to focus solely on running backfills rather than managing model hosting.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- **Single Entrypoint:** Make `bin/run-model` the unified CLI for launching `text`, `multimodal`, and `transcription` servers.
- **Purpose-Oriented Aliases:** Expose stable, meaningful aliases to clients:
  - `jzaleski/text`: Mistral Small 3.2 24B Instruct.
  - `jzaleski/multimodal`: Qwen3.8 Flash Next with multimodal projector (`mmproj`).
  - `jzaleski/transcription`: OpenAI-compatible Whisper server.
- **Quantization Switching:** Support `-q / --quantization` with variants `4`, `6`, and `8` for both `text` and `multimodal` models (defaulting to `6`).
- **Retire Router & Presets:** Remove `bin/run-router` and all `templates/llama-cpp-*.ini.template` files.
- **Vendor Whisper Server:** Integrate `lib/whisper_server.py` into `ai-tools` so transcription is hosted locally with Metal (Apple Silicon MPS), CUDA, and CPU acceleration.
- **Update Opencode Config:** Update `home/.config/opencode/opencode.json` to expose `jzaleski/text` and `jzaleski/multimodal`.
- **Update Documentation & Agent Guides:** Update `AGENTS.md` and `README.md` to reflect the simplified architecture.

### Non-Goals
- Maintaining backward-compatible router flags (`--default`, `--experimental`) or INI preset generation.
- Preserving deprecated models (DeepSeek V4 Flash, GLM 5.3 Flash, Gemma 4, Qwen 27B) — these are slated for decommissioning.
- Building a custom C++ `whisper-server` via CMake; the tested Python `openai-whisper` server is used instead.
- Bundling or requiring custom local draft models for speculative decoding; only publicly accessible Hugging Face repositories are used by default. Clients with custom draft models can pass additional arguments via `-- <args>`.

### Anti-Goals
- Adding heavy orchestration frameworks, Docker, or Kubernetes.
- Coupling `ai-tools` to `backfill-tools` business logic.

---

## 3. Constraints

- **Platform:** macOS Apple Silicon (M-series, e.g., M3 Ultra) primary; Linux (Ryzen + RTX 5090) secondary.
- **Runtimes:**
  - `llama-server` (Homebrew or ggml-org build) for `text` and `multimodal`.
  - Python 3.10+ with `openai-whisper`, `torch`, and `ffmpeg` for `transcription`.
- **Model Storage:** Default `MODELS_DIR` remains `~/.cache/models`. Split GGUFs (4-part and 6-part) and multimodal projectors must be resolved and automatically downloaded via `bin/download-model` if missing.

---

## 4. Approaches Considered

### Approach 1: Unified `run-model` with native `llama-server` and Python Whisper HTTP server (Selected)
- Consolidates all execution into `bin/run-model`.
- Drives `llama-server` for LLMs and `lib/whisper_server.py` for transcription.
- Direct drop-in compatibility with OpenAI-compatible clients and `backfill-tools`.
- **Tradeoff:** Adds Python dependency management to `ai-tools`, but leverages existing system/pyenv packages and virtual environments seamlessly.

### Approach 2: Whisper via `whisper.cpp` Server (Rejected)
- Builds `whisper.cpp` via CMake and runs `whisper-server`.
- **Tradeoff:** Homebrew disables the server build in the official formula (`-DWHISPER_BUILD_SERVER=OFF`), requiring source compilation and custom request/response translation layers for `backfill-tools`.

### Approach 3: Dual Launchers (`run-model` and `run-whisper`) (Rejected)
- Keeps `run-model` for `llama-server` and creates a separate script for Whisper.
- **Tradeoff:** Fails the primary objective of unifying model hosting behind a single tool.

---

## 5. Architecture and Components

### 5.1 CLI Interface: `bin/run-model`

**Usage:**
```bash
bin/run-model [options] <purpose> [-- <additional backend args>]
# Or via flag:
bin/run-model --purpose <purpose> [options]
```

**Purposes (`<purpose>`):**
- `text` (default if omitted): Mistral Small 3.2 24B Instruct.
- `multimodal`: Qwen3.8 Flash Next with F16 multimodal projector.
- `transcription`: Whisper audio transcription HTTP server.

**Options:**
- `-q, --quantization <4|6|8>`: Model quantization (default: `4`). Applies to `text` and `multimodal`.
- `-H, --host <host>`: Host to bind (default: `127.0.0.1` or `HOST` env var).
- `-p, --port <port>`: Port to listen on (defaults: `8080` for text, `8081` for multimodal, `8765` for transcription, or `PORT` env var).
- `-m, --model <path|name>`: Override model GGUF path (for text/multimodal) or Whisper model name (for transcription, default `turbo`).
- `-c, --ctx-size <size>`: Context window tokens (default: `65536` for text, `262144` for multimodal).
- `--threads <n>`: CPU threads to use (default: `8` or `THREADS`).
- `--temp <temp>`: Sampling temperature (default: `0.15` for text, `1.0` for multimodal).
- `--top-k <k>`: Top-k sampling (default: `-1` for text, `20` for multimodal).
- `--top-p <p>`: Top-p sampling (default: `1.00` for text, `0.95` for multimodal).
- `-fa, --flash-attn [on|off|auto]`: Flash attention (default: `on`).
- `--jinja / --no-jinja`: Enable/disable Jinja templating (default: enabled).
- `--device <device>`: Inference device for transcription (`auto`, `mps`, `cuda`, `cpu`; default: `auto`).
- `--dry-run`: Print the underlying command without executing.
- `-h, --help`: Display help and documentation.

### 5.2 Model Mapping, Quantization Matrix & Tuning Defaults

All models prioritize Unsloth's Dynamic Quantization (`UD-*_K_XL`) and public Hugging Face repos.

| Purpose | Quant | Local Path / Split Pattern | HF Repo & Filename | Key Tuning Defaults |
|---|---|---|---|---|
| `text` (default) | `4` (default) | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-UD-Q4_K_XL.gguf` | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF` | ctx `65536`, batch `2048`, ubatch `512`, cache K/V `q8_0`/`q4_0`, temp `0.15`, jinja on, flash-attn on, mlock on, cache-reuse `256`, cache-ram `-1` |
| `text` | `6` | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-UD-Q6_K_XL.gguf` (fallback: `UD-Q5_K_XL.gguf`) | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF` | ctx `65536`, batch `2048`, ubatch `1024`, cache K/V `q8_0`/`q8_0`, temp `0.15`, jinja on, flash-attn on, mlock on, cache-reuse `256`, cache-ram `-1` |
| `text` | `8` | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-UD-Q8_K_XL.gguf` | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF` | ctx `65536`, batch `2048`, ubatch `1024`, cache K/V `q8_0`/`q8_0`, temp `0.15`, jinja on, flash-attn on, mlock on, cache-reuse `256`, cache-ram `-1` |
| `multimodal` | `4` (default) | `unsloth/Qwen3.8-Flash-Next-GGUF/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf` (4 parts) + `mmproj-F16.gguf` | `unsloth/Qwen3.8-Flash-Next-GGUF` | ctx `262144`, batch `1024`, ubatch `256`, cache K/V `q8_0`/`q8_0`, temp `1.0`, top-k `20`, top-p `0.95`, min-p `0.0`, flash-attn on, mlock on, image-min-tokens `1024`, reasoning-preserve on, cache-reuse `256`, cache-ram `-1` |
| `multimodal` | `6` | `unsloth/Qwen3.8-Flash-Next-GGUF/UD-Q6_K_XL/Qwen3.8-Flash-Next-UD-Q6_K_XL-00001-of-00006.gguf` (6 parts) + `mmproj-F16.gguf` | `unsloth/Qwen3.8-Flash-Next-GGUF` | ctx `262144`, batch `1024`, ubatch `256`, cache K/V `q8_0`/`q8_0`, temp `1.0`, top-k `20`, top-p `0.95`, min-p `0.0`, flash-attn on, mlock on, image-min-tokens `1024`, reasoning-preserve on, cache-reuse `256`, cache-ram `-1` |
| `multimodal` | `8` | `unsloth/Qwen3.8-Flash-Next-GGUF/Q8_0/Qwen3.8-Flash-Next-Q8_0-00001-of-00006.gguf` (6 parts) + `mmproj-F16.gguf` | `unsloth/Qwen3.8-Flash-Next-GGUF` | ctx `262144`, batch `1024`, ubatch `256`, cache K/V `q8_0`/`q8_0`, temp `1.0`, top-k `20`, top-p `0.95`, min-p `0.0`, flash-attn on, mlock on, image-min-tokens `1024`, reasoning-preserve on, cache-reuse `256`, cache-ram `-1` |
| `transcription` | N/A | Downloaded via OpenAI Whisper cache (`~/.cache/whisper`) | `turbo` (or `base`, `small`, `medium`, `large-v3`) | Auto-detect `cuda` -> `mps` -> `cpu`, disable FP16 on CPU |

### 5.3 Persistent Whisper Server (`lib/whisper_server.py`)
- Vendored from `backfill-tools/lib/whisper_server.py`.
- Exposes OpenAI-compatible `/v1/audio/transcriptions` (both `multipart/form-data` and `application/json` with local `path`).
- Exposes `/health` and `/v1/models`.
- Disables FP16 when running on CPU to prevent PyTorch warnings.
- Auto-detects `cuda` -> `mps` -> `cpu`.
- Uses a mutex lock around model transcription to ensure thread-safe single-instance inference.

### 5.4 Python Bootstrap (`pyenv` Integration)
Following the pattern established in `home-dir`, `ibble-bootstrap`, and `alakai-bootstrap`:
- `.default-python-version`: checked-in file at repo root specifying default Python version (`3.14.3`).
- `requirements.txt`: top-level requirements specifying:
  ```
  openai-whisper
  torch
  ```
- `bin/configure-python`: standard bootstrap script that:
  1. Checks for `USE_EXISTING_PYTHON_MANAGER`.
  2. Ensures `pyenv` is installed at `~/.pyenv` (cloning or pulling via git).
  3. Ensures shims and bin directories are in `PATH` via `home/.opencoderc`.
  4. Installs the version specified in `.default-python-version` via `pyenv install -s`.
  5. Sets the global or local pyenv version and runs `pyenv rehash`.
  6. Installs or upgrades dependencies from `requirements.txt`.
- `bin/bootstrap`: includes `configure-python` in `bin_scripts` sequence.
- `bin/run-model`: locates Python via pyenv shims, active virtualenv, or python3.

### 5.5 Opencode Provider Configuration (`home/.config/opencode/opencode.json`)
Consolidates the provider into a single `jzaleski` provider:
- `jzaleski/text`: baseURL `http://server-hostname-or-ip:8080/v1`, context 65536, text modalities.
- `jzaleski/multimodal`: baseURL `http://server-hostname-or-ip:8081/v1`, context 262144, text+image modalities.
Removes obsolete `jzaleski/experimental` provider and old tier model blocks (`low`, `medium`, `high`, `quark`, `boson`).

---

## 6. Error Handling and Testing Approach

### Error Handling
- Invalid purpose argument: exit 1 with clear usage instructions.
- Unsupported quantization: exit 1 listing available levels (`4`, `6`, `8`).
- Missing `llama-server` binary: exit 1 with guidance to run `bin/bootstrap` or `brew install llama.cpp`.
- Missing Python/Whisper dependencies when launching `transcription`: exit 1 with clear setup instructions.
- Auto-download failure: clean up partial files and exit 1 with HTTP/network diagnostic.

### Testing Approach
- Shell script syntax verification (`bash -n bin/run-model`).
- CLI argument and flag parsing test via `--dry-run`:
  - `bin/run-model text --dry-run`
  - `bin/run-model text -q 4 --dry-run`
  - `bin/run-model multimodal -q 6 --dry-run`
  - `bin/run-model transcription --dry-run`
- Unit tests for Whisper server (`tests/test_whisper_server.py` ported from backfill-tools).
- Opencode JSON schema validation (`jq . home/.config/opencode/opencode.json`).

---

## 7. What Was Decided vs. What Is Left to the Builder

### Decided
- Total removal of `bin/run-router` and INI templates.
- Purpose names: `text`, `multimodal`, `transcription`.
- Model assignments: Mistral Small 24B for text, Qwen3.8 Flash Next for multimodal, Whisper for transcription.
- Quantization levels: 4, 6, 8 (default 6).
- Ports: 8080 (text), 8081 (multimodal), 8765 (transcription).
- Direct porting of `whisper_server.py` and its test suite.

### Left to Builder
- Script variable naming and shell formatting matching project conventions (`set -e;`, double-quoted expansions).
- Specific test execution details in unit test harness.
