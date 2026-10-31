# AI Tools

Utilities for running local LLMs and audio transcription servers

## Overview

This repository provides unified scripts and configurations for hosting local AI models: `llama-server` for text and multimodal LLM inference, and a persistent Python server for OpenAI-compatible Whisper audio transcription.

All model hosting is unified behind a single entrypoint `bin/run-model` with purpose-oriented model aliases:
- **`jzaleski/text`**: Mistral-Small 3.2 24B Instruct running on port 8080 (default). High-throughput text generation and coding model with Jinja templating, flash attention, and auto-detected speculative decoding (`draft-simple`).
- **`jzaleski/multi`**: Qwen3.8-Flash-Next running on port 8080 with an F16 multimodal projector (`--mmproj`, auto-downloaded). Vision-capable model with reasoning preservation and auto-detected MTP speculative decoding (`draft-mtp`).
- **`jzaleski/transcription`**: Persistent OpenAI-compatible Whisper HTTP server running on port 8765 (`lib/whisper_server.py`). Supports `/v1/audio/transcriptions` (both `multipart/form-data` uploads and JSON payloads with local file paths), `/health`, and `/v1/models` with hardware-accelerated inference (`cuda` -> `mps` -> `cpu`).

Both LLMs support standard quantizations (`-q 4|6|8`, defaulting to `4`), a universal 64K default context window (`65536` tokens, overrideable via `-c / --ctx-size` or `CTX_SIZE`), and full unified memory optimizations (`--load-mode mlock`, `--cache-reuse 256`, `--cache-ram -1`). Bind address is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN). Listen ports default to `8080` (text/multi LLMs) and `8765` (transcription), overrideable via `PORT` or `-p / --port`.

Models are loaded from HuggingFace and quantized for efficient local inference.

## Project Structure

```
.
├── bin/                            # Main execution scripts
│   ├── bootstrap                   # System setup and configuration bootstrap
│   ├── install-dependencies        # Installs/upgrades Homebrew base packages
│   ├── configure-git               # Configures global git settings (core.excludesfile)
│   ├── configure-python            # Sets up pyenv, installs Python 3.14.3 and requirements.txt
│   ├── configure-opencode          # Installs opencode via the anomalyco/tap Homebrew tap, configures shell init
│   ├── download-model              # Downloads a single GGUF file from Hugging Face via curl
│   └── run-model                   # Unified model launcher (text, multi, transcription)
├── lib/                            # Supporting server libraries
│   └── whisper_server.py           # Persistent OpenAI-compatible Whisper HTTP server
├── tests/                          # Test suites
│   ├── test_run_model.sh           # CLI test harness for bin/run-model
│   └── test_whisper_server.py      # Unit tests for persistent Whisper server
├── home/                           # Dotfiles and config files to symlink
│   ├── .config/opencode/           # Opencode configuration and agent definitions
│   │   ├── agents/
│   │   │   ├── data.md             # Data pipeline orchestrator
│   │   │   ├── engineer.md         # Adaptive software engineer (default)
│   │   │   └── product.md          # Work-shaping persona (triage → scope → refine → handoff)
│   │   ├── skills/                 # Vendored workflow skills (no external plugins)
│   │   │   ├── analyze/            # Find patterns / answer questions (pipeline stage 2)
│   │   │   ├── coder/              # Sub-agent implementer (TDD, self-review)
│   │   │   ├── debugging/          # Root cause analysis for bugs and test failures
│   │   │   ├── finisher/           # Verify, merge/PR, cleanup
│   │   │   ├── handoff/            # Package a refined brief into a liftable eng hand-off (product stage 3)
│   │   │   ├── ingest/             # Extract + clean + normalize raw files (pipeline stage 1)
│   │   │   ├── planner/            # Task decomposition + independence analysis
│   │   │   ├── refine/             # Mature a scope into a ticket-ready brief (product stage 2)
│   │   │   ├── report/             # Deliver findings in one+ formats (pipeline stage 3)
│   │   │   ├── researcher/         # Design & discovery (approval-gated)
│   │   │   ├── reviewer/           # Spec compliance + code quality review
│   │   │   ├── scope/              # Stakeholder requirements intake (product stage 1)
│   │   │   ├── test-driven-development/ # Red-Green-Refactor & good test guidelines
│   │   │   ├── triage/             # Classify & route an inbound request (product front door)
│   │   │   └── verification-before-completion/ # Evidence-before-claims gate function
│   │   └── opencode.json           # Opencode provider and agent configuration
│   ├── .local/lib/
│   │   └── opencode.sh             # Opencode wrapper script (session persistence, cache reset)
│   └── .opencoderc                 # Shell alias: opencode → ~/.local/lib/opencode.sh
├── .default-python-version         # Default Python version for pyenv (3.14.3)
└── requirements.txt                # Python dependencies (openai-whisper, torch)
```

## Bootstrap System

The project includes a bootstrap system for setting up your development environment:

```bash
# Run bootstrap (will prompt before overwriting)
bin/bootstrap

# Run bootstrap non-interactively (overwrite without prompt)
ASSUME_YES=true bin/bootstrap
```

The bootstrap script:
- Initializes and updates git submodules if present (none currently)
- Copies files from `home/` to your `$HOME` directory
- Runs an explicit ordered array of scripts from `bin/`

### Bootstrap Scripts

Scripts run in the order defined in the `bin_scripts` array in `bin/bootstrap`:

| Script | Purpose |
|--------|---------|
| `bin/install-dependencies` | Installs Homebrew (if missing) and installs/upgrades: `ag`, `btop`, `curl`, `git`, `jq`, `htop`, `llama.cpp`, `nvtop`, `openssl`, `readline`, `sqlite`, `wget`, `zsh` |
| `bin/configure-git` | Configures global git settings — sets `core.excludesfile` to `~/.gitignore` if not already set |
| `bin/configure-python` | Sets up `pyenv` at `~/.pyenv`, installs Python version from `.default-python-version` (`3.14.3`), and installs pip packages from `requirements.txt` (`openai-whisper`, `torch`) |
| `bin/configure-opencode` | Adds the `anomalyco/tap` Homebrew tap (if not already tapped) and installs/upgrades `anomalyco/tap/opencode`; appends `.opencoderc` sourcing to `~/.bashrc` and `~/.zshrc` |

To run only a subset of scripts, use `BOOTSTRAP_SCRIPTS`:
```bash
BOOTSTRAP_SCRIPTS="configure-git,configure-opencode" bin/bootstrap
```
To skip specific scripts, use `BOOTSTRAP_SKIP`:
```bash
BOOTSTRAP_SKIP="install-dependencies" bin/bootstrap
```

## Prerequisites

- At least 16GB RAM for 20B+ models (Apple Silicon or Linux CUDA)
- GPU support (recommended: Apple Silicon Metal / NVIDIA CUDA)
- Homebrew (macOS)
- Python 3.10+ (managed via `pyenv` by `bin/configure-python`)
- `ffmpeg` (required for Whisper audio transcription)

## Opencode Agent Configuration(s)

### Gemini 3.1 Pro Specific Adjustments

Gemini tends to skip tool calls (like `skill` and `task`) and attempts to simulate their execution inline. To prevent this, the agents and prompt templates have been updated with `CRITICAL` sections forcing literal tool execution.

The project includes `opencode` agent configurations in `home/.config/opencode/`:

- **data.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
- **product.md**: Work-shaping persona — runs the triage skill to classify and route an inbound request, the scope skill to capture a stakeholder's requirements as a right-sized artifact, the refine skill to mature it (with engineering) into a ticket-ready brief, and the handoff skill to package it into a liftable engineering hand-off

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `engineer`.

> **See [`docs/agents-and-skills.md`](docs/agents-and-skills.md) for a comprehensive reference** describing every agent and every skill — their responsibilities, execution model (inline vs. dispatched sub-agent), hard gates, persistence, and how the three workflows fit together.

### Local Skills

Workflow skills are vendored locally under `home/.config/opencode/skills/` (15 total: 8 engineering, 3 data, 4 product) — no external plugin dependencies.

**Engineering lifecycle** (orchestrated by `engineer`):

| Skill | Purpose |
|-------|---------|
| `researcher` | Design & discovery — clarifying questions, approach proposals, spec writing with user approval gate |
| `planner` | Task decomposition with exact file paths, code, commands, and parallel-dispatch independence analysis |
| `coder` | Sub-agent implementer — TDD, self-review, structured status reporting |
| `debugging` | Root cause analysis for bugs, test failures, or unexpected behavior |
| `reviewer` | Dual-mode review — spec compliance (did they build what was asked?) then code quality |
| `finisher` | Verify tests, detect workspace state, present merge/PR options, execute with cleanup |
| `test-driven-development` | Red-Green-Refactor iron law and good test guidelines before writing production code |
| `verification-before-completion` | Evidence-before-claims gate function and rationalization prevention before any completion claim |

**Data pipeline** (orchestrated by `data`):

| Skill | Purpose |
|-------|---------|
| `ingest` | Extract data from raw files (PDF, XLSX, CSV, JSON, HTML, Markdown, text), clean each, converge into one normalized dataset; parallelizes per-file via an escalation ladder |
| `analyze` | Single-pass findings on the clean dataset — aggregations, comparisons, trends, outliers, distributions, joins |
| `report` | Deliver findings in one or more formats (Markdown, CSV, XLSX, JSON, text, inline) with a mandatory Artifacts & Scripts section |

**Product funnel** (orchestrated by `product`):

| Skill | Purpose |
|-------|---------|
| `triage` | Inbound request front door — fast, single-pass classification into product / engineering / data / needs-info / not-actionable, with a routing recommendation; inline-only, recommends but never invokes |
| `scope` | Stakeholder requirements intake — adaptive (capped questions when thin, draft-and-trim when bloated), produces a right-sized, refinable scope artifact; honest about what a non-technical stakeholder cannot know |
| `refine` | Technical-PM maturation — augments the same scope document with system considerations, authoritative scope, complexity, resolved open questions, and a ticket breakdown |
| `handoff` | Engineering hand-off packaging — turns the refined brief into a self-contained, liftable hand-off artifact (written to `docs/handoffs/`) that seeds the engineer agent's design phase |

## Environment Variables

You can override default settings via environment variables.

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST` | Network interface address to bind the server to | `127.0.0.1` (set `0.0.0.0` to expose on the LAN) |
| `PORT` | Network port for the server to listen on | `8080` (text/multi), `8765` (transcription) |
| `WHISPER_HOST` | Bind address override for Whisper server | `${HOST:-127.0.0.1}` |
| `WHISPER_PORT` | Network port override for Whisper server | `${PORT:-8765}` |
| `WHISPER_MODEL` | Whisper transcription model name | `turbo` |
| `MODELS_DIR` | Directory for downloaded GGUF models | `~/.cache/models` |
| `CTX_SIZE` | Context window size in tokens | `65536` |
| `N_GPU_LAYERS` | Number of layers offloaded to GPU | `-1` (all) |
| `THREADS` | Number of CPU threads to use for inference | `8` |
| `WHISPER_DEVICE` | Compute device for Whisper transcription (`auto`, `mps`, `cuda`, `cpu`) | `auto` |

For transcription, specific variables (`WHISPER_HOST`, `WHISPER_PORT`, `WHISPER_MODEL`, `WHISPER_DEVICE`) take precedence over generic variables (`HOST`, `PORT`), which fall back to their respective defaults. CLI flags always take highest precedence.

## Components

### run-model
Unified model launcher driving `llama-server` for text and multi models, and `lib/whisper_server.py` for audio transcription. Accepts an optional positional purpose argument (`text`, `multi`, `transcription`, defaulting to `text`):

```bash
bin/run-model [options] [text|multi|transcription] [-- <additional args>]
# Or with explicit flags:
bin/run-model --purpose <purpose> [options]
bin/run-model --text | --multi | --transcription [options]
```

**Purposes:**
- **`text`** (default): Mistral Small 3.2 24B Instruct running on port 8080 (alias `jzaleski/text`). High-speed, high-accuracy model with Jinja templating, flash attention, and auto-detected `draft-simple` speculative decoding.
- **`multi`**: Qwen3.8 Flash Next running on port 8080 (alias `jzaleski/multi`) with an F16 multimodal projector (`--mmproj`, auto-downloaded). Vision-capable model with reasoning preservation and auto-detected `draft-mtp` speculative decoding.
- **`transcription`**: Persistent OpenAI-compatible Whisper HTTP server running on port 8765 (`lib/whisper_server.py`). Supports `/v1/audio/transcriptions`, `/health`, and `/v1/models` with hardware-accelerated inference (`cuda` -> `mps` -> `cpu`).

**CLI Options:**
- `-q, --quantization <4|6|8>`: Model quantization (default: `4`). Applies to `text` and `multi`.
- `-H, --host <host>`: Host interface to bind (default: `127.0.0.1` or `HOST` env var).
- `-p, --port <port>`: Port to listen on (default: `8080` for text/multi, `8765` for transcription, or `PORT` env var).
- `-m, --model <path|name>`: Override model GGUF path (for text/multi) or Whisper model name (for transcription, default `turbo`).
- `-c, --ctx-size <size>`: Context window tokens (default: `65536` or `CTX_SIZE` env var; easily overridden to `131072`, `262144`, etc.).
- `-ngl, --n-gpu-layers <n>`: Number of layers offloaded to GPU (default: `-1` or `N_GPU_LAYERS`).
- `-t, --threads <n>`: CPU threads to use for inference (default: `8` or `THREADS`).
- `--temp <temp>`: Sampling temperature (default: `0.15` for text, `1.0` for multi).
- `--top-k <k>`: Top-k sampling threshold (default: `-1` for text, `20` for multi).
- `--top-p <p>`: Top-p sampling threshold (default: `1.00` for text, `0.95` for multi).
- `--min-p <p>`: Min-p sampling threshold (default: `0.0` for multi).
- `--jinja / --no-jinja`: Enable or disable Jinja templating (default: enabled).
- `-fa, --flash-attn [on|off|auto]`: Flash attention mode (default: `on`).
- `--speculative / --no-speculative`: Speculative decoding (default: auto-detected when co-located draft or MTP files are found).
- `--spec-type <type>`: Speculative decoding algorithm (`draft-simple` for text, `draft-mtp` for multi).
- `-md, --draft-model <path>`: Explicit path to draft model GGUF or MTP file.
- `--draft-max <n>`: Number of draft tokens to predict (default: `5`).
- `--chat-template-kwargs <json>`: Chat template kwargs JSON (default: `'{"reasoning_effort":"medium"}'` for multi).
- `-d, --device <device>`: Inference device for Whisper transcription (`auto`, `mps`, `cuda`, `cpu`; default: `auto`).
- `--dry-run`: Print the underlying command without executing.
- `--multi`: Run multi model (alias `jzaleski/multi`).
- `-- <args>`: Pass additional arguments directly to the backend (`llama-server` or `whisper_server.py`).

**Model Mapping & Quantization Matrix:**

| Purpose | Quant | Model File / Split Pattern | Hugging Face Repository | Key Tuning Defaults |
|---|---|---|---|---|
| `text` (default) | `4` (default) | `Mistral-Small-3.2-24B-Instruct-2506-UD-Q4_K_XL.gguf` | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF` | ctx `65536`, batch `2048`, ubatch `1024`, cache K/V `q8_0`/`q8_0`, temp `0.15`, jinja on, flash-attn on, mlock on, cache-reuse `256`, cache-ram `-1`, speculative auto-detect |
| `text` | `6` | `Mistral-Small-3.2-24B-Instruct-2506-UD-Q6_K_XL.gguf` (fallback: `UD-Q5_K_XL.gguf`) | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF` | ctx `65536`, batch `2048`, ubatch `1024`, cache K/V `q8_0`/`q8_0`, temp `0.15`, jinja on, flash-attn on, mlock on, cache-reuse `256`, cache-ram `-1`, speculative auto-detect |
| `text` | `8` | `Mistral-Small-3.2-24B-Instruct-2506-UD-Q8_K_XL.gguf` | `unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF` | ctx `65536`, batch `2048`, ubatch `1024`, cache K/V `q8_0`/`q8_0`, temp `0.15`, jinja on, flash-attn on, mlock on, cache-reuse `256`, cache-ram `-1`, speculative auto-detect |
| `multi` | `4` (default) | `UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf` (4 parts) + `mmproj-F16.gguf` | `unsloth/Qwen3.8-Flash-Next-GGUF` | ctx `65536`, batch `2048`, ubatch `1024`, cache K/V `q8_0`/`q8_0`, temp `1.0`, top-k `20`, top-p `0.95`, min-p `0.0`, flash-attn on, mlock on, image-min-tokens `1024`, reasoning-preserve on, cache-reuse `256`, cache-ram `-1`, speculative auto-detect |
| `multi` | `6` | `UD-Q6_K_XL/Qwen3.8-Flash-Next-UD-Q6_K_XL-00001-of-00006.gguf` (6 parts) + `mmproj-F16.gguf` | `unsloth/Qwen3.8-Flash-Next-GGUF` | ctx `65536`, batch `2048`, ubatch `1024`, cache K/V `q8_0`/`q8_0`, temp `1.0`, top-k `20`, top-p `0.95`, min-p `0.0`, flash-attn on, mlock on, image-min-tokens `1024`, reasoning-preserve on, cache-reuse `256`, cache-ram `-1`, speculative auto-detect |
| `multi` | `8` | `Q8_0/Qwen3.8-Flash-Next-Q8_0-00001-of-00006.gguf` (6 parts) + `mmproj-F16.gguf` | `unsloth/Qwen3.8-Flash-Next-GGUF` | ctx `65536`, batch `2048`, ubatch `1024`, cache K/V `q8_0`/`q8_0`, temp `1.0`, top-k `20`, top-p `0.95`, min-p `0.0`, flash-attn on, mlock on, image-min-tokens `1024`, reasoning-preserve on, cache-reuse `256`, cache-ram `-1`, speculative auto-detect |
| `transcription` | N/A | Downloaded via OpenAI Whisper cache (`~/.cache/whisper`) | `openai/whisper` (default `turbo`) | auto-detect `cuda` -> `mps` -> `cpu`, disable FP16 on CPU, thread-safe inference lock |

### whisper_server.py
A persistent Python HTTP server (`lib/whisper_server.py`) exposing an OpenAI-compatible transcription interface:
- **`POST /v1/audio/transcriptions`**: Supports both `multipart/form-data` file uploads and JSON bodies containing a local `file_path` or `path`.
- **`GET /health`**: Health check reporting server status, loaded model, active device, and MPS/CUDA availability.
- **`GET /v1/models`**: Lists available Whisper models.
- **CLI Options**: Supports `-H, --host`, `-p, --port`, `-m, --model`, `-d, --device` aligning with `run-model`.
- **Environment Precedence**: Specific overrides (`WHISPER_HOST`, `WHISPER_PORT`, `WHISPER_MODEL`, `WHISPER_DEVICE`) > general overrides (`HOST`, `PORT`) > defaults.
- **Acceleration**: Automatically selects `cuda` (if NVIDIA GPU present), `mps` (Apple Silicon Metal Performance Shaders), or `cpu`. Automatically disables FP16 precision on CPU to prevent PyTorch warnings.
- **Concurrency**: Thread-safe single-instance inference protected by a mutex lock.

## Usage

```bash
# Start text generation server (default: Mistral Small 3.2 24B, Q4, port 8080)
./bin/run-model
./bin/run-model text

# Start text generation with Q6 quantization
./bin/run-model text -q 6

# Start vision-capable model (Qwen3.8 Flash Next, Q4, port 8080)
./bin/run-model multi

# Start vision-capable model with Q6 quantization
./bin/run-model multi -q 6

# Start persistent Whisper transcription server (port 8765)
./bin/run-model transcription

# Expose on the LAN
HOST=0.0.0.0 ./bin/run-model text

# Override context size or port
./bin/run-model text -c 131072 -p 8888

# Dry run to inspect the exact underlying command
./bin/run-model text -q 6 --dry-run
```

### Client API Examples

**Text completions (`jzaleski/text` on port 8080):**
```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jzaleski/text",
    "messages": [{"role": "user", "content": "Explain unified memory in Apple Silicon."}]
  }'
```

**Multimodal completions (`jzaleski/multi` on port 8080):**
```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jzaleski/multi",
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": "Describe this architecture diagram."},
          {"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}
        ]
      }
    ]
  }'
```

**Audio transcription via file upload (port 8765):**
```bash
curl http://localhost:8765/v1/audio/transcriptions \
  -F "file=@/path/to/recording.mp3" \
  -F "model=turbo"
```

**Audio transcription via local file path (port 8765):**
```bash
curl http://localhost:8765/v1/audio/transcriptions \
  -H "Content-Type: application/json" \
  -d '{"file_path": "/path/to/recording.mp3"}'
```

**Transcription health check:**
```bash
curl http://localhost:8765/health
```

## Architecture

All model execution is consolidated under `bin/run-model`. It drives `llama-server` for text and multi LLMs and `lib/whisper_server.py` for persistent Whisper audio transcription:

```
┌────────────────────────────────────────────────────────────────────────┐
│                             bin/run-model                              │
│               (Unified CLI: text, multi, transcription)                │
└───────────────┬────────────────────────┬───────────────────────────────┘
                │                        │                               │
    ┌───────────┴──────────┐ ┌───────────┴──────────┐       ┌────────────┴─────────────┐
    │ llama-server (text)  │ │llama-server (vision) │       │ lib/whisper_server.py    │
    │ HOST:8080            │ │HOST:8080             │       │ HOST:8765                │
    │ Mistral Small 24B    │ │Qwen3.8 Flash Next    │       │ OpenAI Whisper Turbo     │
    │ alias: jzaleski/text │ │+ mmproj (F16)        │       │ /v1/audio/transcriptions │
    │ (Q4/Q6/Q8, 64K ctx)  │ │alias: jzaleski/multi │       │ (MPS / CUDA / CPU)       │
    │                      │ │(Q4/Q6/Q8, 64K ctx)   │       │                          │
    └──────────────────────┘ └──────────────────────┘       └──────────────────────────┘
```

`HOST` defaults to `127.0.0.1` across all launchers; set `HOST=0.0.0.0` to expose on the LAN. Listen ports default to `8080` (text and multi LLMs) and `8765` (transcription); override with `PORT` or `-p / --port` when running servers concurrently.

## Opencode Agent Architecture

The opencode system provides a multi-agent workflow with role-specific capabilities:

```
┌──────────────────────┐
│    Opencode CLI      │
│                      │
│  ┌────────────────┐  │
│  │ Engineer       │◄─┼── default agent
│  │ [adaptive:     │  │
│  │  triage →      │  │
│  │  direct /      │  │
│  │  dispatch /    │  │
│  │  lifecycle]    │  │
│  └────────────────┘  │
│                      │
│  ┌────────────────┐  │
│  │ Data           │  │
│  │ [pipeline:     │  │
│  │  ingest →      │  │
│  │  analyze →     │  │
│  │  report]       │  │
│  └────────────────┘  │
│                      │
│  ┌────────────────┐  │
│  │ Product        │  │
│  │ [funnel:       │  │
│  │  triage →      │  │
│  │  scope →       │  │
│  │  refine →      │  │
│  │  handoff]      │  │
│  └────────────────┘  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│                        LLM Provider                          │
│                                                              │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ jzaleski                                                 │ │
│ │ baseURL: http://server-hostname-or-ip:8080/v1            │ │
│ │                                                          │ │
│ │ • jzaleski/text:       Mistral 24B, port 8080 (ctx 64K)  │ │
│ │ • jzaleski/multi:      Qwen3.8 Flash, port 8080 (ctx 64K)│ │
│ └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Provider Configuration

The opencode configuration (`home/.config/opencode/opencode.json`) defines a single `jzaleski` provider:
- **`jzaleski/text`**: Mistral-Small 3.2 24B Instruct running on port 8080. Universal 65,536 token context (57,344 input, 8,192 output). Text-only modality.
- **`jzaleski/multi`**: Qwen3.8-Flash-Next running on port 8080 with F16 multimodal projector. Universal 65,536 token context (57,344 input, 8,192 output). Text and image input modalities.

The `baseURL` ships templated with the `server-hostname-or-ip` placeholder rather than a hardcoded `localhost` — replace it with `localhost` if opencode runs on the same machine as the model server, or with that machine's actual hostname/IP if opencode runs elsewhere. The `HOST` env var independently governs whether the underlying server binds to `127.0.0.1` (local-only) or `0.0.0.0` (LAN-reachable).

| Provider | Endpoint | Model | Display Name | Context | Input | Output | Modalities |
|----------|----------|-------|---------------|---------|-------|--------|------------|
| jzaleski | `server-hostname-or-ip:8080` | `jzaleski/text` | Text (Mistral 24B) | 65,536 | 57,344 | 8,192 | text in, text out |
| jzaleski | `server-hostname-or-ip:8080` | `jzaleski/multi` | jzaleski/multi | 65,536 | 57,344 | 8,192 | text+image in, text out |

### Agent Roles

| Agent | Mode | Capabilities | Output Style |
|-------|------|--------------|--------------|
| engineer | primary (default) | Adaptive scope triage — handles trivial changes directly (Path A), dispatches parallel coders for multi-file work (Path B), or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger/ambiguous features (Path C) | Path A/B: working tree (may commit if clearly safe on Path A); Path C: feature branch with commits/PR |
| data | primary | Data pipeline orchestration — parallel ingestion of multi-format inputs, normalization, analysis, report generation | Report in user-specified format |
| product | primary | Work-shaping funnel — triage (classify & route) → scope (stakeholder intake) → refine (technical-PM maturation) → handoff (liftable engineering package) | Triage decision (inline) + scope artifact (evolves in place) + separate hand-off artifact |

### Disabled Built-in Agents

The `build` and `plan` agents that ship with opencode are disabled in `opencode.json` — only the three custom agents above are active.

### Plugins

None. All workflow skills are vendored locally under `home/.config/opencode/skills/`. This architecture has zero external plugin dependencies — if any third-party project disappears tomorrow, the agents continue working identically.

### MCP Integrations

The following MCP integrations are configured but **disabled by default**:

| Integration | Type | Command / URL | Notes |
|-------------|------|---------------|-------|
| AWS API | local | `uvx mcp-proxy-for-aws@latest https://aws-mcp.YOUR_AWS_REGION.api.aws/mcp --metadata AWS_REGION=YOUR_AWS_REGION --profile YOUR_AWS_PROFILE` | Enable in `opencode.json` to use; requires `uvx` (uv) |
| Google Cloud | local | `npx -y @google-cloud/gcloud-mcp` | Enable in `opencode.json` to use; requires Node.js/npm on `PATH` (not installed by the bootstrap system) |
| GitHub | remote | `https://api.githubcopilot.com/mcp/` | Enable in `opencode.json` to use; requires a Personal Access Token in headers |
| Jira | remote | `https://mcp.atlassian.com/v1/mcp` | Enable in `opencode.json` to use |
| Playwright | local | `npx @playwright/mcp@latest` | Enable in `opencode.json` to use; requires Node.js/npm on `PATH` (not installed by the bootstrap system) |
| Vercel | remote | `https://mcp.vercel.com/v1/mcp` | Enable in `opencode.json` to use |

### Usage

```bash
# Run opencode with default agent (engineer)
opencode "your question or task"

# Specify a different agent
opencode --agent engineer "implement this feature"
opencode --agent data "analyze this data file"
opencode --agent product "scope this feature request"
```

### Opencode Wrapper Script

The project includes `home/.local/lib/opencode.sh`, a wrapper script for the opencode CLI that manages model history, cache state, and session persistence. It is aliased to the `opencode` command via `home/.opencoderc`, which is sourced from `~/.bashrc` and `~/.zshrc` by the bootstrap system.

```bash
# Via alias after bootstrap
opencode [options] [query]

# Direct invocation
~/.local/lib/opencode.sh [options] [query]
```

**Features:**
- Persists the last session ID to `.last-opencode-session` in the git repo root after each run
- Resumes sessions via `--continue` by reading the persisted session ID (works even after moving the repo)
- Automatically resets opencode model history on session start (configurable)
- Clears model cache to ensure fresh model selection
- Supports `--continue`, `-s`, or `--session` flags to preserve history/cache across invocations
- Reads default `--model`/`--agent` values from `.opencode-config` (JSON) in the git repo root (falling back to `~/.opencode-config` in the home directory), applied only when the corresponding flag isn't already passed on the command line

**Default Model/Agent Configuration**

Commit a `.opencode-config` JSON file to a repo root to set per-repo defaults, or place one at `~/.opencode-config` in your home directory to set global user defaults when a repo does not provide one:

```json
{
  "model": "jzaleski/text",
  "agent": "engineer"
}
```

- Both keys are optional — set either, both, or neither.
- Precedence (highest to lowest): explicit CLI flag (`--model`/`-m`, `--agent`) → repo-root `.opencode-config` → `~/.opencode-config` → `opencode.json`'s `default_agent`/defaults.
- Invalid JSON prints a warning to stderr and is otherwise ignored — the underlying `opencode` command still runs.
- Unlike `.last-opencode-session`, repo-root `.opencode-config` is meant to be committed to the repo.

**Required binaries** (all installed via bootstrap): `cat`, `git`, `jq`, `opencode`, `sqlite3`

**Environment Variables:**
- `RESET_OPENCODE_HISTORY` — Reset model history on each invocation (default: `true`)
- `RESET_OPENCODE_MODELS_CACHE` — Clear model cache on each invocation (default: `true`)

### Configuration Notes

- `autoupdate`: disabled (manual updates only)
- `default_agent`: `engineer` (full tool access for general work)
- Both models are served under the unified `jzaleski` provider with a `server-hostname-or-ip` placeholder in the `baseURL` — replace with `localhost` or the actual hostname/IP
- Universal context window set to 65,536 tokens (57,344 input, 8,192 output)

## Performance Tips

- GPU acceleration enabled with flash attention by default (`--flash-attn on`)
- Standard quantization: `4` (default), `6`, `8` via `-q / --quantization`
- KV cache quantization: `q8_0` for both K and V cache across text and multi models to preserve quality during extended reasoning traces
- Universal context size: `65536` (64K tokens) by default; override with `-c <size>` or `CTX_SIZE`
- Batch/ubatch: `2048` / `1024` for high-throughput prompt processing on Apple Silicon
- Unified memory optimizations:
  - `--load-mode mlock`: pins model weights in RAM to prevent macOS memory compression latency on idle resumption
  - `--cache-reuse 256`: reuses KV cache for shared prompt prefixes across turns
  - `--cache-ram -1`: removes the default 8GiB slot RAM cache cap for memory-rich systems
- Purpose-specific tuning:
  - `text` (Mistral Small 3.2 24B): `temp=0.15`, `top-k=-1`, `top-p=1.00`, `--jinja`; auto-detects `draft-simple` speculative decoding (`draft-max 5`) when draft models are co-located
  - `multi` (Qwen3.8 Flash Next): `temp=1.0`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `--image-min-tokens 1024`, `--reasoning-preserve`, `--chat-template-kwargs '{"reasoning_effort":"medium"}'`; auto-detects `draft-mtp` speculative decoding (`draft-max 5`)
  - `transcription` (Whisper): auto-detects `cuda` -> `mps` -> `cpu`, disables FP16 on CPU, thread-safe transcription mutex

## Troubleshooting

**Bootstrap issues:**
- Run with `ASSUME_YES=true` for non-interactive mode
- If using an existing Python version manager (such as `asdf`), set `USE_EXISTING_PYTHON_MANAGER=true`

**Model not loading:**
- Ensure you have enough RAM (16GB+ recommended)
- Verify model name and quantization level

**Slow inference:**
- Enable flash attention (`--flash-attn on`)
- Reduce context size (`-c 32768`)
- Use Q4 quantization (`-q 4`)

**Quality issues:**
- Sampling defaults are tuned specifically for coding and agentic reasoning: `temp=0.15` for text, `temp=1.0` for multi
- For more creative responses, increase `temp` (e.g. `0.7`) and `top-p`
- For deterministic output, use lower temperatures

**Memory issues:**
- Reduce `CTX_SIZE` for smaller context windows
- Use lower quantization (`-q 4`)
