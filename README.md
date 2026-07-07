# AI Tools

Utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. It supports four model tiers — low (32K ctx), medium (64K ctx), high (128K ctx), and long (256K ctx for long agent sessions) — each available in two variants: a fast, text-only variant (`jzaleski/<tier>`) running unsloth's Qwen3.6-35B-A3B **MTP** (multi-token prediction) build with `--spec-type draft-mtp` speculative decoding for ~1.5-2x faster inference, and a vision-capable variant (`jzaleski/<tier>-multimodal`) running the original (non-MTP) Qwen3.6-35B-A3B build with a multimodal projector. llama.cpp does not yet support combining `--mmproj` with MTP speculative decoding, so the fast variants are text-only and the `-multimodal` variants forgo the speedup. All eight aliases run within the Qwen3.6-35B-A3B family (speed → quality → context; fast → vision-capable). The low/medium/high tiers and their `-multimodal` counterparts (6 aliases total) are served by the router on port `8080`; `long` and `long-multimodal` are **standalone-only** — excluded from the router preset and launched via `run-model --tier long` / `--tier long-multimodal`. `run-model` also defaults to port `8080`; set `PORT` (e.g. `8081`) to run it alongside the router. Bind address is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN). Tiers are stable; the models behind them can rotate without changing client-facing aliases.

Models are loaded from HuggingFace and quantized for efficient local inference.

## Project Structure

```
.
├── bin/                            # Main execution scripts
│   ├── bootstrap                   # System setup and configuration bootstrap
│   ├── install-dependencies        # Installs/upgrades Homebrew base packages
│   ├── configure-git               # Configures global git settings (core.excludesfile)
│   ├── configure-node              # Clones/updates nodenv, installs Node.js and npm
│   ├── configure-opencode          # Installs opencode-ai and configures shell init
│   ├── download-model              # Downloads a single GGUF file from Hugging Face via curl
│   ├── run-model                   # Direct llama-server launcher (single model, --tier low|medium|high|long|<tier>-multimodal)
│   └── run-router                  # Router server (llama.cpp, multi-model; HOST env toggles bind)
├── templates/                      # llama-server INI preset templates
│   └── llama-cpp.ini.template      # Router preset (6 aliases: low/medium/high + -multimodal variants)
├── home/                           # Dotfiles and config files to symlink
│   ├── .config/opencode/           # Opencode configuration and agent definitions
│   │   ├── agents/
│   │   │   ├── data.md             # Data pipeline orchestrator
│   │   │   ├── engineer.md         # Adaptive software engineer (default)
│   │   │   └── product.md          # Work-shaping persona (triage → scope → refine → handoff)
│   │   ├── skills/                 # Vendored workflow skills (no external plugins)
│   │   │   ├── analyze/            # Find patterns / answer questions (pipeline stage 2)
│   │   │   ├── coder/              # Sub-agent implementer (TDD, self-review)
│   │   │   ├── finisher/           # Verify, merge/PR, cleanup
│   │   │   ├── handoff/             # Package a refined brief into a liftable eng hand-off (product stage 3)
│   │   │   ├── ingest/             # Extract + clean + normalize raw files (pipeline stage 1)
│   │   │   ├── planner/            # Task decomposition + independence analysis
│   │   │   ├── refine/             # Mature a scope into a ticket-ready brief (product stage 2)
│   │   │   ├── report/             # Deliver findings in one+ formats (pipeline stage 3)
│   │   │   ├── researcher/         # Design & discovery (approval-gated)
│   │   │   ├── reviewer/         # Spec compliance + code quality review
│   │   │   ├── scope/              # Stakeholder requirements intake (product stage 1)
│   │   │   └── triage/             # Classify & route an inbound request (product front door)
│   │   └── opencode.json           # Opencode provider and agent configuration
│   ├── .local/lib/
│   │   └── opencode.sh             # Opencode wrapper script (session persistence, cache reset)
│   └── .opencoderc                 # Shell alias: opencode → ~/.local/lib/opencode.sh
├── .default-node-version           # Default node version
├── .default-npm-version            # Default npm version
└── .default-opencode-version       # Default opencode-ai version
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
| `bin/configure-node` | Clones/updates `nodenv` to `~/.nodenv` and the `node-build` plugin; installs Node.js (from `.default-node-version`) and npm (from `.default-npm-version`) |
| `bin/configure-opencode` | Installs `opencode-ai` version from `.default-opencode-version` via npm; appends `.opencoderc` sourcing to `~/.bashrc` and `~/.zshrc` |

To run only a subset of scripts, use `BOOTSTRAP_SCRIPTS`:
```bash
BOOTSTRAP_SCRIPTS="configure-node,configure-opencode" bin/bootstrap
```
To skip specific scripts, use `BOOTSTRAP_SKIP`:
```bash
BOOTSTRAP_SKIP="install-dependencies" bin/bootstrap
```

## Prerequisites

- At least 16GB RAM for 20B+ models
- GPU support (recommended)

## Tool Versions

The project tracks specific versions of key development tools in version files:

| File | Description | Default |
|------|-------------|---------|
| `.default-node-version` | Node.js version for nodenv | 24.18.0 |
| `.default-npm-version` | npm version | 11.16.0 |
| `.default-opencode-version` | opencode-ai version | 1.17.13 |

These versions are managed and installed via the bootstrap system.

## Opencode Agent Configuration(s)

The project includes `opencode-ai` agent configurations in `home/.config/opencode/`:

- **data.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
- **product.md**: Work-shaping persona — runs the triage skill to classify and route an inbound request, the scope skill to capture a stakeholder's requirements as a right-sized artifact, the refine skill to mature it (with engineering) into a ticket-ready brief, and the handoff skill to package it into a liftable engineering hand-off

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `engineer`.

### Local Skills

Workflow skills are vendored locally under `home/.config/opencode/skills/` — no external plugin dependencies.

**Engineering lifecycle** (orchestrated by `engineer`):

| Skill | Purpose |
|-------|---------|
| `researcher` | Design & discovery — clarifying questions, approach proposals, spec writing with user approval gate |
| `planner` | Task decomposition with exact file paths, code, commands, and parallel-dispatch independence analysis |
| `coder` | Sub-agent implementer — TDD, self-review, structured status reporting |
| `reviewer` | Dual-mode review — spec compliance (did they build what was asked?) then code quality |
| `finisher` | Verify tests, detect workspace state, present merge/PR options, execute with cleanup |

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

**Common Variables:**
- `HOST`: Network interface address to bind the server to (default: `127.0.0.1`; set `0.0.0.0` to expose on the LAN)
- `PORT`: Network port for the server to listen on (default: 8080)

## Components

### run-model
Starts a single llama-server directly (no router). Accepts `--tier low|medium|high|long|low-multimodal|medium-multimodal|high-multimodal|long-multimodal` (default: `medium`). Downloads the model automatically if not present. Fast tiers (no `-multimodal` suffix) also download the model's MTP head and run with speculative decoding; `-multimodal` tiers download the shared multimodal projector (mmproj) instead. Binds to `127.0.0.1` unless `HOST=0.0.0.0` is set. The `long`/`long-multimodal` tiers are standalone-only (not part of the router preset); like the others they default to port `8080`, so set `PORT` (e.g. `8081`) to run one alongside the router.

**Shared defaults (all tiers):**
- Host: `127.0.0.1` (override with `HOST`)
- Port: 8080
- Sampling: `temp=0.6`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`, `repeat-penalty=1.0`
- Output: `predict=32768` default (clients may override via `max_tokens`)
- GPU: `n-gpu-layers=-1` (all), flash-attn on

**Fast/no-vision tiers** — `unsloth/Qwen3.6-35B-A3B-MTP-GGUF`, run with `--spec-type draft-mtp --spec-draft-n-max 2`:

| Tier | Quant | KV Cache | Context | Batch/Ubatch |
|---|---|---|---|---|
| low | `UD-Q4_K_XL` | q8_0/q4_0 | 32,768 | 2048 / 512 |
| medium | `UD-Q6_K_XL` | q8_0/q4_0 | 65,536 | 2048 / 512 |
| high | `UD-Q8_K_XL` | q8_0/q8_0 | 131,072 | 1024 / 256 |
| long | `UD-Q8_K_XL` | q8_0/q8_0 | 262,144 | 1024 / 256 |

**Vision-capable tiers** — `unsloth/Qwen3.6-35B-A3B-GGUF` (original, non-MTP build) + multimodal projector, no speculative decoding:

| Tier | Quant | KV Cache | Context | Batch/Ubatch |
|---|---|---|---|---|
| low-multimodal | `UD-Q4_K_XL` | q8_0/q4_0 | 32,768 | 2048 / 512 |
| medium-multimodal | `UD-Q6_K_XL` | q8_0/q4_0 | 65,536 | 2048 / 512 |
| high-multimodal | `UD-Q8_K_XL` | q8_0/q8_0 | 131,072 | 1024 / 256 |
| long-multimodal | `UD-Q8_K_XL` | q8_0/q8_0 | 262,144 | 1024 / 256 |

Batch/ubatch are identical between a tier and its `-multimodal` counterpart — both stay in the same Qwen3.6-35B-A3B family (no architecture change), so there was no technical driver to retune them.

> `long`/`long-multimodal` are standalone-only — excluded from the router preset and must be launched via `run-model --tier long` / `--tier long-multimodal`. They default to port 8080 like the other tiers; set `PORT` (e.g. 8081) to run one alongside the router.

**MTP speculative decoding:** The fast tiers load unsloth's MTP (multi-token prediction) build and run llama.cpp with `--spec-type draft-mtp --spec-draft-n-max 2`, per the model card's recommended settings, for ~1.5-2x faster inference. The MTP repo's per-quant filenames are identical to the non-MTP repo's (e.g. both ship `Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf`), so the local cache disambiguates them with a `-MTP-` infix (e.g. `Qwen3.6-35B-A3B-MTP-UD-Q4_K_XL.gguf`). `download-model` takes an explicit local filename (`download-model <hf-repo> <hf-filename> [local-filename]`) so it saves directly under that disambiguated name — without it, the existence check can't tell the two repos' same-named files apart and would wrongly skip downloading one of them.

**Vision (multimodal):** Only the `-multimodal` tiers load a multimodal projector (`--mmproj`); the fast tiers are text-only because llama.cpp does not yet support combining `--mmproj` with MTP speculative decoding. The `F16` projector is downloaded from the same Hugging Face repo as the (non-MTP) model (remote filename `mmproj-F16.gguf`) and stored alongside each model with a matching name — the model's filename with a `.mmproj` extension instead of `.gguf` (e.g. `Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf` → `Qwen3.6-35B-A3B-UD-Q4_K_XL.mmproj`). All `-multimodal` tiers also set `--image-min-tokens 1024`, per [llama.cpp #16842](https://github.com/ggml-org/llama.cpp/issues/16842) — Qwen-VL models need at least 1024 image tokens to keep grounding/bbox accuracy correct.

**Reasoning preservation:** All 8 tiers set `--reasoning-preserve`, which sets the chat template's `preserve_reasoning` kwarg server-wide instead of requiring each client request to pass `chat_template_kwargs: {"preserve_thinking": true}`. Qwen3.6's model card recommends this for agentic use (better decision consistency and KV-cache reuse across turns) at the cost of feeding more accumulated thinking-trace tokens back in on every subsequent turn — worth it on hardware with headroom to spare, less so if you're tight on context/memory on the smaller tiers.

**Agentic/hardware tuning:** All 8 tiers also set `--cache-reuse 256`, `--cache-ram -1`, and `--mlock`, tuned for large-RAM dedicated inference hosts (e.g. Apple Silicon Mac Studio with 512GB unified memory) running agentic coding workloads:
- `--cache-reuse 256` lets llama-server reuse cached KV state for the shared prefix when a new request extends a previous one (exactly the shape of an opencode agent loop: same system prompt + tool defs + growing history each turn) instead of reprocessing the whole prompt from scratch every time. Pairs especially well with `--reasoning-preserve`, which makes prompts grow faster.
- `--cache-ram -1` removes the default 8GiB cap on the idle-slot prompt cache that `--cache-reuse` depends on, so cached conversation states aren't evicted under memory pressure that will essentially never occur with RAM to spare.
- `--mlock` pins model weights in RAM, avoiding macOS's background memory compression touching them during idle periods between agent turns (and the decompression stall that would otherwise hit the next request).

**Environment Variables:**
- `HOST`: Bind address (default: `127.0.0.1`; set `0.0.0.0` for LAN)
- `PORT`: Override listen port (default: 8080)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)

### run-router
Starts a single llama-server in [router mode](https://github.com/ggml-org/llama.cpp/blob/master/docs/preset.md), loading 6 aliases (low/medium/high + their `-multimodal` counterparts) from the rendered INI preset (`templates/llama-cpp.ini.template` → `tmp/llama-cpp.ini`). `long`/`long-multimodal` are excluded from the preset and are standalone-only via `run-model --tier long` / `--tier long-multimodal`. Clients select an alias via the `model` parameter. Binds to `127.0.0.1` unless `HOST=0.0.0.0` is set.

**Defaults:**
- Host: `127.0.0.1` (override with `HOST`)
- Port: 8080
- Sampling: `temp=0.6`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`, `repeat-penalty=1.0`
- Output: `predict=32768` default (clients may override via `max_tokens`)
- Per-tier context/KV/batch as in the run-model tables above. `low`/`medium`/`high` additionally set `spec-type=draft-mtp`/`spec-draft-n-max=2` and omit `mmproj`; the `-multimodal` sections set `mmproj` and omit the spec-decoding keys.

**Environment Variables:**
- `HOST`: Bind address (default: `127.0.0.1`; set `0.0.0.0` for LAN)
- `PORT`: Override listen port (default: 8080)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)

## Usage

```bash
# Start single model directly — medium tier (default), localhost
./bin/run-model

# Start single model — specific tier
./bin/run-model --tier low
./bin/run-model --tier high
./bin/run-model --tier long

# Start single model — vision-capable variant
./bin/run-model --tier high-multimodal

# Expose a single model on the LAN
HOST=0.0.0.0 ./bin/run-model --tier high

# Start router (low/medium/high + their -multimodal counterparts on localhost:8080)
./bin/run-router

# Start router exposed on the LAN
HOST=0.0.0.0 ./bin/run-router
```

Clients select a model via the `model` query parameter or request body field:

```bash
curl http://localhost:8080/v1/chat/completions?model=jzaleski/low               ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/low-multimodal    ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/medium            ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/medium-multimodal ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/high              ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/high-multimodal   ...
# jzaleski/long and jzaleski/long-multimodal are standalone-only:
# run `./bin/run-model --tier long` (or `--tier long-multimodal`), then curl
# the port it is listening on (8080 by default; set PORT to change it)
```

## Architecture

The router listens on port 8080 and serves 6 aliases: the low/medium/high tiers and their `-multimodal` counterparts. The `long`/`long-multimodal` tiers are standalone-only and served directly by `run-model --tier long` / `--tier long-multimodal`. Alternatively, `run-model` bypasses the router and starts a single llama-server directly for any of the 8 tiers. Both bind to `127.0.0.1` unless `HOST=0.0.0.0` is set.

```
┌───────────────────────────┐   ┌──────────────────────────┐
│   ./bin/run-router         │   │   ./bin/run-model         │
│   (multi-model router)     │   │   (single model)          │
└────────────┬───────────────┘   └────────────┬─────────────┘
             │                                 │
   ┌──────────┴──────────────────┐    ┌─────────┴──────────┐
   │  llama.cpp (router)         │    │  llama.cpp         │
   │  HOST:8080                  │    │  HOST:8080         │
   │  --models-preset            │    │  (direct, --tier)  │
   │                             │    └────────────────────┘
   │ ┌─────────────────────────┐ │
   │ │ jzaleski/low             │ │  HOST defaults to 127.0.0.1;
   │ │ jzaleski/low-multimodal  │ │  set HOST=0.0.0.0 to expose
   │ │ jzaleski/medium          │ │  on the LAN.
   │ │ jzaleski/medium-multimodal│ │
   │ │ jzaleski/high            │ │  (jzaleski/long and
   │ │ jzaleski/high-multimodal │ │  jzaleski/long-multimodal
   │ └─────────────────────────┘ │  are standalone-only, via
   └──────────────────────────────┘  run-model --tier long[-multimodal])
```

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
┌──────────────────────┐
│    LLM Providers     │
│                      │
│  ┌────────────────┐  │ ┌────────────────┐
│  │ Local          │  │ │ Server         │
│  │ localhost:8080 │  │ │ remote:8080    │
│  │ per-tier ctx   │  │ │ per-tier ctx   │
│  └────────────────┘  │ └────────────────┘
└──────────────────────┘
```

### Provider Configuration

The opencode configuration (`~/.config/opencode/opencode.json`) defines 2 provider endpoints:

Both providers expose the same 6 aliases with identical per-tier limits; they
differ only in endpoint (the server provider is the same models reached by
launching with `HOST=0.0.0.0`). The fast aliases (`jzaleski/low`,
`jzaleski/medium`, `jzaleski/high`) are text-only (MTP speculative decoding
does not yet support `--mmproj`); the `-multimodal` aliases accept image
input. `long`/`long-multimodal` are **not** part of the opencode
configuration — they are standalone-only via `run-model --tier long` /
`--tier long-multimodal`.

| Provider | Endpoint | Model | Context | Input | Output | Modalities |
|----------|----------|-------|---------|-------|--------|------------|
| llama.cpp (local) | `localhost:8080` | jzaleski/low | 32,768 | 28,672 | 4,096 | text in, text out |
| llama.cpp (local) | `localhost:8080` | jzaleski/low-multimodal | 32,768 | 28,672 | 4,096 | text+image in, text out |
| llama.cpp (local) | `localhost:8080` | jzaleski/medium | 65,536 | 57,344 | 8,192 | text in, text out |
| llama.cpp (local) | `localhost:8080` | jzaleski/medium-multimodal | 65,536 | 57,344 | 8,192 | text+image in, text out |
| llama.cpp (local) | `localhost:8080` | jzaleski/high | 131,072 | 114,688 | 16,384 | text in, text out |
| llama.cpp (local) | `localhost:8080` | jzaleski/high-multimodal | 131,072 | 114,688 | 16,384 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/low | 32,768 | 28,672 | 4,096 | text in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/low-multimodal | 32,768 | 28,672 | 4,096 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/medium | 65,536 | 57,344 | 8,192 | text in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/medium-multimodal | 65,536 | 57,344 | 8,192 | text+image in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/high | 131,072 | 114,688 | 16,384 | text in, text out |
| llama.cpp (server) | `server-hostname-or-ip:8080` | jzaleski/high-multimodal | 131,072 | 114,688 | 16,384 | text+image in, text out |

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
| Jira | remote | `https://mcp.atlassian.com/v1/mcp` | Enable in `opencode.json` to use |
| Playwright | local | `npx @playwright/mcp@latest` | Enable in `opencode.json` to use |
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

**Required binaries** (all installed via bootstrap): `cat`, `git`, `jq`, `opencode`, `sqlite3`

**Environment Variables:**
- `RESET_OPENCODE_HISTORY` — Reset model history on each invocation (default: `true`)
- `RESET_OPENCODE_MODELS_CACHE` — Clear model cache on each invocation (default: `true`)

### Configuration Notes

- `autoupdate`: disabled (manual updates only)
- `default_agent`: `engineer` (full tool access for general work)
- Server providers use `server-hostname-or-ip` placeholder - replace with actual hostname/IP
- Input/output token limits set to optimize for local inference constraints

## Performance Tips

- GPU acceleration enabled with flash attention by default
- Each tier has a fast/no-vision variant (`jzaleski/<tier>`, MTP + speculative decoding) and a vision-capable variant (`jzaleski/<tier>-multimodal`, no speculative decoding); `--mmproj` and `--spec-type draft-mtp` are not yet supported together in llama.cpp
- KV cache quantization is tier-specific (same for a tier and its `-multimodal` counterpart): low=q8_0/q4_0 (K/V), medium=q8_0/q4_0 (K/V), high=q8_0/q8_0, long=q8_0/q8_0 — K-cache is kept at q8_0 on all tiers to preserve quality of long thinking traces; V-cache matches `high`'s q8_0 on `long` too (the Q6_K_XL/q4_0 medium-tier tradeoff wasn't worth it for the flagship long-context tier)
- Context size is tier-specific: low=32K, medium=64K, high=128K, long=256K
- Batch/ubatch scales inversely with context for steady latency on Apple Silicon: low & medium=2048/512, high & long=1024/256 — identical between a tier and its `-multimodal` counterpart, since both stay within the same Qwen3.6-35B-A3B family
- Sampling defaults are tuned for coding and tool-calling per Qwen3.6's thinking/coding profile: `temp=0.6`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`; server-side `predict=32768` caps default output length
- `--reasoning-preserve` is set on all 8 tiers, preserving full reasoning traces across turns server-wide (matches Qwen3.6's agentic-use recommendation) — trades a larger accumulated context per turn for better multi-turn decision consistency; worth it with RAM/context to spare, worth reconsidering on the smaller tiers if you're context-constrained
- `--image-min-tokens 1024` is set on all `-multimodal` tiers to preserve grounding/bbox accuracy on Qwen-VL models (see [llama.cpp #16842](https://github.com/ggml-org/llama.cpp/issues/16842))
- `--cache-reuse 256` + `--cache-ram -1` are set on all 8 tiers to reuse KV cache across turns that extend a previous prompt (the common shape of an agent loop) instead of reprocessing from scratch, with the idle-slot cache's default 8GiB budget removed — tuned for hosts with RAM to spare
- `--mlock` is set on all 8 tiers to keep model weights pinned in RAM rather than subject to macOS's background memory compression, avoiding a decompression stall on the first request after an idle period

## Troubleshooting

**Bootstrap issues:**
- Run with `ASSUME_YES=true` for non-interactive mode

**Model not loading:**
- Ensure you have enough RAM
- Verify model name and quantization

**Slow inference:**
- Enable flash attention
- Reduce context size
- Adjust quantization level

**Quality issues:**
- Sampling defaults are tuned for coding/tool-calling per Qwen3.6's thinking/coding profile: `temp=0.6`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`
- For more creative/diverse responses, increase `temp` and `top-p`, or raise `presence-penalty`
- For more deterministic output, lower `temp` (e.g. `0.4–0.6`)

**Memory issues:**
- Reduce `CTX_SIZE` for smaller context windows
- Use lower quantization (recommend Q4 as the minimum to balance accuracy and speed)
