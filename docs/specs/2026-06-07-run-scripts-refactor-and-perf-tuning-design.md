# Run Scripts Refactor & Performance Tuning — Design

**Date:** 2026-06-07
**Status:** Approved (pending final user review of written spec)

## Problem

Two issues with the current `bin/` run scripts and `templates/` presets:

1. **Performance left on the table.** Batch/ubatch sizes were set with a
   "bigger is better" assumption (local 2048/512, server 4096/1024). On Apple
   Silicon (M3 Ultra, Metal, unified memory) oversized batches inflate the
   compute buffer and hurt interactive latency without buying throughput. The
   upstream llama.cpp defaults (batch 2048 / ubatch 512) are well-tuned for
   this hardware.

2. **Context forced too large for the common case.** Everything is pinned to
   64K (local) / 256K (server). The 256K window only exists to support a
   long-running agent session; it is not the typical usecase and bloats the KV
   cache for everyday work.

3. **Awkward local/server split.** The local-vs-server distinction is baked
   into *both* the bind address *and* the performance parameters, duplicated
   across two scripts (`run-local`, `run-server`) and two templates. The
   `run-router --server` flag reads as redundant.

## Goals

- Right-size context per tier instead of one forced value.
- Tune batch/ubatch for reliable, predictable performance on Metal.
- Collapse the local/server mode duplication: bind address becomes a single
  `HOST` env var; performance params become mode-independent (tier-driven).
- Isolate the large-context use case into a dedicated `long` tier.

## Non-Goals

- No benchmark harness (informed defaults only; user tunes later).
- No changes to sampling parameters (already tuned).
- No new models outside the Qwen3.6 family.

## Script Restructure

| Script | Role | Bind default | Bind override |
|---|---|---|---|
| `run-model` | Single model, one tier | `127.0.0.1` | `HOST=0.0.0.0` |
| `run-router` | Multi-model preset routing | `127.0.0.1` | `HOST=0.0.0.0` |

Changes:

- **Delete** `bin/run-local` and `bin/run-server`.
- **Create** `bin/run-model`: single-model launcher with `--tier low|medium|high|long`.
  Retains the `require_model` download helper and the `--tier` parsing loop from
  the deleted scripts. Default tier: `medium`.
- **Modify** `bin/run-router`: remove the `--server` flag and the local/server
  preset split. Render one unified template. Bind via `--host "${HOST:-127.0.0.1}"`.
- Both scripts bind via `--host "${HOST:-127.0.0.1}"`. Expose on LAN with
  `HOST=0.0.0.0 ./bin/run-model --tier high`.

## Template Consolidation

- **Delete** `templates/llama-cpp-local.ini.template` and
  `templates/llama-cpp-server.ini.template`.
- **Create** `templates/llama-cpp.ini.template`: one preset, bind address no
  longer baked in (it's a CLI flag now). Exposes all four routable aliases:
  `jzaleski/low`, `jzaleski/medium`, `jzaleski/high`, `jzaleski/long`.

## Tier Configuration

The tier axis runs **speed → quality** within the Qwen3.6 family. `long` is a
sibling of `low` (same model/quant) tuned for a large context window. The tier
axis intentionally bundles context growth with the speed→quality progression;
`long` is the dedicated extreme for long agent sessions.

| Tier | Model | Quant | ctx | KV quant | batch | ubatch | ngl |
|---|---|---|---|---|---|---|---|
| `low` | Qwen3.6-35B-A3B | Q4_K_XL | 32768 | q4_0 | 2048 | 512 | -1 |
| `medium` | Qwen3.6-35B-A3B | Q6_K_XL | 65536 | q4_0 | 2048 | 512 | -1 |
| `high` | Qwen3.6-27B | Q8_K_XL | 131072 | q8_0 | 1024 | 256 | -1 |
| `long` | Qwen3.6-35B-A3B | Q4_K_XL | 262144 | q4_0 | 1024 | 256 | -1 |

### Rationale

- **Context (ascending):** 32K → 64K → 128K → 256K. Mirrors speed→quality; the
  fast tier keeps a small KV cache for snappy prefill, the quality tier gets
  more working context, `long` is the extreme. KV-cache memory cost is trivial
  on 512GB.
- **Batch/ubatch (inverse scaling):** 2048/512 for low+medium, 1024/256 for
  high+long. On Metal, a large ubatch inflates the compute buffer; that cost
  compounds with large context. Trimming batch on the heavy-context tiers keeps
  the compute buffer smaller and latency steadier. Batch/ubatch do not affect
  output quality — only how tokens are processed — so the heavy tiers are tuned
  for **reliable, predictable performance**.
- **KV quant:** q4_0 everywhere except `high` (q8_0, the quality-focused tier).
  `long` uses q4_0 — at 256K the cache is large, and q4_0 keeps it lean while
  matching its low-tier sibling.
- **Medium quant:** standardize on **Q6_K_XL**. The old `run-local` used
  Q4_K_XL for medium while `run-server` used Q6_K_XL; since the local/server
  split is gone, medium resolves to the higher-quality Q6_K_XL (its quality
  bump over low comes from quant, not context).
- **n-gpu-layers:** kept explicit at `-1` (= all) in every tier and the router
  preset for forward-compat / future tweaking, even though upstream now
  defaults to `auto`.
- **flash-attn:** `on` (correct for Metal).
- **No `--swa-full`:** inflates memory at large ctx for negligible benefit in a
  single-user pattern.

### Sampling (unchanged)

`temp 0.7`, `top-k 0`, `top-p 0.95`, `min-p 0.02`, `presence-penalty 0.2`,
`repeat-penalty 1.0`.

## Usage After Refactor

```bash
./bin/run-model                          # single model, medium tier, localhost
./bin/run-model --tier low               # low tier
./bin/run-model --tier high              # high tier
./bin/run-model --tier long              # long-context tier
HOST=0.0.0.0 ./bin/run-model --tier high # expose on LAN

./bin/run-router                         # multi-model router, localhost
HOST=0.0.0.0 ./bin/run-router            # router exposed on LAN
# Clients select tier: ?model=jzaleski/low|medium|high|long
```

## Documentation Impact

`AGENTS.md` and `README.md` (if present) must be updated to reflect:

- `run-local`/`run-server` → `run-model` (with `--tier long`)
- Removal of `--server` flag; `HOST` env var as the bind toggle
- New per-tier ctx/batch/ubatch/KV-quant table
- Single consolidated template name
- Build/Test command examples
- `bash -x` test invocations referencing the new script names

## Testing Approach

- `bash -n` syntax check on `run-model` and `run-router`.
- `bash -x ./bin/run-model --tier <each>` dry-trace to confirm correct flag
  assembly per tier (model path, ctx, batch, ubatch, host).
- `bash -x ./bin/run-router` to confirm template render + host binding.
- Confirm `HOST=0.0.0.0` overrides bind address in both scripts.
- Verify no lingering references to `run-local`, `run-server`, `--server`, or
  the old template names anywhere in the repo.
