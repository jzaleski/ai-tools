# AGENTS.md

Guidelines for agentic coding tools in this repository.

## Project Overview

Shell scripts for running local LLMs using `llama-server`.
The default router (`--default`) binds to port 8080 and supports three model tiers — low (64K ctx), medium (128K ctx), high (256K ctx) — each with two variants: a fast, text-only variant (`jzaleski/default/<tier>`) running Qwen3.8-27B with `--spec-type draft-mtp --spec-draft-n-max 3` speculative decoding (MTP), and a vision-capable variant (`jzaleski/default/<tier>-multimodal`) running the same Qwen3.8-27B model with an F16 multimodal projector (`--mmproj`, auto-downloaded) instead. llama.cpp does not yet support combining `--mmproj` with MTP speculative decoding, so the fast variants are text-only and the `-multimodal` variants forgo the speedup — pick per-request based on whether image input is needed. All six aliases (low/medium/high and their `-multimodal` counterparts) are served by the default router. The experimental router (`--experimental`) binds to port 8081 by default so it can coexist with the default router, and serves DeepSeek-V4-Flash under the namespace `jzaleski/experimental/<particle>` (e.g. `quark` for 1M ctx, `boson` for 2M ctx). Bind address is controlled by the `HOST` env var (default `127.0.0.1`; set `HOST=0.0.0.0` to expose on the LAN).

**No code repositories** - utilities/config only.

## Opencode Agent Configuration(s)

### Gemini 3.1 Pro Specific Adjustments

Gemini tends to skip tool calls (like `skill` and `task`) and attempts to simulate their execution inline. To prevent this, the agents and prompt templates have been updated with `CRITICAL` sections forcing literal tool execution.

The project includes `opencode` agent configurations in `home/.config/opencode/`:

- **data.md**: Data pipeline orchestrator — triages scope, then runs raw data through ingest → analyze → report, dispatching parallel ingest workers when the input volume justifies it
- **engineer.md**: Adaptive software engineer — triages task scope, then handles trivial changes directly, dispatches parallel coders for multi-file work, or runs the full researcher → planner → coder → reviewer → finisher lifecycle for larger features
- **product.md**: Work-shaping persona — runs the triage skill to classify and route an inbound request, the scope skill to capture a stakeholder's requirements as a right-sized artifact, the refine skill to mature it (with engineering) into a ticket-ready brief, and the handoff skill to package it into a liftable engineering hand-off; produces artifacts, never writes code or hands off automatically

Workflow skills are vendored locally under `home/.config/opencode/skills/`. The engineering lifecycle uses researcher, planner, coder, debugging, reviewer, and finisher; the data pipeline uses ingest, analyze, and report; the product funnel uses triage, scope, refine, and handoff. No external plugin dependencies.

Agent configurations are managed via the bootstrap system and integrate with the local llama-server (llama.cpp) instance. The default agent is `engineer`.

---

## Project Structure

```
.
├── bin/                                   # Main execution scripts
│   ├── bootstrap                          # System setup and configuration bootstrap
│   ├── install-dependencies               # Installs/upgrades Homebrew base packages
│   ├── configure-git                      # Configures global git settings (core.excludesfile)
│   ├── configure-opencode                 # Installs opencode via the anomalyco/tap Homebrew tap, configures shell init
│   ├── download-model                     # Downloads a single GGUF file from Hugging Face via curl
│   ├── run-model                          # Direct llama-server launcher (single model, --tier low|medium|high|<tier>-multimodal)
│   └── run-router                         # Router server (llama.cpp, multi-model; HOST env toggles bind)
├── templates/                             # llama-server INI preset templates
│   └── llama-cpp.ini.template             # Router preset (6 aliases: low/medium/high + -multimodal counterparts; ctx 64K/128K/256K)
├── home/                                  # Dotfiles and config files to symlink
│   ├── .config/opencode/
│   │   ├── agents/                        # Agent definitions (data, engineer, product)
│   │   ├── skills/                        # Vendored workflow skills (analyze, coder, debugging, finisher, handoff, ingest, planner, refine, report, researcher, reviewer, scope, triage)
│   │   └── opencode.json                  # Provider, agent, MCP configuration
│   ├── .local/lib/opencode.sh             # Opencode wrapper (session persistence, cache reset)
│   └── .opencoderc                        # Shell alias: opencode → ~/.local/lib/opencode.sh
```

---

## Build/Test Commands

Scripts in `bin/` bind to `127.0.0.1` by default; set `HOST=0.0.0.0` to expose on the LAN. `run-model` takes an optional `--tier` flag (e.g. `default/low`, `default/medium`, `default/high`, or their `-multimodal` counterparts; default `default/medium`):

```bash
./bin/run-router --default                 # default multi-model router, localhost (8080)
./bin/run-router --experimental            # experimental multi-model router, localhost (8081)
HOST=0.0.0.0 ./bin/run-router --default    # default multi-model router, exposed on LAN
# Clients select tier via: ?model=jzaleski/default/low  jzaleski/default/medium  jzaleski/default/high
#                          jzaleski/default/low-multimodal  jzaleski/default/medium-multimodal  jzaleski/default/high-multimodal
# Or via experimental:     ?model=jzaleski/experimental/quark  jzaleski/experimental/boson

./bin/run-model                            # single model, default medium tier, localhost (8080)
./bin/run-model --tier default/low         # single model, low tier (fast, no vision)
./bin/run-model --tier default/high        # single model, high tier (fast, no vision)
./bin/run-model --tier experimental/quark  # single model, experimental tier (DeepSeek-V4-Flash, 1M ctx)
./bin/run-model --tier experimental/boson  # single model, experimental tier (DeepSeek-V4-Flash, 2M ctx)
./bin/run-model --tier default/high-multimodal # single model, high tier (vision-capable)
HOST=0.0.0.0 ./bin/run-model --tier default/high # single model, high tier, exposed on LAN
```

Test with: `bash -x ./bin/run-router` or `bash -x ./bin/run-model`

---

## Code Style Guidelines

### Bash Scripts

- **Shebang**: `#!/usr/bin/env bash`
- **Functions**: Use `run_<tier>()` helpers (e.g. `run_low()`, `run_high()`) plus a `main()` for the router, as needed
- **Tier Detection**: Parse the `--tier` flag with a `for arg in "$@"` loop; dispatch to the appropriate function
- **Variable Quoting**: Always quote expansions `"${VAR:-default}"`
- **Path Resolution**: Use `$(dirname $0)/..` for relative paths

### Configuration Files

- Environment Variables: Use `${VAR:-default}` syntax

### Documentation

- Keep `README.md` updated
- Document all environment variables with defaults
- Include usage examples and ASCII diagrams

### Naming Conventions

- Scripts: `run-{component}`
- Bind toggle: `HOST` env var (`127.0.0.1` default / `0.0.0.0` for LAN)
- Ports: 8080 (default router), 8081 (experimental router)
- Aliases: `jzaleski/default/{tier}` (fast, no vision) / `jzaleski/default/{tier}-multimodal` (vision-capable)
- Experimental: `jzaleski/experimental/{particle}` (e.g. quark, boson)

---

## Environment Variables

| Variable | Description | Default (Local) | Default (Server) |
|----------|-------------|-----------------|------------------|
| `HOST` | Host address | `127.0.0.1` | `0.0.0.0` |
| `PORT` | Network port | `8080` | `8080` |

Model-specific parameters (quantization, context size, sampling settings, etc.) are configured in the INI preset files under `templates/`.

---

## Architecture

```
┌──────────────────────────────────┐
│     Default Router (--default)   │ (Port 8080)
│        --models-preset           │
│                                  │
│       ┌───────────────────────┐  │
│       │ jzaleski/default/low  │  │
│       │ jzaleski/default/low-multimodal│
│       │ jzaleski/default/medium│ │
│       │ jzaleski/default/medium-multimodal│
│       │ jzaleski/default/high │  │
│       │ jzaleski/default/high-multimodal│
│       └───────────────────────┘  │
└──────────────────────────────────┘

┌──────────────────────────────────┐
│Experimental Router (--experimental)│ (Port 8081)
│        --models-preset           │
│                                  │
│       ┌───────────────────────┐  │
│       │ jzaleski/experimental/quark│
│       │ jzaleski/experimental/boson│
│       └───────────────────────┘  │
└──────────────────────────────────┘
```
(`jzaleski/experimental/<particle>` is available via router, or standalone via `run-model --tier experimental/<particle>`.)

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
┌──────────────────┐
│    LLM Provider  │
│                  │
│ ┌──────────────┐ │ ┌───────────────┐
│ │ Local        │ │ │ Server        │
│ │ Port 8080    │ │ │ (remote)      │
│ └──────────────┘ │ └───────────────┘
└──────────────────┘
```

The opencode configuration defines 2 provider endpoints:
- **llama.cpp (local)**: `localhost:8080` — per-tier context (low: 64K, medium: 128K, high: 256K); 6 models: `jzaleski/default/low|medium|high` (fast, text-only, MTP + speculative decoding) and `jzaleski/default/low-multimodal|medium-multimodal|high-multimodal` (vision-capable, no speculative decoding), all in the Qwen3.8-27B family at Q4_K_XL/Q6_K_XL/Q8_K_XL respectively.
- **llama.cpp (server)**: `server-hostname-or-ip:8080` — same 6 aliases and contexts; reach this endpoint by launching with `HOST=0.0.0.0`

Each provider specifies model limits for context window, input tokens, and output tokens, plus per-model `modalities` (`jzaleski/default/<tier>` is text-only input; `jzaleski/default/<tier>-multimodal` is text+image input). Users should replace `server-hostname-or-ip` with their actual server hostname or IP address.

### Disabled Providers & Built-in Agents

`opencode.json` disables the default `opencode` and `openai` providers via `disabled_providers`. The built-in `build` and `plan` agents are also disabled — only the three custom agents (`data`, `engineer`, `product`) are active.

### MCP Integrations

MCP integrations are declared in `opencode.json` but **disabled by default**:

| Integration | Type | Command / URL |
|-------------|------|---------------|
| AWS API | local | `uvx awslabs.aws-api-mcp-server@latest` |
| Google Cloud | local | `npx -y @google-cloud/gcloud-mcp` |
| GitHub | remote | `https://api.githubcopilot.com/mcp/` |
| Jira | remote | `https://mcp.atlassian.com/v1/mcp` |
| Playwright | local | `npx @playwright/mcp@latest` |
| Vercel | remote | `https://mcp.vercel.com/v1/mcp` |

Toggle `enabled: true` in `opencode.json` to activate. Playwright and Google Cloud's `npx` commands require Node.js/npm on `PATH` — not installed by the bootstrap system. AWS API requires `uvx` (uv). GitHub requires a Personal Access Token in headers.

### Opencode Wrapper

`home/.local/lib/opencode.sh` wraps the `opencode` CLI to add session persistence and cache reset behavior. It is aliased via `home/.opencoderc`, which is sourced from `~/.bashrc` and `~/.zshrc` by the bootstrap system.

- Persists the last session ID to `.last-opencode-session` in the git repo root
- Resumes via `--continue` / `-s` / `--session` using the persisted ID
- Resets model history and clears model cache on fresh sessions (configurable via `RESET_OPENCODE_HISTORY`, `RESET_OPENCODE_MODELS_CACHE`)
- Reads default `--model`/`--agent` values from `.opencode-config` (JSON) in the git repo root, applied only when not already passed as a CLI flag; invalid JSON logs a warning to stderr and is otherwise ignored. Unlike `.last-opencode-session` (per-user, gitignored), `.opencode-config` is meant to be committed
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

- GPU acceleration enabled with flash attention by default
- Use Q4-Q6 quantization for memory-constrained environments
- KV cache quantization is tier-specific: low=q8_0/q4_0 (K/V), medium=q8_0/q8_0 (K/V), high=q8_0/q8_0 — K-cache is kept at q8_0 on all tiers to preserve quality of long thinking traces; V-cache moves to q8_0 at 128K+ context (medium and high) to preserve quality at longer context lengths; identical between a tier and its `-multimodal` counterpart
- Context size is tier-specific: low=64K, medium=128K, high=256K
- Batch/ubatch is tier-specific and scales inversely with context for steady latency on Apple Silicon: low=2048/512, medium & high=1024/256 — identical between a tier and its `-multimodal` counterpart, since both stay within the same Qwen3.8-27B family (no architecture change to drive retuning)
- Sampling defaults are tuned for coding and tool-calling per Qwen3.8's thinking/coding profile: `temp=1.0`, `top-k=20`, `top-p=0.95`, `min-p=0.0`, `presence-penalty=0.0`, `repeat-penalty=1.0`. Server-side `predict=262144` caps default output length (clients may override via `max_tokens`).
- MTP speculative decoding (`jzaleski/default/low|medium|high`): `--spec-type draft-mtp --spec-draft-n-max 3`, for ~1.5-2x faster inference; Unsloth's MTP guide documents `2` as the "best starting point" but states 1-6 are all valid and the optimal value is hardware-dependent — `3` was chosen empirically for this hardware, re-benchmark if it changes; llama.cpp does not yet support combining this with `--mmproj`, so these tiers are text-only
- `--reasoning-preserve` is set on all 6 tiers (server-wide default for the chat template's `preserve_reasoning` kwarg, matching Qwen3.8's agentic-use recommendation) — preserves full reasoning traces across turns at the cost of larger accumulated per-turn context; reconsider on the smaller tiers if context-constrained
- `--image-min-tokens 1024` is set on all `-multimodal` tiers to preserve grounding/bbox accuracy on Qwen-VL models (see [llama.cpp #16842](https://github.com/ggml-org/llama.cpp/issues/16842))
- `--cache-reuse 256` + `--cache-ram -1` are set on all 6 tiers — reuses KV cache for the shared prefix when a request extends a previous prompt (the common shape of an agent loop), with the idle-slot cache's default 8GiB budget removed given RAM to spare; pairs well with `--reasoning-preserve` making prompts grow faster
- `--load-mode mlock` is set on all 6 tiers to pin model weights in RAM, avoiding macOS's background memory compression and the decompression stall it would otherwise cause on the first request after an idle period

## Troubleshooting

**Model not loading**: Verify RAM (16GB+), GPU/VRAM, model name and quantization.

**Connection failures**: Verify llama-server running.

**Performance issues**: Enable flash attention, reduce context size, adjust quantization.

## What to Avoid

- Do not modify model defaults without clear reason — quantization levels and context sizes are tuned for specific hardware profiles
- Do not change port allocations without updating all dependent configurations
- Do not skip `set -e` error handling in shell scripts
