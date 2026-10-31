# Multi Model Alias and Server Consistency Implementation Plan

> **For agentic workers:** Use skills/coder to implement each task. Read the full task description — don't summarize or skip steps.

**Goal:** Standardize model alias and CLI purpose to `multi` (`jzaleski/multi`), unify environment variable precedence (`WHISPER_*` > `HOST`/`PORT` > default), and align CLI flag handling across server wrappers.

**Architecture:** Update `lib/whisper_server.py` argument parsing to support short flags and fallback to generic `HOST`/`PORT`; update `bin/run-model` to handle `multi`/`--multi`, resolve transcription environment precedence, and support `-d/--device`; update opencode provider configuration; synchronize documentation; and verify against full test suites.

**Tech Stack:** Bash, Python 3 (argparse, unittest), JSON, Markdown.

**Spec:** `docs/specs/2026-10-31-multi-model-alias-design.md`

## Global Constraints

- Posix shell & Bash 3.2+ compatibility with `set -e` error handling.
- Python standard library only for `lib/whisper_server.py` argument parsing (`argparse`, `os`).
- No backward compatibility flags for `multimodal` or `--multimodal`.
- Port allocations remain 8080 (`text`), 8081 (`multi`), and 8765 (`transcription`).
- `opencode.json` must be valid JSON adhering to opencode provider schema.

## Review Focus

1. `HOST` and `PORT` set without `WHISPER_*`: Whisper server and wrapper bind to `HOST` and `PORT`.
2. `WHISPER_HOST` or `WHISPER_PORT` set alongside `HOST` or `PORT`: `WHISPER_*` takes precedence.
3. CLI flags (`-H`, `-p`, `-m`, `-d`): CLI flags override all environment variables.
4. Purpose `multi` and flag `--multi` / `-m`: Sets alias `jzaleski/multi` on port 8081.
5. Rejection of legacy `multimodal` / `--multimodal`: Fails with exit code 1 as an unknown option or purpose.

---

### Task 1: Whisper Server Environment Hierarchy & Flag Parity

**Files:**
- Modify: `lib/whisper_server.py:48-74`
- Test: `tests/test_whisper_server.py:18-60`

**Interfaces:**
- Consumes: `os.getenv("WHISPER_HOST")`, `os.getenv("HOST")`, `os.getenv("WHISPER_PORT")`, `os.getenv("PORT")`, `os.getenv("WHISPER_MODEL")`, `os.getenv("WHISPER_DEVICE")`
- Produces: `ws.parse_args()` returning `Namespace(host=..., port=..., model=..., device=...)`

- [ ] **Step 1: Write failing tests for general `HOST`/`PORT` fallback and short flags in `tests/test_whisper_server.py`**

Add tests to `TestWhisperServerArgs`:
```python
    def test_parse_args_general_env_fallback(self):
        env = {
            "HOST": "0.0.0.0",
            "PORT": "9000",
        }
        with patch.object(sys, "argv", ["whisper_server.py"]):
            with patch.dict(os.environ, env, clear=True):
                args = ws.parse_args()
                self.assertEqual(args.host, "0.0.0.0")
                self.assertEqual(args.port, 9000)

    def test_parse_args_whisper_env_precedence_over_general(self):
        env = {
            "HOST": "1.1.1.1",
            "PORT": "8000",
            "WHISPER_HOST": "2.2.2.2",
            "WHISPER_PORT": "8888",
        }
        with patch.object(sys, "argv", ["whisper_server.py"]):
            with patch.dict(os.environ, env, clear=True):
                args = ws.parse_args()
                self.assertEqual(args.host, "2.2.2.2")
                self.assertEqual(args.port, 8888)

    def test_parse_args_short_flags(self):
        cli = [
            "whisper_server.py",
            "-H", "192.168.1.100",
            "-p", "8999",
            "-m", "medium",
            "-d", "cpu",
        ]
        with patch.object(sys, "argv", cli):
            with patch.dict(os.environ, {}, clear=True):
                args = ws.parse_args()
                self.assertEqual(args.host, "192.168.1.100")
                self.assertEqual(args.port, 8999)
                self.assertEqual(args.model, "medium")
                self.assertEqual(args.device, "cpu")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m unittest tests/test_whisper_server.py`
Expected: FAIL with unrecognized arguments or mismatched defaults.

- [ ] **Step 3: Update `parse_args()` in `lib/whisper_server.py`**

Update `parse_args()` in `lib/whisper_server.py`:
- Add `-H` alias to `--host`, default: `os.getenv("WHISPER_HOST") or os.getenv("HOST") or "127.0.0.1"`
- Add `-p` alias to `--port`, default: `int(os.getenv("WHISPER_PORT") or os.getenv("PORT") or "8765")`
- Add `-m` alias to `--model`, default: `os.getenv("WHISPER_MODEL") or "turbo"`
- Add `-d` alias to `--device`, default: `get_default_device()`

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m unittest tests/test_whisper_server.py`
Expected: PASS (Ran 24 tests, OK).

- [ ] **Step 5: Commit**

```bash
git add lib/whisper_server.py tests/test_whisper_server.py
git commit -m "feat: add short flags and env precedence fallback to whisper server"
```

---

### Task 2: Update `bin/run-model` for `multi` Purpose and Server Consistency

**Files:**
- Modify: `bin/run-model:90-125,184-192,316-325,338-349,375-381,391-422,525-560`
- Test: `tests/test_run_model.sh`

**Interfaces:**
- Consumes: CLI args `multi`, `-m`, `--multi`, `-d`, `--device`, `WHISPER_HOST`, `WHISPER_PORT`, `WHISPER_MODEL`, `WHISPER_DEVICE`, `HOST`, `PORT`
- Produces: `bin/run-model` CLI commands for `llama-server` (alias `jzaleski/multi`) and `whisper_server.py`

- [ ] **Step 1: Update test harness in `tests/test_run_model.sh`**

Modify `tests/test_run_model.sh`:
- Change Test 5 from `bin/run-model multimodal --dry-run` to `bin/run-model multi --dry-run` and assert `jzaleski/multi` and port 8081.
- Change Test 6 from `bin/run-model multimodal -q 6 --dry-run` to `bin/run-model multi -q 6 --dry-run`.
- Change Test 7 from `bin/run-model multimodal -q 8 --dry-run` to `bin/run-model multi -q 8 --dry-run`.
- Change Test 17 from `bin/run-model --purpose multimodal --dry-run` to `bin/run-model --purpose multi --dry-run`.
- Change Test 18 from `bin/run-model --multimodal --dry-run` to `bin/run-model --multi --dry-run` (assert `jzaleski/multi`).
- Add Test 19: `bin/run-model -m --dry-run` (when purpose unset, `-m` runs multi; assert `jzaleski/multi` on port 8081).
- Add Test 20: `bin/run-model multimodal --dry-run` (assert fails with exit code 1).
- Add Test 21: `bin/run-model transcription -d cpu --dry-run` (assert `--device cpu`).
- Add Test 22: `bin/run-model transcription` with `WHISPER_HOST=0.0.0.0 WHISPER_PORT=9100 WHISPER_MODEL=small --dry-run` (assert `--host 0.0.0.0`, `--port 9100`, `--model small`).

- [ ] **Step 2: Run test harness to verify new tests fail**

Run: `bash tests/test_run_model.sh`
Expected: FAIL on `multi` tests.

- [ ] **Step 3: Update `bin/run-model`**

In `bin/run-model`:
1. Update help text:
   - Usage: `bin/run-model [text|multi|transcription]`
   - Purpose list: `multi: Qwen3.8 Flash Next with mmproj (port 8081, alias jzaleski/multi)`
   - Option: `-m, --multi: Run multi model (alias jzaleski/multi)`
   - Option: `-d, --device <device>: Inference device for transcription: auto, mps, cuda, cpu (default: auto)`
2. Argument parsing:
   - Add flag tracking variables (e.g., `host_cli=""`, `port_cli=""`, `model_cli=""`, `device_cli=""`).
   - Replace `-m|--model)` with `-M|--model)` or handle `-m|--multi)` vs model flag. Wait: in `bin/run-model`, currently `-m|--model` is used for model path/name, and there was no `-m` shorthand for multimodal. Let's make `-m|--multi` activate purpose `multi` (or keep `--multi`, and support `-m` for model or `-m|--multi` when no arg). Wait! Look at lines 184-192 in `bin/run-model`: `-m|--model` sets model name. In the spec: `--multi` is the shorthand flag. Support `--multi` for purpose multi, and `-d|--device` for device.
   - Replace `--multimodal` with `--multi`.
   - In positional purpose handling, allow `multi`, remove `multimodal`.
   - Update valid purpose validation: `text|multi|transcription`.
3. In `purpose == "transcription"` block:
   - Evaluate host: `${host_cli:-${WHISPER_HOST:-${HOST:-"127.0.0.1"}}}`
   - Evaluate port: `${port_cli:-${WHISPER_PORT:-${PORT:-8765}}}`
   - Evaluate model: `${model_cli:-${WHISPER_MODEL:-"turbo"}}}`
   - Evaluate device: `${device_cli:-${WHISPER_DEVICE:-"auto"}}}`
4. In execution block:
   - Change `if [[ "${purpose}" == "multimodal" ]]; then` to `if [[ "${purpose}" == "multi" ]]; then`
   - Set `alias_name="jzaleski/multi"`

- [ ] **Step 4: Run test harness to verify it passes**

Run: `bash tests/test_run_model.sh`
Expected: PASS (All tests passed, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add bin/run-model tests/test_run_model.sh
git commit -m "feat: rename multimodal purpose to multi and support whisper env/flag parity"
```

---

### Task 3: Update Opencode Provider Configuration

**Files:**
- Modify: `home/.config/opencode/opencode.json:40-55`

**Interfaces:**
- Consumes: `opencode.json` provider config
- Produces: Provider model definition `"jzaleski/multi"` with port 8081 and text+image modalities

- [ ] **Step 1: Update `home/.config/opencode/opencode.json`**

Rename key `"jzaleski/multimodal"` to `"jzaleski/multi"` and update its name attribute to `"jzaleski/multi"`.

- [ ] **Step 2: Validate JSON syntax**

Run: `jq . home/.config/opencode/opencode.json >/dev/null`
Expected: Exit code 0 (valid JSON).

- [ ] **Step 3: Commit**

```bash
git add home/.config/opencode/opencode.json
git commit -m "feat: update opencode provider model alias to jzaleski/multi"
```

---

### Task 4: Synchronize Documentation and Agent Guidelines

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: Approved spec `docs/specs/2026-10-31-multi-model-alias-design.md`
- Produces: Fully synchronized documentation and guidelines reflecting `multi` and `WHISPER_*` / `HOST` / `PORT` hierarchy

- [ ] **Step 1: Update `AGENTS.md`**

In `AGENTS.md`:
- Replace all references to `jzaleski/multimodal` with `jzaleski/multi`.
- Replace all references to purpose `multimodal` with `multi`.
- Update architecture diagrams and tables.
- Update environment variables table with `WHISPER_HOST`, `WHISPER_PORT`, `WHISPER_MODEL`.

- [ ] **Step 2: Update `README.md`**

In `README.md`:
- Replace all references to `jzaleski/multimodal` with `jzaleski/multi`.
- Replace all references to purpose `multimodal` / `--multimodal` with `multi` / `--multi`.
- Update architecture diagrams, quickstart CLI commands, curl examples, and tables.
- Document environment variable fallbacks for transcription (`WHISPER_HOST`, `WHISPER_PORT`, `WHISPER_MODEL`).

- [ ] **Step 3: Run full verification across test suites**

Run:
```bash
bash tests/test_run_model.sh
python3 -m unittest discover -s tests
```
Expected: Both test suites pass with 0 failures.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md README.md
git commit -m "docs: update AGENTS.md and README.md for multi alias and whisper env parity"
```

---

## Parallel Dispatch Analysis

### Batch 1 (Independent — Dispatch Together):
- **Task 1** (`lib/whisper_server.py`, `tests/test_whisper_server.py`)
  *Rationale:* Python server arg parsing and unit tests. Completely isolated from shell script and JSON.
- **Task 2** (`bin/run-model`, `tests/test_run_model.sh`)
  *Rationale:* Bash launcher script and test harness. Completely isolated from Python files and JSON.
- **Task 3** (`home/.config/opencode/opencode.json`)
  *Rationale:* Static JSON configuration for opencode provider. Completely isolated from code and tests.
- **Task 4** (`README.md`, `AGENTS.md`)
  *Rationale:* Markdown documentation updates. Completely isolated from code and configs.

*All four tasks touch mutually disjoint sets of files with zero shared mutable state, so they can be dispatched in parallel or sequentially executed cleanly.*
