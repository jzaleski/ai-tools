# Unified Purpose-Oriented `run-model` Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Reconcile model hosting into `ai-tools` as the repo of record, remove router mode and tier abstractions, and unify all model hosting behind `bin/run-model` for `text` (Mistral 24B), `multimodal` (Qwen3.8 Flash Next), and `transcription` (OpenAI-compatible Whisper).

**Architecture:** A single unified entrypoint `bin/run-model` drives `llama-server` for text and multimodal models and `lib/whisper_server.py` for audio transcription. It supports standard quantizations (`4`, `6`, `8` defaulting to `4`), 64K default context size, automatic speculative decoding detection, and full unified memory optimizations (`mlock`, `cache-reuse 256`, `cache-ram -1`). Router scripts and INI templates are removed, while Python dependencies are managed via `pyenv` consistent with project bootstrap patterns.

**Tech Stack:** Bash, Python 3.14 (`openai-whisper`, `torch`), `llama-server` (Homebrew/llama.cpp), JSON (`opencode.json`).

**Spec:** `docs/specs/2026-10-29-unified-run-model-design.md`

## Global Constraints

- Platform: macOS Darwin (Apple Silicon arm64) primary; Linux (Ryzen + CUDA) secondary.
- Standard quantization variants: `4` (default), `6`, and `8` for `text` and `multimodal`.
- Universal default context size: `65536` tokens (overrideable via `-c / --ctx-size` or `CTX_SIZE`).
- High-throughput defaults: `--flash-attn on`, `--load-mode mlock`, `--cache-reuse 256`, `--cache-ram -1`, `--batch-size 2048`, `--ubatch-size 1024`.
- Auto-detect speculative decoding when draft or MTP files are co-located, passing `--spec-draft-ngl -1` and `--spec-draft-n-max 3`.
- Public Hugging Face repos only by default: `unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF` and `unsloth/Qwen3.8-Flash-Next-GGUF`.
- Python bootstrap uses `pyenv` standard pattern (`bin/configure-python`, `.default-python-version`).
- No git worktrees; execute on feature branch `unify-run-model`.

## Review Focus

- Missing `llama-server` binary: cleanly exits with code 1 and diagnostic install message.
- Missing Python / `whisper` module on transcription: cleanly exits with code 1 instructing user to run bootstrap or install `requirements.txt`.
- Unsplit or split model resolution: ensures all multi-part GGUF files and `.mmproj` files exist before launching.
- Speculative decoding draft model fallback: gracefully continues without speculative decoding if no draft model is present and none was passed.
- Context size override: verifies `-c 262144` propagates exact token count to `llama-server`.

---

### Task 1: Python Environment & Pyenv Bootstrap

**Files:**
- Create: `.default-python-version`
- Create: `requirements.txt`
- Create: `bin/configure-python`
- Modify: `bin/bootstrap:50-65`
- Modify: `home/.opencoderc`

**Interfaces:**
- Produces: `bin/configure-python` executable; `pyenv` setup with Python 3.14.3 and `requirements.txt` installed.

- [ ] **Step 1: Write `.default-python-version` and `requirements.txt`**

Create `.default-python-version`:
```
3.14.3
```

Create `requirements.txt`:
```
openai-whisper
torch
```

- [ ] **Step 2: Create `bin/configure-python`**

Port and adapt `configure-python` from `ibble-bootstrap` / `alakai-bootstrap`:
- Check `$USE_EXISTING_PYTHON_MANAGER`.
- Ensure `$HOME/.pyenv` is cloned or pulled from `https://github.com/pyenv/pyenv.git`.
- Read `.default-python-version`.
- Run `${pyenv_cmd} install -s ${default_python_version}`.
- Run `${pyenv_cmd} global ${default_python_version}` and `${pyenv_cmd} rehash`.
- Install dependencies via `${pyenv_cmd} exec pip install -r requirements.txt`.
- Ensure `chmod +x bin/configure-python`.

- [ ] **Step 3: Update `bin/bootstrap` and `home/.opencoderc`**

In `bin/bootstrap`, add `configure-python` to `bin_scripts`:
```bash
  bin_scripts=(
    install-dependencies \
    configure-git \
    configure-python \
    configure-opencode \
  );
```
In `home/.opencoderc`, ensure `$HOME/.pyenv/bin` and `$HOME/.pyenv/shims` are prepended to `PATH` if `$HOME/.pyenv` exists.

- [ ] **Step 4: Verify syntax and execution**

Run: `bash -n bin/configure-python && bash -n bin/bootstrap`
Expected: Syntax OK (exit 0).

- [ ] **Step 5: Commit**

```bash
git add .default-python-version requirements.txt bin/configure-python bin/bootstrap home/.opencoderc
git commit -m "feat: add pyenv python bootstrap and whisper dependencies"
```

---

### Task 2: Port Persistent Whisper Server and Unit Tests

**Files:**
- Create: `lib/whisper_server.py`
- Create: `tests/test_whisper_server.py`

**Interfaces:**
- Consumes: Python 3 with `torch` and `whisper`.
- Produces: `lib/whisper_server.py` supporting `/v1/audio/transcriptions`, `/health`, and `/v1/models`.

- [ ] **Step 1: Port `lib/whisper_server.py`**

Port `lib/whisper_server.py` from `backfill-tools`:
- `parse_args()` with `--host`, `--port` (default 8765), `--model` (default turbo), `--device` (auto-detects cuda -> mps -> cpu).
- HTTP handler implementing:
  - `GET /health` returning `{"status": "ok", "model": ..., "device": ..., "cuda_available": ..., "mps_available": ...}`.
  - `GET /v1/models` returning OpenAI model list.
  - `POST /v1/audio/transcriptions` accepting `multipart/form-data` with `file` upload and `application/json` with local `path`/`file_path`.
  - Disables FP16 when device is CPU to prevent PyTorch warnings.
  - Thread-safe transcription with `threading.Lock()`.
- Ensure file has executable permissions (`chmod +x lib/whisper_server.py`).

- [ ] **Step 2: Write unit tests in `tests/test_whisper_server.py`**

Port and adapt unit tests from `backfill-tools/tests/test_whisper_server.py`:
- `TestWhisperServerArgs`: test CLI flag parsing, default host `127.0.0.1`, port `8765`, model `turbo`, and environment variable overrides.
- `TestGetDefaultDevice`: test CUDA availability returning `cuda`, MPS returning `mps`, fallback to `cpu`, and `WHISPER_DEVICE` override.
- `TestWhisperRequestHandler`: test `/health` GET handler and `/v1/models` GET handler.
- `TestWhisperTranscriptionHandling`: test POST request validation (reject missing file, reject non-audio).

- [ ] **Step 3: Run unit tests**

Run: `python3 -m unittest tests/test_whisper_server.py`
Expected: All tests PASS (exit 0).

- [ ] **Step 4: Commit**

```bash
git add lib/whisper_server.py tests/test_whisper_server.py
git commit -m "feat: vendor persistent whisper server and test suite"
```

---

### Task 3: Unified `bin/run-model` Script & CLI Test Harness

**Files:**
- Modify: `bin/run-model`
- Create: `tests/test_run_model.sh`

**Interfaces:**
- Consumes: `llama-server`, `lib/whisper_server.py`, `bin/download-model`.
- Produces: `bin/run-model` supporting `text`, `multimodal`, and `transcription` with `-q 4|6|8`, `-c <size>`, `-H <host>`, `-p <port>`, `--speculative`, `--dry-run`.

- [ ] **Step 1: Write CLI test harness in `tests/test_run_model.sh`**

Test cases for `--dry-run`:
- `bin/run-model text --dry-run` -> outputs `llama-server` with `Mistral-Small-3.2-24B-Instruct-2506-UD-Q4_K_XL.gguf`, alias `jzaleski/text`, port 8080, ctx 65536, batch 2048, ubatch 1024, mlock.
- `bin/run-model text -q 6 --dry-run` -> outputs model `Mistral-Small-3.2-24B-Instruct-2506-UD-Q6_K_XL.gguf`.
- `bin/run-model text -q 8 --dry-run` -> outputs model `Mistral-Small-3.2-24B-Instruct-2506-UD-Q8_K_XL.gguf`.
- `bin/run-model text -c 262144 --dry-run` -> outputs `--ctx-size 262144`.
- `bin/run-model multimodal --dry-run` -> outputs `llama-server` with `Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf`, `--mmproj`, alias `jzaleski/multimodal`, port 8081, ctx 65536.
- `bin/run-model multimodal -q 6 --dry-run` -> outputs `Qwen3.8-Flash-Next-UD-Q6_K_XL-00001-of-00006.gguf`.
- `bin/run-model transcription --dry-run` -> outputs python execution of `lib/whisper_server.py` with port 8765 and `--model turbo`.
- `bin/run-model invalid_purpose` -> fails with exit code 1.
- Make executable: `chmod +x tests/test_run_model.sh`.

- [ ] **Step 2: Run test harness to verify failure before implementation**

Run: `bash tests/test_run_model.sh`
Expected: FAIL (current `bin/run-model` does not support these flags or purposes).

- [ ] **Step 3: Implement unified `bin/run-model`**

Rewrite `bin/run-model`:
- Parse flags: `-h/--help`, `-q/--quantization` (default 4), `-H/--host` (default 127.0.0.1 or HOST), `-p/--port`, `-m/--model`, `-c/--ctx-size` (default 65536), `-ngl/--n-gpu-layers` (default -1), `-t/--threads` (default 8), `--temp`, `--top-k`, `--top-p`, `--jinja`, `--flash-attn`, `--speculative`, `--no-speculative`, `--spec-type`, `-md/--draft-model`, `--draft-max`, `--device`, `--dry-run`, `-- <extra args>`.
- Parse purpose positional arg (`text`, `multimodal`, `transcription`, defaulting to `text` if not specified).
- **For `transcription`:**
  - Find Python binary (probe `.venv/bin/python`, `$VIRTUAL_ENV/bin/python`, `pyenv which python3`, `python3`).
  - Verify `import whisper` works or exit 1 with clear diagnostic.
  - Port defaults: `8765` (or `PORT`).
  - If `--dry-run`: echo command and exit 0. Else `exec "${python_bin}" "${repo_root}/lib/whisper_server.py" ...`.
- **For `text`:**
  - Select model according to `-q`:
    - `4`: `unsloth/Mistral-Small-3.2-24B-Instruct-2506-UD-Q4_K_XL.gguf`
    - `6`: `unsloth/Mistral-Small-3.2-24B-Instruct-2506-UD-Q6_K_XL.gguf` (fallback `UD-Q5_K_XL.gguf` if present on disk)
    - `8`: `unsloth/Mistral-Small-3.2-24B-Instruct-2506-UD-Q8_K_XL.gguf`
  - HF repo: `unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF`.
  - Default port: `8080`. Alias: `jzaleski/text`.
  - Tuning defaults: `--batch-size 2048 --ubatch-size 1024 --cache-type-k q8_0 --cache-type-v q8_0 --load-mode mlock --cache-reuse 256 --cache-ram -1 --jinja --temp 0.15 --top-k -1 --top-p 1.00`.
  - Speculative auto-detection: if draft file exists or `-md` passed, apply `--spec-type draft-simple --spec-draft-model <file> --spec-draft-ngl -1 --spec-draft-n-max 3`.
- **For `multimodal`:**
  - Select model according to `-q`:
    - `4`: `unsloth/Qwen3.8-Flash-Next-GGUF/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL.gguf` (4 parts)
    - `6`: `unsloth/Qwen3.8-Flash-Next-GGUF/UD-Q6_K_XL/Qwen3.8-Flash-Next-UD-Q6_K_XL.gguf` (6 parts)
    - `8`: `unsloth/Qwen3.8-Flash-Next-GGUF/Q8_0/Qwen3.8-Flash-Next-Q8_0.gguf` (6 parts)
  - HF repo: `unsloth/Qwen3.8-Flash-Next-GGUF`.
  - Mmproj: `mmproj-F16.gguf` (or `mmproj-BF16.gguf` / `.mmproj`).
  - Default port: `8081`. Alias: `jzaleski/multimodal`.
  - Tuning defaults: `--batch-size 2048 --ubatch-size 1024 --cache-type-k q8_0 --cache-type-v q8_0 --load-mode mlock --cache-reuse 256 --cache-ram -1 --image-min-tokens 1024 --reasoning-preserve --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0.0`.
  - Speculative auto-detection: if MTP file exists or `-md` passed, apply `--spec-type draft-mtp --spec-draft-model <file> --spec-draft-ngl -1 --spec-draft-n-max 3`.

- [ ] **Step 4: Run test harness to verify it passes**

Run: `bash tests/test_run_model.sh`
Expected: PASS (all dry-run assertions match).

- [ ] **Step 5: Commit**

```bash
git add bin/run-model tests/test_run_model.sh
git commit -m "feat: unify run-model for text, multimodal, and transcription"
```

---

### Task 4: Remove Router Script and INI Templates

**Files:**
- Delete: `bin/run-router`
- Delete: `templates/llama-cpp-default.ini.template`
- Delete: `templates/llama-cpp-experimental.ini.template`
- Create/Keep: `templates/.keep` (if keeping templates dir for future use, or remove templates directory)

**Interfaces:**
- Removes legacy router artifacts.

- [ ] **Step 1: Remove legacy files**

```bash
git rm bin/run-router templates/llama-cpp-default.ini.template templates/llama-cpp-experimental.ini.template
```
Check if `templates` directory has other files; if empty, clean up or place `.keep`.

- [ ] **Step 2: Verify git status**

Run: `git status`
Expected: `bin/run-router` and templates deleted.

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor: remove run-router and legacy ini preset templates"
```

---

### Task 5: Update Opencode Configuration

**Files:**
- Modify: `home/.config/opencode/opencode.json`

**Interfaces:**
- Produces: Opencode configuration exposing `jzaleski/text` and `jzaleski/multimodal`.

- [ ] **Step 1: Update `home/.config/opencode/opencode.json`**

Consolidate provider block into:
```json
  "provider": {
    "jzaleski": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "jzaleski",
      "options": {
        "baseURL": "http://server-hostname-or-ip:8080/v1"
      },
      "models": {
        "jzaleski/text": {
          "name": "Text (Mistral 24B)",
          "limit": {
            "context": 65536,
            "input": 57344,
            "output": 8192
          },
          "modalities": {
            "input": ["text"],
            "output": ["text"]
          }
        },
        "jzaleski/multimodal": {
          "name": "Multimodal (Qwen3.8 Flash)",
          "limit": {
            "context": 65536,
            "input": 57344,
            "output": 8192
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          }
        }
      }
    }
  }
```
Remove `jzaleski/default` and `jzaleski/experimental` blocks.

- [ ] **Step 2: Validate JSON syntax**

Run: `jq . home/.config/opencode/opencode.json > /dev/null`
Expected: Valid JSON (exit 0).

- [ ] **Step 3: Commit**

```bash
git add home/.config/opencode/opencode.json
git commit -m "feat: update opencode provider to unified jzaleski text and multimodal models"
```

---

### Task 6: Update Documentation and Agent Guides

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`

**Interfaces:**
- Documents the unified `run-model` architecture, purpose-oriented naming, and removal of router mode.

- [ ] **Step 1: Update `AGENTS.md`**

- Update Project Overview: replace router descriptions with unified `run-model` (`text`, `multimodal`, `transcription`).
- Update Project Structure tree (remove `run-router` and `templates/llama-cpp-*.ini.template`, add `lib/whisper_server.py`, `requirements.txt`).
- Update Build/Test Commands with:
  ```bash
  ./bin/run-model                               # text generation (Mistral 24B, Q4, port 8080)
  ./bin/run-model text -q 6                     # text generation, Q6 quantization
  ./bin/run-model multimodal                    # vision-capable model (Qwen3.8 Flash Next, Q4, port 8081)
  ./bin/run-model transcription                 # Whisper transcription server (port 8765)
  HOST=0.0.0.0 ./bin/run-model text            # expose on LAN
  ```
- Update Code Style & Naming Conventions: remove router references; document purpose aliases `jzaleski/text`, `jzaleski/multimodal`, `jzaleski/transcription`.
- Update Architecture diagram to show the unified model host.

- [ ] **Step 2: Update `README.md`**

- Update Overview, project tree, and quick start examples.
- Update component documentation to describe `bin/run-model` flags and purpose modes.
- Document Python bootstrap with `pyenv`.

- [ ] **Step 3: Verify markdown formatting**

Run: `git diff AGENTS.md README.md` to inspect changes.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md README.md
git commit -m "docs: update AGENTS.md and README.md for unified run-model architecture"
```

---

## Parallel Dispatch Analysis

### Batch 1 (Independent — dispatch concurrently):
- **Worker 1 (Task 1):** Python Environment & Pyenv Bootstrap (`.default-python-version`, `requirements.txt`, `bin/configure-python`, `bin/bootstrap`, `home/.opencoderc`)
- **Worker 2 (Task 2):** Persistent Whisper Server and Unit Tests (`lib/whisper_server.py`, `tests/test_whisper_server.py`)
- **Worker 3 (Task 4):** Remove Router Script and INI Templates (`bin/run-router`, `templates/`)
- **Worker 4 (Task 5):** Update Opencode Configuration (`home/.config/opencode/opencode.json`)

*Rationale:* Each of these 4 tasks operates on completely separate files without any cross-dependencies.

### Batch 2 (Depends on Batch 1):
- **Worker 5 (Task 3):** Unified `bin/run-model` Script & CLI Test Harness (`bin/run-model`, `tests/test_run_model.sh`)

*Rationale:* `bin/run-model` relies on `lib/whisper_server.py` (from Task 2) for transcription verification and replaces the legacy routing logic cleanly after Task 4.

### Batch 3 (Depends on Batch 2):
- **Worker 6 (Task 6):** Documentation Updates (`AGENTS.md`, `README.md`)

*Rationale:* Documentation documents the finalized, verified state of all prior tasks.
