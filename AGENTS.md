# AGENTS.md

Guidelines for agentic coding tools in this repository.

## Project Overview

Unified utilities for running local AI models: `llama-server` for text and multimodal LLM inference, and a persistent Python server for OpenAI-compatible Whisper audio transcription.

All model hosting is unified behind `bin/run-model` with purpose-oriented model aliases:
- **`jzaleski/text`**: Mistral-Small 3.2 24B Instruct running on port 8080 (default). High-throughput text generation and coding model with Jinja templating, flash attention, and auto-detected speculative decoding (`draft-simple`).
- **`jzaleski/multi`**: Qwen3.8-Flash-Next running on port 8080 with an F16 multimodal projector (`--mmproj`, auto-downloaded). Vision-capable model with reasoning preservation and auto-detected MTP speculative decoding (`draft-mtp`).
- **`jzaleski/transcription`**: Persistent OpenAI-compatible Whisper HTTP server running on port 8765 (`lib/whisper_server.py`). Supports `/v1/audio/transcriptions`, `/health`, and `/v1/models` with hardware-accelerated inference (`cuda` -> `mps` -> `cpu`).

Both LLMs support standard quantizations (`-q 4|6|8`, defaulting to `4`), 64K universal default context (`65536` tokens, overrideable via `-c / --ctx-size` or `CTX_SIZE`), and full unified memory optimizations (`--load-mode mlock`, `--cache-reuse 256`, `--cache-ram -1`). Bind address is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN). Listen ports default to `8080` (text/multi LLMs) and `8765` (transcription), overrideable via `PORT` or `-p / --port`.

**No code repositories** - utilities/config only.

## Opencode Agent Configuration(s)

### Gemini 3.1 Pro Specific Adjustments

Gemini tends to skip tool calls (like `skill` and `task`) and attempts to simulate their execution inline. To prevent this, the agents and prompt templates have been updated with `CRITICAL` sections forcing literal tool execution.

The project includes `opencode` agent configurations in `home/.config/opencode/`:

- **data.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
- **product.md**: Work-shaping persona — runs the triage skill to classify and route an inbound request, the scope skill to capture a stakeholder's requirements as a right-sized artifact, the refine skill to mature it (with engineering) into a ticket-ready brief, and the handoff skill to package it into a liftable engineering hand-off; produces artifacts, never writes code or hands off automatically

Workflow skills are vendored locally under `home/.config/opencode/skills/`. The engineering lifecycle uses researcher, planner, coder, debugging, reviewer, finisher, test-driven-development, and verification-before-completion; the data pipeline uses ingest, analyze, and report; the product funnel uses triage, scope, refine, and handoff. No external plugin dependencies.

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `engineer`.

---

## Project Structure

```
.
├── bin/                                   # Main execution scripts
│   ├── bootstrap                          # System setup and configuration bootstrap
│   ├── install-dependencies               # Installs/upgrades Homebrew base packages
│   ├── configure-git                      # Configures global git settings (core.excludesfile)
│   ├── configure-python                   # Sets up pyenv, installs Python 3.14.3 and requirements.txt
│   ├── configure-opencode                 # Installs opencode via the anomalyco/tap Homebrew tap, configures shell init
│   ├── download-model                     # Downloads a single GGUF file from Hugging Face via curl
│   └── run-model                          # Unified model launcher (text, multi, transcription)
├── lib/                                   # Supporting server libraries
│   └── whisper_server.py                  # Persistent OpenAI-compatible Whisper HTTP server
├── tests/                                 # Test suites
│   ├── test_run_model.sh                  # CLI test harness for bin/run-model
│   └── test_whisper_server.py             # Unit tests for persistent Whisper server
├── home/                                  # Dotfiles and config files to symlink
│   ├── .config/opencode/
│   │   ├── agents/                        # Agent definitions (data, engineer, product)
│   │   ├── skills/                        # Vendored workflow skills (analyze, coder, debugging, finisher, handoff, ingest, planner, refine, report, researcher, reviewer, scope, test-driven-development, triage, verification-before-completion)
│   │   └── opencode.json                  # Provider, agent, MCP configuration
│   ├── .local/lib/opencode.sh             # Opencode wrapper (session persistence, cache reset)
│   └── .opencoderc                        # Shell alias: opencode → ~/.local/lib/opencode.sh
├── .default-python-version                # Default Python version for pyenv (3.14.3)
└── requirements.txt                       # Python dependencies (openai-whisper, torch)
```

---

## Build/Test Commands

Scripts in `bin/` bind to `127.0.0.1` by default; set `HOST=0.0.0.0` to expose on the LAN. `run-model` launches models by purpose (`text`, `multi`, `transcription`; default `text`), with optional quantization (`-q 4|6|8`, default `4`):

```bash
./bin/run-model                               # text generation (Mistral 24B, Q4, port 8080)
./bin/run-model text -q 6                     # text generation, Q6 quantization
./bin/run-model multi                         # vision-capable model (Qwen3.8 Flash Next, Q4, port 8080)
./bin/run-model transcription                 # Whisper transcription server (port 8765)
HOST=0.0.0.0 ./bin/run-model text            # expose on LAN
```

Test with:
```bash
bash tests/test_run_model.sh                  # run-model CLI test harness (59 assertions)
python3 -m unittest discover -s tests         # Whisper server unit test suite
```

---

## Code Style Guidelines

### Bash Scripts

- **Shebang**: `#!/usr/bin/env bash`
- **Error Handling**: Use `set -e;`
- **Variable Quoting**: Always quote expansions `"${VAR:-default}"`
- **Path Resolution**: Use `repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` or `$(dirname $0)/..`

### Configuration Files

- Environment Variables: Use `${VAR:-default}` syntax

### Documentation

- Keep `README.md` updated
- Document all environment variables with defaults
- Include usage examples and ASCII diagrams

### Naming Conventions

- Scripts: `run-{component}`, `configure-{component}`
- Bind toggle: `HOST` env var (`127.0.0.1` default / `0.0.0.0` for LAN)
- Ports: 8080 (text/multi LLMs), 8765 (transcription)
- Aliases: `jzaleski/text` (text), `jzaleski/multi` (vision-capable), `jzaleski/transcription` (transcription)

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST` | Bind address | `127.0.0.1` (set `0.0.0.0` to expose on the LAN) |
| `PORT` | Network port | `8080` (text/multi), `8765` (transcription) |
| `WHISPER_HOST` | Bind address override for Whisper server | `${HOST:-127.0.0.1}` |
| `WHISPER_PORT` | Network port override for Whisper server | `${PORT:-8765}` |
| `WHISPER_MODEL` | Whisper transcription model name | `turbo` |
| `MODELS_DIR` | Directory for downloaded GGUF models | `~/.cache/models` |
| `CTX_SIZE` | Context window size in tokens | `65536` |
| `N_GPU_LAYERS` | Layers offloaded to GPU | `-1` (all) |
| `THREADS` | CPU threads for inference | `8` |
| `WHISPER_DEVICE` | Compute device for Whisper transcription (`auto`, `mps`, `cuda`, `cpu`) | `auto` |

Model-specific parameters (quantization, context size, sampling settings, etc.) are configured via flags in `bin/run-model`.

---

## Architecture

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

---

## Opencode Agent Architecture

```
┌──────────────────┐
│   Opencode CLI   │
│                  │
│ ┌──────────────┐ │
│ │ Engineer     │ │ (default)
│ │ [adaptive:   │ │
│ │  triage →    │ │
│ │  direct /    │ │
│ │  dispatch /  │ │
│ │  lifecycle]  │ │
│ └──────────────┘ │
│                  │
│ ┌──────────────┐ │
│ │ Data         │ │
│ │ [pipeline:   │ │
│ │  ingest →    │ │
│ │  analyze →   │ │
│ │  report]     │ │
│ └──────────────┘ │
│                  │
│ ┌──────────────┐ │
│ │ Product      │ │
│ │ [funnel:     │ │
│ │  triage →    │ │
│ │  scope →     │ │
│ │  refine →    │ │
│ │  handoff]    │ │
│ └──────────────┘ │
└─────────┬────────┘
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

The opencode configuration defines a unified `jzaleski` provider endpoint templated with a `server-hostname-or-ip` placeholder in its `baseURL` (replace with `localhost` or an actual hostname/IP):
- **jzaleski/text**: `server-hostname-or-ip:8080` — Mistral-Small 3.2 24B Instruct (`UD-Q4_K_XL`), 65,536 token context (57,344 input, 8,192 output). Text-only modality.
- **jzaleski/multi**: `server-hostname-or-ip:8080` — Qwen3.8-Flash-Next (`UD-Q4_K_XL`) with F16 multimodal projector, 65,536 token context (57,344 input, 8,192 output). Multimodal modality (text + image input).

The provider is unopinionated about network topology — the `HOST` env var governs whether the underlying server binds to `127.0.0.1` (local-only) or `0.0.0.0` (LAN-reachable). If opencode runs on a different machine than the server, edit the provider's `baseURL` in `opencode.json` (e.g. `http://192.168.1.50:8080/v1`).

Each model specifies limits for context window (65,536), input tokens (57,344), and output tokens (8,192), plus per-model `modalities` (`jzaleski/text` is text-only input; `jzaleski/multi` is text+image input).

### Disabled Providers & Built-in Agents

`opencode.json` disables the default `opencode` and `openai` providers via `disabled_providers`. The built-in `build` and `plan` agents are also disabled — only the three custom agents (`data`, `engineer`, `product`) are active.

### MCP Integrations

MCP integrations are declared in `opencode.json` but **disabled by default**:

| Integration | Type | Command / URL |
|-------------|------|---------------|
| AWS API | local | `uvx mcp-proxy-for-aws@latest https://aws-mcp.YOUR_AWS_REGION.api.aws/mcp --metadata AWS_REGION=YOUR_AWS_REGION --profile YOUR_AWS_PROFILE` |
| Google Cloud | local | `npx -y @google-cloud/gcloud-mcp` |
| GitHub | remote | `https://api.githubcopilot.com/mcp/` |
| Jira | remote | `https://mcp.atlassian.com/v1/mcp` |
| Playwright | local | `npx @playwright/mcp@latest` |
| Vercel | remote | `https://mcp.vercel.com/v1/mcp` |

Toggle `enabled: true` in `opencode.json` to activate. Playwright and Google Cloud's `npx` commands require Node.js/npm on `PATH` — not installed by the bootstrap system. GitHub requires a Personal Access Token in headers.

### Opencode Wrapper

`home/.local/lib/opencode.sh` wraps the `opencode` CLI to add session persistence and cache reset behavior. It is aliased via `home/.opencoderc`, which is sourced from `~/.bashrc` and `~/.zshrc` by the bootstrap system.

- Persists the last session ID to `.last-opencode-session` in the git repo root
- Resumes via `--continue` / `-s` / `--session` using the persisted ID
- Resets model history and clears model cache on fresh sessions (configurable via `RESET_OPENCODE_HISTORY`, `RESET_OPENCODE_MODELS_CACHE`)
- Reads default `--model`/`--agent` values from `.opencode-config` (JSON) in the git repo root (falling back to `~/.opencode-config` in the home directory), applied only when not already passed as a CLI flag; invalid JSON logs a warning to stderr and is otherwise ignored. Unlike `.last-opencode-session` (per-user, gitignored), `.opencode-config` is meant to be committed
- Required binaries (all installed via bootstrap): `cat`, `git`, `jq`, `opencode`, `sqlite3`

---

## Bootstrap System

The bootstrap system sets up the local development environment:

```bash
bin/bootstrap                               # Interactive
ASSUME_YES=true bin/bootstrap               # Non-interactive
```

Bootstrap scripts are defined as an explicit ordered array in `bin/bootstrap` and live alongside it in `bin/`:

| Script | Purpose |
|--------|---------|
| `bin/install-dependencies` | Installs Homebrew (if missing) and base packages (`ag`, `btop`, `curl`, `git`, `jq`, `htop`, `llama.cpp`, `nvtop`, `openssl`, `readline`, `sqlite`, `wget`, `zsh`) |
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

---

## Performance

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
  - `text` (Mistral Small 3.2 24B): `temp=0.15`, `top-k=-1`, `top-p=1.00`, `--jinja`; auto-detects `draft-simple` speculative decoding when draft models are co-located
  - `multi` (Qwen3.8 Flash Next): `temp=1.0`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `--image-min-tokens 1024`, `--reasoning-preserve`; auto-detects `draft-mtp` speculative decoding
  - `transcription` (Whisper): auto-detects `cuda` -> `mps` -> `cpu`, disables FP16 on CPU, thread-safe transcription mutex

## Troubleshooting

**Model not loading**: Verify RAM (16GB+), GPU/VRAM, model name and quantization.

**Connection failures**: Verify llama-server or whisper-server is running.

**Performance issues**: Enable flash attention, reduce context size, adjust quantization.

## What to Avoid

- Do not modify model defaults without clear reason — quantization levels and context sizes are tuned for specific hardware profiles
- Do not change port allocations without updating all dependent configurations
- Do not skip `set -e` error handling in shell scripts
