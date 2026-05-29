# Design: vLLM Config Tuning & cipher/sage Client Sampling (+ server context lowering)

**Date:** 2026-05-29
**Branch:** `vllm-config-tuning`
**Status:** Awaiting user approval

## Problem Statement

Two issues surfaced while running the vLLM (Metal) backend via
`bin/run-router --server --experimental`:

1. **Hard requirement violation:** Only `jzaleski/cipher` was registered with
   vLLM; `jzaleski/sage` was absent. vLLM serves one model per process, unlike
   the llama.cpp `--models-preset` router which hosts multiple aliases.
   *(Already fixed in the working tree — see Component A.)*

2. **cipher/sage are behaviorally identical on vLLM.** The original work mapped
   the llama.cpp INI presets to a vLLM YAML 1:1, but per-alias sampling
   (`top_k`, `min_p`, penalties) is a **server-side** feature in the llama.cpp
   router that vLLM does not have. The vLLM YAML relegated those params to
   comments, so today both aliases hit the same weights with the model's
   baked-in `generation_config.json` defaults (`top_k: 20`). The distinction
   only matters if the **client** sends per-request sampling.

3. **Perceived slow token generation.** Investigated; see Findings.

## Research Findings

### F1 — Prefix caching MUST stay disabled (not a bug)

Core vLLM `vllm/config/model.py:1804-1809`: `is_prefix_caching_supported`
returns `False` for any generative model with `attn_type == "hybrid"`
("Hybrid models do not support prefix caching since the feature is still
experimental"). Qwen3.6-35B-A3B is hybrid (startup log: "10 SDPA layers,
30 linear layers"). Therefore `enable-prefix-caching: false` in
`conf/vllm-server.yaml` is **correct and mandatory**. The full-prefill cost on
every request (~1290 tok/s prompt throughput recurring per request in the log)
is inherent to this model on vLLM and is NOT fixable via config. The existing
config comment is accurate; we will reinforce it with the source citation.

**Decision:** Leave prefix caching off. No change. Document why.

### F2 — Model natively supports 262144 context

`mlx-community/Qwen3.6-35B-A3B-8bit` `config.json`:
`max_position_embeddings: 262144`, `rope_type: default` (no scaling). So
`max-model-len: 262144` is the model's true trained max. Lowering it is a
deliberate latency/memory tradeoff, not a correctness fix.

### F3 — Memory cost of current sizing

Startup log breakdown: `hybrid_gdn_state=65.93GB (64.4MB/seq * max_num_seqs=1024)`,
KV budget 340.56GB, and post-init "Metal memory: 86.4GB available" (down from
535.9GB). The implicit `max_num_seqs=1024` over-reserves hybrid GDN state for a
single-/few-user workload.

### F4 — opencode per-model `options` semantics (OPEN RISK)

Per opencode docs (`/docs/models`, `/docs/providers`), `provider.models.<id>.options`
passes **AI-SDK provider options**, not arbitrary OpenAI request-body fields.
For `@ai-sdk/openai-compatible`:
- `temperature`, `topP` → standard AI-SDK call settings, forwarded reliably.
- `top_k`, `min_p`, `presence_penalty`, `repetition_penalty` → **non-standard**
  for the OpenAI chat schema; forwarding requires the AI-SDK extra-body
  mechanism, and opencode's exact passthrough key is **unverified**.

This is the one item requiring **empirical verification** during
implementation (live `curl` to the running server + inspect what vLLM receives,
or inspect request via vLLM debug logging).

### F5 — llama.cpp honors per-request sampling; INI router does two jobs (informational; llama.cpp sampling relocation DEFERRED)

> **Scope note:** This finding documents the eventual cross-backend direction,
> but moving llama.cpp sampling client-side is **deferred** and NOT part of this
> effort. Retained here as recorded research. The only llama.cpp change in this
> effort is the server `ctx-size` (B.2) and its matching client `limit.context`.

The llama.cpp server README confirms `/v1/chat/completions` is OpenAI-compatible
and accepts per-request sampling (`top_k`, `min_p`, `top_p`, `temperature`,
`presence_penalty`, `repeat_penalty`). The `--models-preset` INI router does
**two separable jobs**:
- **(a) Multi-model routing** — loads `jzaleski/cipher` AND `jzaleski/sage` as
  routable aliases on one port (per-section `hf=` weights, `--models-max`,
  autoload). This is irreducibly **server-side**; there is no client equivalent.
- **(b) Per-alias sampling defaults** — the `min-p` / `top-k` per `[alias]`
  section. This sets the *server-side default* per alias and **can move to the
  client**, since llama-server honors per-request sampling.

Therefore the consistent cross-backend model is: weights + alias names + context
/ cache / batch stay **server-side** (backend-specific); **per-alias sampling
moves to the client** (`opencode.json`), identically for both backends. The INI
keeps only what is irreducibly server-side; it stops carrying sampling.

**Accepted tradeoff (user-confirmed):** moving sampling client-side means a
non-opencode client (raw `curl`, llama.cpp web UI) hitting the server directly
receives the backend's *built-in* sampling defaults (llama.cpp: `top-k 40`,
`min-p 0.05`, `temp 0.8`; vLLM: model `generation_config.json`), NOT the tuned
cipher/sage values. This is acceptable for this opencode-first workflow.

## Usage Profile (user-confirmed)

**Profile (2): occasionally parallel agents/sessions, moderate concurrency,
modest `max-model-len`.** Matches the engineer agent's sub-agent dispatch
pattern (a handful of concurrent requests, not 1, not 1024).

## Design

### Component A — Restore cipher/sage distinction (vLLM, client-side sampling)

**A.1 (DONE in working tree):** `conf/vllm-server.yaml` now lists both aliases:
```yaml
served-model-name:
  - jzaleski/cipher
  - jzaleski/sage
```
Both names resolve to the one loaded checkpoint. `/v1/models` will list both.

**A.2 (NEW — vLLM only):** Move per-alias sampling into the opencode client
config (`home/.config/opencode/opencode.json`) for the **two vLLM** provider
entries. Add an `options` block per model carrying the sampling profile:

- Shared: `temperature: 1.0`, `topP: 0.95`, `presencePenalty: 1.5`
- cipher: `top_k: 40`, `min_p: 0.01`
- sage:   `top_k: 20`, `min_p: 0.0`

Provider entries to update (sampling-bearing `options`):
- `vLLM (server - jzaleski/cipher)`, `vLLM (server - jzaleski/sage)`

The vLLM YAML sampling comments (lines 17-33) are repointed to note that
sampling now lives in the client.

**Deferred (NOT in this effort):** moving sampling client-side for the llama.cpp
provider entries, and removing the sampling keys from the INI files. The
llama.cpp INIs keep their existing `[alias]` sampling sections unchanged (their
only change in this effort is the server context size — see B.2). The
cross-backend "unified sampling" model (F5) remains the eventual direction but
is out of scope here.

**A.3 (VERIFICATION GATE — blocks A.2 completion):** Before declaring A.2 done,
empirically confirm which fields actually reach the vLLM server in the request
body (`curl` test or server-side request logging). For any field that does NOT
forward via opencode's `options` passthrough:
- Use the AI-SDK extra-body mechanism if available, OR
- Document the limitation explicitly and keep that field as a **server-side
  default** in `conf/vllm-server.yaml` (or accept the model's
  `generation_config.json` default), noting why in comments + `AGENTS.md`.

The acceptance criterion is **truthful documentation of what works**, not
forcing unsupported fields. We will not claim a differentiation the vLLM
runtime doesn't honor.

### Component B — Right-size server context/concurrency

**B.1 — vLLM** (`conf/vllm-server.yaml`):
- Add `max-num-seqs: 16` — caps concurrency to a moderate level appropriate for
  parallel sub-agent dispatch, freeing ~63GB of hybrid GDN reservation
  (vs. 1024 default). 16 × 64.4MB ≈ 1.03GB hybrid state.
- Set `max-model-len: 131072` — half the trained max; still a very large
  coding context, materially reducing KV pressure and improving decode locality.

**B.2 — llama.cpp server** (`conf/router-server.ini`):
- `ctx-size: 262144 → 131072`, for consistency with vLLM (user-confirmed).
- **`conf/router-local.ini` is left UNCHANGED** at `ctx-size: 81920`
  (memory-constrained local profile — user-confirmed to leave as-is).
- The INI `[alias]` sampling sections are **left unchanged** (sampling relocation
  for llama.cpp is deferred).

Both are **deliberate, justified** changes (AGENTS.md: "don't change tuned
defaults without clear reason" — the reason is documented here and tied to the
confirmed usage profile). Memory-fraction control (`VLLM_METAL_MEMORY_FRACTION`)
is unchanged.

### Component C — Documentation sync

- `conf/vllm-server.yaml`: reinforce the prefix-caching comment with the vLLM
  source citation (F1); document `max-num-seqs` / `max-model-len` rationale;
  repoint the per-alias sampling comments to note sampling now lives in the
  client (vLLM only).
- `conf/router-server.ini`: note the lowered `ctx-size` rationale. (Sampling
  sections unchanged.)
- `AGENTS.md`: note that on **vLLM**, cipher/sage differ via **client-side**
  sampling (with whatever A.3 verification confirms); that prefix caching is
  mandatorily off for the hybrid vLLM model (F1); and the updated vLLM
  concurrency + both-backend server context defaults. (llama.cpp sampling
  remains server-side/INI for now.)
- `README.md` if it documents these values (to be checked during planning).

## Out of Scope (YAGNI / Deferred)

- Running two vLLM processes on two ports to get true per-model server-side
  sampling — rejected; the single-checkpoint + client-sampling approach is
  simpler and matches the actual (identical-weights) reality.
- **Moving llama.cpp sampling client-side / removing INI `[alias]` sampling keys**
  — deferred to a later effort. INIs keep their sampling sections as-is.
- Changing `conf/router-local.ini` context size — left at 81920 (user-confirmed).
- Enabling prefix caching — impossible per F1.
- Multimodal/VLM wiring — text-only is the intended path.

## Testing & Verification

1. **vLLM:** Restart `bin/run-router --server --experimental`; confirm startup
   log `non-default args` shows both `jzaleski/cipher` and `jzaleski/sage`, and
   `max_num_seqs=16`, `max_model_len=131072`.
2. `curl http://localhost:8080/v1/models` lists both aliases.
3. **A.3 verification (vLLM):** issue a request per alias and confirm (via server
   logging or response behavior) which sampling fields are honored.
4. Confirm vLLM memory breakdown in the log shows the reduced hybrid GDN reservation.
5. **llama.cpp server:** `bash -x bin/run-router --server` starts; INI parses;
   `ctx-size=131072` in effect; both aliases routable with sampling intact.
6. `opencode.json` remains valid JSON (`jq . opencode.json`).

## Files Touched

- `conf/vllm-server.yaml` (A.1 done; B.1; C)
- `conf/router-server.ini` (B.2 ctx-size only; C)
- `home/.config/opencode/opencode.json` (A.2 — two vLLM entries gain sampling
  `options`; two llama.cpp-server entries get `limit.context` 262144 → 131072 to
  stay honest with the lowered server `ctx-size`)
- `AGENTS.md` (C)
- `README.md` (C, if applicable)

> **Note:** `conf/router-local.ini` is intentionally NOT in this list — it is
> fully unchanged. llama.cpp sampling relocation is deferred (see Out of Scope).
