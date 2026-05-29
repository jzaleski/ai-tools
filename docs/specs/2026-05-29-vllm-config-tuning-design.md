# Design: vLLM Config Tuning & Unified Client-Side Sampling (vLLM + llama.cpp)

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

### F5 — llama.cpp honors per-request sampling; INI router does two jobs

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

### Component A — Restore cipher/sage distinction via unified client-side sampling

**A.1 (DONE in working tree):** `conf/vllm-server.yaml` now lists both aliases:
```yaml
served-model-name:
  - jzaleski/cipher
  - jzaleski/sage
```
Both names resolve to the one loaded checkpoint. `/v1/models` will list both.

**A.2 (NEW — applies to BOTH backends):** Move per-alias sampling into the
opencode client config (`home/.config/opencode/opencode.json`) for the relevant
provider entries. Per F5, this is the consistent cross-backend model: sampling
lives in the client, not in the server config. Add an `options` block per model
carrying the sampling profile:

- Shared: `temperature: 1.0`, `topP: 0.95`, `presencePenalty: 1.5`
- cipher: `top_k: 40`, `min_p: 0.01`
- sage:   `top_k: 20`, `min_p: 0.0`

Provider entries to update (sampling-bearing `options`):
- `vLLM (server - jzaleski/cipher)`, `vLLM (server - jzaleski/sage)`
- `llama.cpp (local - jzaleski/cipher)`, `llama.cpp (local - jzaleski/sage)`
- `llama.cpp (server - jzaleski/cipher)`, `llama.cpp (server - jzaleski/sage)`

Correspondingly, **remove the per-`[alias]` sampling keys** (`min-p`, `top-k`)
and the shared sampling keys (`presence-penalty`, `repeat-penalty`, `temp`,
`top-p`) from `conf/router-local.ini` and `conf/router-server.ini`. The INI
retains only irreducibly server-side keys (weights, `ctx-size`, cache types,
batch sizes) and the `[alias]` section headers needed for routing. The vLLM YAML
sampling comments (lines 17-33) are likewise removed/repointed to the client.

**A.3 (VERIFICATION GATE — blocks A.2 completion):** Before declaring A.2 done,
empirically confirm which fields actually reach each server in the request body
(`curl` test or server-side request logging, per backend). For any field that
does NOT forward via opencode's `options` passthrough:
- Use the AI-SDK extra-body mechanism if available, OR
- Document the limitation explicitly and keep that field as a **server-side
  default in BOTH configs** (INI `[alias]` section and vLLM) for consistency,
  noting why in comments + `AGENTS.md`.

The acceptance criterion is **truthful documentation of what works**, not
forcing unsupported fields. We will not claim a differentiation the runtime
doesn't honor. Whatever the verification concludes is applied symmetrically to
both backends so they stay consistent.

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

Both are **deliberate, justified** changes (AGENTS.md: "don't change tuned
defaults without clear reason" — the reason is documented here and tied to the
confirmed usage profile). Memory-fraction control (`VLLM_METAL_MEMORY_FRACTION`)
is unchanged.

### Component C — Documentation sync

- `conf/vllm-server.yaml`: reinforce the prefix-caching comment with the vLLM
  source citation (F1); document `max-num-seqs` / `max-model-len` rationale;
  remove/repoint the per-alias sampling comments to the client.
- `conf/router-server.ini` / `conf/router-local.ini`: document that sampling now
  lives client-side; keep only routing + server-side keys (and any A.3 fallback
  server-side defaults).
- `AGENTS.md`: note that for BOTH backends, cipher/sage differ via **client-side**
  sampling (with whatever A.3 verification confirms); that prefix caching is
  mandatorily off for the hybrid vLLM model (F1); the updated context/concurrency
  defaults; and the accepted bare-request tradeoff (F5).
- `README.md` if it documents these values (to be checked during planning).

## Out of Scope (YAGNI)

- Running two vLLM processes on two ports to get true per-model server-side
  sampling — rejected; the single-checkpoint + client-sampling approach is
  simpler and matches the actual (identical-weights) reality.
- Changing `conf/router-local.ini` context size — left at 81920 (user-confirmed).
- Enabling prefix caching — impossible per F1.
- Multimodal/VLM wiring — text-only is the intended path.

## Testing & Verification

1. **vLLM:** Restart `bin/run-router --server --experimental`; confirm startup
   log `non-default args` shows both `jzaleski/cipher` and `jzaleski/sage`, and
   `max_num_seqs=16`, `max_model_len=131072`.
2. `curl http://localhost:8080/v1/models` lists both aliases.
3. **A.3 verification (both backends):** issue a request per alias and confirm
   (via server logging or response behavior) which sampling fields are honored;
   apply conclusions symmetrically.
4. Confirm vLLM memory breakdown in the log shows the reduced hybrid GDN reservation.
5. **llama.cpp server:** `bash -x bin/run-router --server` starts; INI parses
   with sampling removed; `ctx-size=131072` in effect; both aliases routable.
6. `opencode.json` remains valid JSON (`jq . opencode.json`).
7. INI files still parse (no orphaned/empty `[alias]` sections that break routing).

## Files Touched

- `conf/vllm-server.yaml` (A.1 done; B.1; C)
- `conf/router-server.ini` (A.2 sampling removal; B.2 ctx-size; C)
- `conf/router-local.ini` (A.2 sampling removal; C — ctx-size UNCHANGED)
- `home/.config/opencode/opencode.json` (A.2 — vLLM + llama.cpp local + server entries)
- `AGENTS.md` (C)
- `README.md` (C, if applicable)
