# Dual-Router Architecture and Namespace Refactor

## Purpose
Migrate the existing flat model namespace (`jzaleski/low`, `jzaleski/experimental`, etc.) to a structured, dual-router architecture. This allows standard models (Qwen) and experimental models (DeepSeek, GLM, etc.) to run concurrently on different ports without naming collisions, while maintaining strict obfuscation of the underlying experimental models.

## Namespaces

### 1. Default Namespace (Standard Qwen3.8-27B Models)
*   **Base:** `jzaleski/default/<tier>`
*   **Text-only variants (MTP):**
    *   `jzaleski/default/low`
    *   `jzaleski/default/medium`
    *   `jzaleski/default/high`
*   **Vision-capable variants (No MTP):**
    *   `jzaleski/default/low-multimodal`
    *   `jzaleski/default/medium-multimodal`
    *   `jzaleski/default/high-multimodal`

### 2. Experimental Namespace (Various Architectures)
*   **Base:** `jzaleski/experimental/<particle>`
*   **Variants:**
    *   `jzaleski/experimental/quark` (DeepSeek-V4-Flash)
    *   `jzaleski/experimental/boson` (Qwen3.8-Flash-Next)
    *   *(Future models map to `muon`, `gluon`, `fermion`, etc.)*

## Architecture

### The Router (`bin/run-router`)
*   **Default Mode:** Runs on Port 8080. Serves the 6 standard Qwen aliases using `llama-cpp-default.ini.template`.
*   **Experimental Mode:** Runs on Port 8081. Triggered via a flag (e.g. `--experimental`). Serves the experimental particle aliases using `llama-cpp-experimental.ini.template`.

### Single Model Launcher
*   **Script:** `bin/run-model`
*   **Role:** Continues to launch standalone instances, but updated to accept the new structured flags (e.g., `--tier default/medium`, `--tier experimental/quark`).

## Execution Plan

1.  **Template Overhaul:**
    *   Rename `llama-cpp.ini.template` to `llama-cpp-default.ini.template` and update section headers to `[jzaleski/default/...]`.
    *   Create `llama-cpp-experimental.ini.template` defining `[jzaleski/experimental/quark]` (DeepSeek config) and `[jzaleski/experimental/boson]` (Qwen3.8-Flash-Next config).

2.  **Script Updates:**
    *   Update `bin/run-model` to parse `default/*` and `experimental/*` tiers. Add the download/execution logic for `Qwen3.8-Flash-Next` under the `boson` tier.
    *   Update `bin/run-router` to accept an `--experimental` flag. When present, it switches to port 8081 (unless overridden) and loads `llama-cpp-experimental.ini.template`.

3.  **Config & Docs:**
    *   Update `home/.config/opencode/opencode.json` to define the new `default/` and `experimental/` models across the local and server providers. Add a new local provider for the experimental router on port 8081.
    *   Update `AGENTS.md` and `README.md` to reflect the new architecture, namespaces, and the `--experimental` router flag.
