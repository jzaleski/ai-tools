# AI Tools

Utilities for running local LLMs with llama-server

## Overview

This repository provides scripts and configurations for running local AI models using llama-server. The default router (`run-router --default`) binds to port `8080` and serves three model tiers — low (64K ctx), medium (128K ctx), and high (256K ctx) — each with two variants: a fast, text-only variant (`jzaleski/default/<tier>`) running Qwen3.8-27B with `--spec-type draft-mtp --spec-draft-n-max 3` speculative decoding (MTP), and a vision-capable variant (`jzaleski/default/<tier>-multimodal`) running the same Qwen3.8-27B model with an F16 multimodal projector (`--mmproj`, auto-downloaded) instead. llama.cpp does not yet support combining `--mmproj` with MTP speculative decoding, so the fast variants are text-only and the `-multimodal` variants forgo the speedup — pick per-request based on whether image input is needed. All six aliases are served by the default router. The experimental router (`run-router --experimental`) binds to port `8081` by default so it can coexist with the default router, and serves two more aliases under the `jzaleski/experimental/<particle>` namespace: `quark` (`unsloth/DeepSeek-V4-Flash-0731-GGUF`, 1M ctx, DSpark speculative decoding) and `boson` (`unsloth/Qwen3.8-Flash-Next-GGUF`, 256K ctx, MTP speculative decoding). `run-model` bypasses both routers and starts a single llama-server directly for any of the eight tiers via `--tier <namespace>/<tier>` (e.g. `default/high`, `experimental/quark`), defaulting to `default/medium`; its default listen port matches the tier's namespace (`8080` for `default/*`, `8081` for `experimental/*`), mirroring the two routers so a default and an experimental tier can run side by side without a `PORT` override. Bind address for both routers and `run-model` is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN). Tiers are stable; the models behind them can rotate without changing client-facing aliases.

Models are loaded from HuggingFace and quantized for efficient local inference.

## Project Structure

```
.
├── bin/                            # Main execution scripts
│   ├── bootstrap                   # System setup and configuration bootstrap
│   ├── install-dependencies        # Installs/upgrades Homebrew base packages
│   ├── configure-git               # Configures global git settings (core.excludesfile)
│   ├── configure-opencode          # Installs opencode via the anomalyco/tap Homebrew tap, configures shell init
│   ├── download-model              # Downloads a single GGUF file from Hugging Face via curl
│   ├── run-model                   # Direct llama-server launcher (single model, --tier default/low|default/medium|default/high|default/<tier>-multimodal|experimental/quark|experimental/boson)
│   └── run-router                  # Router server (llama.cpp, multi-model; --default binds 8080, --experimental binds 8081; HOST env toggles bind)
├── templates/                      # llama-server INI preset templates
│   ├── llama-cpp-default.ini.template      # Default router preset (6 aliases: default/low|medium|high + -multimodal variants)
│   └── llama-cpp-experimental.ini.template # Experimental router preset (2 aliases: experimental/quark, experimental/boson)
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
│   │   │   └── triage/             # Classify & route an inbound request (product front door)
│   │   └── opencode.json           # Opencode provider and agent configuration
│   ├── .local/lib/
│   │   └── opencode.sh             # Opencode wrapper script (session persistence, cache reset)
│   └── .opencoderc                 # Shell alias: opencode → ~/.local/lib/opencode.sh
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

- At least 16GB RAM for 20B+ models
- GPU support (recommended)

## Opencode Agent Configuration(s)

### Gemini 3.1 Pro Specific Adjustments

Gemini tends to skip tool calls (like `skill` and `task`) and attempts to simulate their execution inline. To prevent this, the agents and prompt templates have been updated with `CRITICAL` sections forcing literal tool execution.

The project includes `opencode` agent configurations in `home/.config/opencode/`:

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
| `debugging` | Root cause analysis for bugs, test failures, or unexpected behavior |
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
- `PORT`: Network port for the server to listen on (default: `8080`; anything in the `experimental` namespace — `run-router --experimental` or `run-model --tier experimental/*` — defaults to `8081` instead, so a default and an experimental instance can run side by side; see Components below)

## Components

### run-model
Starts a single llama-server directly (no router). Accepts `--tier <namespace>/<tier>` (default: `default/medium`):
- `default/low`, `default/medium`, `default/high` — fast, text-only Qwen3.8-27B tiers with MTP speculative decoding
- `default/low-multimodal`, `default/medium-multimodal`, `default/high-multimodal` — vision-capable Qwen3.8-27B tiers (same weights, `--mmproj` instead of speculative decoding)
- `experimental/quark` — DeepSeek-V4-Flash-0731, 1M ctx, DSpark speculative decoding
- `experimental/boson` — Qwen3.8-Flash-Next, 256K ctx, MTP speculative decoding

Downloads the model automatically if not present, fetching multi-part GGUFs (`experimental/quark`, `experimental/boson`) shard-by-shard. Fast `default/*` tiers and `experimental/boson` also download the model's MTP head and run with speculative decoding; `experimental/quark` downloads a separate DSpark drafter model instead; `-multimodal` tiers download the shared multimodal projector (mmproj) instead. Binds to `127.0.0.1` unless `HOST=0.0.0.0` is set. The default listen port matches the tier's namespace — `8080` for `default/*` tiers, `8081` for `experimental/*` tiers — so a `default/*` and an `experimental/*` tier can already run side by side without touching `PORT`; use `PORT` to override further (e.g. to avoid colliding with a router running on the same default port).

Bare legacy tier names (`low`, `medium`, `high`, `low-multimodal`, `medium-multimodal`, `high-multimodal`) and the old standalone `experimental` tier are no longer accepted — `run-model` exits with an error pointing you at the equivalent `default/*` tier or `experimental/quark`/`experimental/boson`.

**Shared defaults (6 Qwen3.8-27B tiers — low/medium/high + their `-multimodal` counterparts):**
- Host: `127.0.0.1` (override with `HOST`)
- Port: 8080
- Sampling: `temp=1.0`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`, `repeat-penalty=1.0`
- Output: `predict=262144` default (clients may override via `max_tokens`)
- GPU: `n-gpu-layers=-1` (all), flash-attn on

**Fast/no-vision tiers** — `unsloth/Qwen3.8-27B-GGUF`, run with `--spec-type draft-mtp --spec-draft-n-max 3`:

| Tier | Quant | KV Cache | Context | Batch/Ubatch |
|---|---|---|---|---|
| default/low | `UD-Q4_K_XL` | q8_0/q4_0 | 65,536 | 2048 / 512 |
| default/medium | `UD-Q6_K_XL` | q8_0/q8_0 | 131,072 | 1024 / 256 |
| default/high | `UD-Q8_K_XL` | q8_0/q8_0 | 262,144 | 1024 / 256 |

**Vision-capable tiers** — `unsloth/Qwen3.8-27B-GGUF` + multimodal projector, no speculative decoding:

| Tier | Quant | KV Cache | Context | Batch/Ubatch |
|---|---|---|---|---|
| default/low-multimodal | `UD-Q4_K_XL` | q8_0/q4_0 | 65,536 | 2048 / 512 |
| default/medium-multimodal | `UD-Q6_K_XL` | q8_0/q8_0 | 131,072 | 1024 / 256 |
| default/high-multimodal | `UD-Q8_K_XL` | q8_0/q8_0 | 262,144 | 1024 / 256 |

Batch/ubatch are identical between a tier and its `-multimodal` counterpart — both stay in the same Qwen3.8-27B family (no architecture change), so there was no technical driver to retune them.

**Experimental tiers** — excluded from the default router; served by the experimental router (`run-router --experimental`, port `8081`) or directly via `run-model --tier experimental/quark|boson`:

| Tier | Model | Quant | KV Cache | Context | Batch/Ubatch | Speculative Decoding |
|---|---|---|---|---|---|---|
| experimental/quark | `unsloth/DeepSeek-V4-Flash-0731-GGUF` | `UD-Q4_K_XL` | q8_0/q8_0 | 1,048,576 | 1024 / 256 | DSpark (`--spec-draft-n-max 3`) |
| experimental/boson | `unsloth/Qwen3.8-Flash-Next-GGUF` | `UD-Q4_K_XL` | q8_0/q8_0 | 262,144 | 1024 / 256 | MTP (`--spec-draft-n-max 3`) |

Sampling for `experimental/quark` follows [Unsloth's DeepSeek-V4-Flash-0731 guide](https://unsloth.ai/docs/models/deepseek-v4) rather than the Qwen shared defaults above, and diverges from them in three ways: `min-p=0.01` (matches every llama.cpp example in Unsloth's guide, though not called out in their prose recommendations), no `top-k` override (Unsloth's examples never pass one, so llama-server's built-in default applies instead of the `20` tuned for Qwen3.8), and `top-p=0.95` for the agentic/tool-calling use case this tier targets (Unsloth recommends `1.0` for non-agentic use instead). `temp=1.0`, `presence-penalty=0.0`, `repeat-penalty=1.0`, and `predict=262144` are unchanged from the shared defaults. Context is set to the model's stated 1,048,576-token ("1M") maximum — sized for a dedicated M3 Ultra Mac Studio (512GB unified memory), where the `UD-Q4_K_XL` weights plus the DSpark drafter total ~172GB per Unsloth's own hardware table, leaving ~340GB of headroom for the KV cache; DeepSeek-V4's MLA (Multi-head Latent Attention) architecture keeps the per-token KV cache footprint small enough that even 1M tokens of context fits comfortably within that headroom. `--spec-draft-n-max 3` is Unsloth's documented "good default" for DSpark (~1.9x faster; larger values measured slower).

`experimental/boson` uses the same shared Qwen sampling defaults as the `default/*` fast tiers (`temp=1.0`, `top-k=20`, `top-p=0.95`, `min-p=0.0`) and runs standard MTP speculative decoding rather than DSpark.

**MTP speculative decoding:** The fast `default/*` tiers and `experimental/boson` run with `--spec-type draft-mtp --spec-draft-n-max 3`, for ~1.5-2x faster inference. Unsloth's MTP guide documents `2` as the "best starting point" but states 1-6 are all valid and the optimal value is hardware-dependent — `3` was chosen empirically for this hardware, re-benchmark if it changes. Both model families ship with MTP tensors natively in their main repos, so there is no need to disambiguate local filenames or download a separate model file for MTP (unlike DSpark, which needs the separate drafter downloaded for `experimental/quark`).

**Vision (multimodal):** Only the `-multimodal` tiers load a multimodal projector (`--mmproj`); the fast tiers are text-only because llama.cpp does not yet support combining `--mmproj` with MTP speculative decoding. The `F16` projector is downloaded from the same Hugging Face repo as the model (remote filename `mmproj-F16.gguf`) and stored alongside each model with a matching name — the model's filename with a `.mmproj` extension instead of `.gguf` (e.g. `Qwen3.8-27B-UD-Q4_K_XL.gguf` → `Qwen3.8-27B-UD-Q4_K_XL.mmproj`). All `-multimodal` tiers also set `--image-min-tokens 1024`, per [llama.cpp #16842](https://github.com/ggml-org/llama.cpp/issues/16842) — Qwen-VL models need at least 1024 image tokens to keep grounding/bbox accuracy correct.

**Reasoning preservation:** All 8 tiers set `--reasoning-preserve`, which sets the chat template's `preserve_reasoning` kwarg server-wide instead of requiring each client request to pass `chat_template_kwargs: {"preserve_thinking": true}`. Qwen3.8's model card recommends this for agentic use (better decision consistency and KV-cache reuse across turns) at the cost of feeding more accumulated thinking-trace tokens back in on every subsequent turn — worth it on hardware with headroom to spare, less so if you're tight on context/memory on the smaller tiers.

**Agentic/hardware tuning:** All 8 tiers also set `--cache-reuse 256`, `--cache-ram -1`, and `--load-mode mlock`, tuned for large-RAM dedicated inference hosts (e.g. Apple Silicon Mac Studio with 512GB unified memory) running agentic coding workloads:
- `--cache-reuse 256` lets llama-server reuse cached KV state for the shared prefix when a new request extends a previous one (exactly the shape of an opencode agent loop: same system prompt + tool defs + growing history each turn) instead of reprocessing the whole prompt from scratch every time. Pairs especially well with `--reasoning-preserve`, which makes prompts grow faster.
- `--cache-ram -1` removes the default 8GiB cap on the idle-slot prompt cache that `--cache-reuse` depends on, so cached conversation states aren't evicted under memory pressure that will essentially never occur with RAM to spare.
- `--load-mode mlock` pins model weights in RAM, avoiding macOS's background memory compression touching them during idle periods between agent turns (and the decompression stall that would otherwise hit the next request).

**Environment Variables:**
- `HOST`: Bind address (default: `127.0.0.1`; set `0.0.0.0` for LAN)
- `PORT`: Override listen port (default: `8080` for `default/*` tiers, `8081` for `experimental/*` tiers)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)

### run-router
Starts a single llama-server in [router mode](https://github.com/ggml-org/llama.cpp/blob/master/docs/preset.md), loading model aliases from a rendered INI preset. Accepts `--default` (default mode if no flag given) or `--experimental`:
- `--default` — loads 6 aliases (`jzaleski/default/low|medium|high` + their `-multimodal` counterparts) from `templates/llama-cpp-default.ini.template` → `tmp/llama-cpp-default.ini`; binds to port `8080` by default.
- `--experimental` — loads 2 aliases (`jzaleski/experimental/quark`, `jzaleski/experimental/boson`) from `templates/llama-cpp-experimental.ini.template` → `tmp/llama-cpp-experimental.ini`; binds to port `8081` by default so it can run alongside the default router.

Clients select an alias via the `model` parameter. Binds to `127.0.0.1` unless `HOST=0.0.0.0` is set. Both routers can run at once (they default to different ports) to make every tier reachable simultaneously.

**Defaults:**
- Host: `127.0.0.1` (override with `HOST`)
- Port: `8080` for `--default`, `8081` for `--experimental` (override either with `PORT`)
- Sampling: `temp=1.0`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`, `repeat-penalty=1.0` on `--default`; `experimental/quark` overrides `min-p`/`top-p` and drops the `top-k` default per Unsloth's DeepSeek guidance, while `experimental/boson` matches the `--default` sampling defaults (see the run-model tables above)
- Output: `predict=262144` default (clients may override via `max_tokens`)
- Per-tier context/KV/batch as in the run-model tables above. `default/low|medium|high` and `experimental/boson` additionally set `spec-type=draft-mtp`/`spec-draft-n-max=3` and omit `mmproj`; the `default/*-multimodal` sections set `mmproj` and omit the spec-decoding keys; `experimental/quark` sets `spec-type=draft-dspark`/`spec-draft-n-max=3` and a separate `spec-draft-model`.

**Environment Variables:**
- `HOST`: Bind address (default: `127.0.0.1`; set `0.0.0.0` for LAN)
- `PORT`: Override listen port (default: `8080` for `--default`, `8081` for `--experimental`)
- `MODELS_DIR`: Override model cache directory (default: `~/.cache/models`)

## Usage

```bash
# Start single model directly — default/medium tier (default), localhost
./bin/run-model

# Start single model — specific default tier
./bin/run-model --tier default/low
./bin/run-model --tier default/high

# Start single model — vision-capable variant
./bin/run-model --tier default/high-multimodal

# Start single model — experimental tiers
./bin/run-model --tier experimental/quark
./bin/run-model --tier experimental/boson

# Expose a single model on the LAN
HOST=0.0.0.0 ./bin/run-model --tier default/high

# Start the default router (default/low|medium|high + their -multimodal counterparts on localhost:8080)
./bin/run-router --default

# Start the experimental router (experimental/quark, experimental/boson on localhost:8081)
./bin/run-router --experimental

# Run both routers at once — every tier reachable simultaneously
./bin/run-router --default &
./bin/run-router --experimental &

# Start a router exposed on the LAN
HOST=0.0.0.0 ./bin/run-router --default
```

Clients select a model via the `model` query parameter or request body field:

```bash
curl http://localhost:8080/v1/chat/completions?model=jzaleski/default/low               ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/default/low-multimodal    ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/default/medium            ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/default/medium-multimodal ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/default/high              ...
curl http://localhost:8080/v1/chat/completions?model=jzaleski/default/high-multimodal   ...
curl http://localhost:8081/v1/chat/completions?model=jzaleski/experimental/quark        ...
curl http://localhost:8081/v1/chat/completions?model=jzaleski/experimental/boson        ...
# Or run any tier standalone via run-model and curl the port it listens on
# (defaults to 8080 for default/* tiers, 8081 for experimental/* tiers — override with PORT)
```

## Architecture

There are two routers, each serving a fixed set of aliases, plus `run-model` for launching any single tier directly. The default router (`run-router --default`, port `8080`) serves 6 aliases: the `default/low|medium|high` tiers and their `-multimodal` counterparts. The experimental router (`run-router --experimental`, port `8081`) serves 2 aliases: `experimental/quark` and `experimental/boson`. `run-model` bypasses both routers and starts a single llama-server directly for any of the 8 tiers via `--tier <namespace>/<tier>`, defaulting its listen port to `8080` for `default/*` tiers or `8081` for `experimental/*` tiers (mirroring the routers). All three bind to `127.0.0.1` unless `HOST=0.0.0.0` is set.

```
┌────────────────────────────┐  ┌────────────────────────────────┐  ┌─────────────────────┐
│  ./bin/run-router --default │  │  ./bin/run-router --experimental │  │  ./bin/run-model     │
│  (multi-model router)       │  │  (multi-model router)            │  │  (single model)      │
└──────────────┬───────────────┘  └────────────────┬─────────────────┘  └───────────┬──────────┘
               │                                     │                               │
    ┌──────────┴───────────┐              ┌──────────┴───────────┐        ┌──────────┴─────────┐
    │ llama.cpp (default)   │              │ llama.cpp (experimental)│    │ llama.cpp            │
    │ HOST:8080              │              │ HOST:8081                │    │ HOST:8080 or :8081   │
    │ --models-preset        │              │ --models-preset          │    │ (--tier, see below)  │
    │                        │              │                          │    └──────────────────────┘
    │ jzaleski/default/low          │      │ jzaleski/experimental/quark │
    │ jzaleski/default/low-multimodal│     │ jzaleski/experimental/boson │
    │ jzaleski/default/medium        │      └──────────────────────────┘
    │ jzaleski/default/medium-multimodal│
    │ jzaleski/default/high             │
    │ jzaleski/default/high-multimodal  │
    └────────────────────────────────────┘
```

HOST defaults to `127.0.0.1` for all three launchers; set `HOST=0.0.0.0` to expose on the LAN. `run-model` accepts any of the 8 tiers directly (`default/low|medium|high[-multimodal]`, `experimental/quark|boson`) and defaults its port to `8080` for `default/*` tiers or `8081` for `experimental/*` tiers, so a default and an experimental tier (whether via router or `run-model`) can run side by side without a `PORT` override.

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
│  ┌────────────────┐  │ ┌────────────────┐  ┌────────────────────┐
│  │ Local (default)│  │ │ Server (default) │ │ Local (experimental)│
│  │ localhost:8080 │  │ │ remote:8080       │ │ localhost:8081      │
│  │ per-tier ctx   │  │ │ per-tier ctx      │ │ quark / boson ctx   │
│  └────────────────┘  │ └────────────────┘  └────────────────────┘
└──────────────────────┘
```

### Provider Configuration

The opencode configuration (`~/.config/opencode/opencode.json`) defines 3 provider endpoints:

The two `(default)` providers expose the same 6 `jzaleski/default/*` aliases with identical per-tier limits; they differ only in endpoint (the server provider is the same models reached by launching `run-router --default` with `HOST=0.0.0.0`). The fast aliases (`jzaleski/default/low`,
`jzaleski/default/medium`, `jzaleski/default/high`) are text-only (MTP speculative decoding
does not yet support `--mmproj`); the `-multimodal` aliases accept image
input. The `(experimental)` provider exposes `jzaleski/experimental/quark` and `jzaleski/experimental/boson` at `localhost:8081` (text-only); there is no server-side `(experimental)` provider configured.

| Provider | Endpoint | Model | Context | Input | Output | Modalities |
|----------|----------|-------|---------|-------|--------|------------|
| llama.cpp (local) (default) | `localhost:8080` | jzaleski/default/low | 65,536 | 57,344 | 8,192 | text in, text out |
| llama.cpp (local) (default) | `localhost:8080` | jzaleski/default/low-multimodal | 65,536 | 57,344 | 8,192 | text+image in, text out |
| llama.cpp (local) (default) | `localhost:8080` | jzaleski/default/medium | 131,072 | 114,688 | 16,384 | text in, text out |
| llama.cpp (local) (default) | `localhost:8080` | jzaleski/default/medium-multimodal | 131,072 | 114,688 | 16,384 | text+image in, text out |
| llama.cpp (local) (default) | `localhost:8080` | jzaleski/default/high | 262,144 | 229,376 | 32,768 | text in, text out |
| llama.cpp (local) (default) | `localhost:8080` | jzaleski/default/high-multimodal | 262,144 | 229,376 | 32,768 | text+image in, text out |
| llama.cpp (server) (default) | `server-hostname-or-ip:8080` | jzaleski/default/low | 65,536 | 57,344 | 8,192 | text in, text out |
| llama.cpp (server) (default) | `server-hostname-or-ip:8080` | jzaleski/default/low-multimodal | 65,536 | 57,344 | 8,192 | text+image in, text out |
| llama.cpp (server) (default) | `server-hostname-or-ip:8080` | jzaleski/default/medium | 131,072 | 114,688 | 16,384 | text in, text out |
| llama.cpp (server) (default) | `server-hostname-or-ip:8080` | jzaleski/default/medium-multimodal | 131,072 | 114,688 | 16,384 | text+image in, text out |
| llama.cpp (server) (default) | `server-hostname-or-ip:8080` | jzaleski/default/high | 262,144 | 229,376 | 32,768 | text in, text out |
| llama.cpp (server) (default) | `server-hostname-or-ip:8080` | jzaleski/default/high-multimodal | 262,144 | 229,376 | 32,768 | text+image in, text out |
| llama.cpp (local) (experimental) | `localhost:8081` | jzaleski/experimental/quark | 1,048,576 | 917,504 | 131,072 | text in, text out |
| llama.cpp (local) (experimental) | `localhost:8081` | jzaleski/experimental/boson | 262,144 | 229,376 | 32,768 | text in, text out |

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
| AWS API | local | `uvx awslabs.aws-api-mcp-server@latest` | Enable in `opencode.json` to use; requires `uvx` (uv) |
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
- Reads default `--model`/`--agent` values from `.opencode-config` (JSON) in the git repo root, applied only when the corresponding flag isn't already passed on the command line

**Default Model/Agent Configuration**

Commit a `.opencode-config` JSON file to a repo root to set per-repo defaults:

```json
{
  "model": "jzaleski/default/high",
  "agent": "engineer"
}
```

- Both keys are optional — set either, both, or neither.
- Precedence (highest to lowest): explicit CLI flag (`--model`/`-m`, `--agent`) → `.opencode-config` → `opencode.json`'s `default_agent`/defaults.
- Invalid JSON prints a warning to stderr and is otherwise ignored — the underlying `opencode` command still runs.
- Unlike `.last-opencode-session`, this file is meant to be committed to the repo.

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
- Each tier has a fast/no-vision variant (`jzaleski/default/<tier>`, MTP + speculative decoding) and a vision-capable variant (`jzaleski/default/<tier>-multimodal`, no speculative decoding); `--mmproj` and `--spec-type draft-mtp` are not yet supported together in llama.cpp
- KV cache quantization is tier-specific (same for a tier and its `-multimodal` counterpart): `default/low`=q8_0/q4_0 (K/V), `default/medium`=q8_0/q8_0 (K/V), `default/high`=q8_0/q8_0 — K-cache is kept at q8_0 on all tiers to preserve quality of long thinking traces; V-cache moves to q8_0 at 128K+ context (medium and high) to preserve quality at longer context lengths
- Context size is tier-specific: `default/low`=64K, `default/medium`=128K, `default/high`=256K; `experimental/quark`=1M, `experimental/boson`=256K
- Batch/ubatch scales inversely with context for steady latency on Apple Silicon: `default/low`=2048/512, `default/medium` & `default/high`=1024/256 — identical between a tier and its `-multimodal` counterpart, since both stay within the same Qwen3.8-27B family
- Sampling defaults are tuned for coding and tool-calling per Qwen3.8's thinking/coding profile: `temp=1.0`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`; server-side `predict=262144` caps default output length
- `--reasoning-preserve` is set on all 8 tiers, preserving full reasoning traces across turns server-wide (matches Qwen3.8's agentic-use recommendation) — trades a larger accumulated context per turn for better multi-turn decision consistency; worth it with RAM/context to spare, worth reconsidering on the smaller tiers if you're context-constrained
- `--image-min-tokens 1024` is set on all `-multimodal` tiers to preserve grounding/bbox accuracy on Qwen-VL models (see [llama.cpp #16842](https://github.com/ggml-org/llama.cpp/issues/16842))
- `--cache-reuse 256` + `--cache-ram -1` are set on all 8 tiers to reuse KV cache across turns that extend a previous prompt (the common shape of an agent loop) instead of reprocessing from scratch, with the idle-slot cache's default 8GiB budget removed — tuned for hosts with RAM to spare
- `--load-mode mlock` is set on all 8 tiers to keep model weights pinned in RAM rather than subject to macOS's background memory compression, avoiding a decompression stall on the first request after an idle period

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
- Sampling defaults are tuned for coding/tool-calling per Qwen3.8's thinking/coding profile: `temp=1.0`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`
- For more creative/diverse responses, increase `temp` and `top-p`, or raise `presence-penalty`
- For more deterministic output, lower `temp` (e.g. `0.4–0.6`)

**Memory issues:**
- Reduce `CTX_SIZE` for smaller context windows
- Use lower quantization (recommend Q4 as the minimum to balance accuracy and speed)
