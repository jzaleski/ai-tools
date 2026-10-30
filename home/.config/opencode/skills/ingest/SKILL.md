---
name: ingest
description: "Use when you have one or more raw files (PDF, XLSX, CSV/TSV, JSON, HTML, Markdown, plain text) that need extracting, cleaning, and normalizing into one dataset."
---

# Ingest Skill

Turn a pile of raw, messy files into one clean, consistent dataset. This is the
first stage of a data pipeline: **extract → clean → converge (normalize)**. When
you have many files, you extract them in parallel, then bring the results
together into a single aligned shape that the next stage can analyze.

**Always announce at start:** "I'm using the ingest skill to extract and normalize the data."

**Work from:** the project directory (provided by whoever invoked this skill).

## What This Skill Produces

- Per-file extracted artifacts in `.pipeline-cache/extracted/`
- One (or a small number of) normalized, analysis-ready artifact(s) in `.pipeline-cache/normalized/`
- A short manifest of what came in, what came out, and any warnings

## Persistence (Environment-Adaptive)

**The manifest is the canonical output in every environment** — always render it
inline (the *Report Format* block below) so whoever invoked the skill sees what
came in, what came out, and any warnings.

The pipeline-cache artifacts are the *persistence layer*, and the mechanism adapts
to the environment:

- **When a durable working directory is available** (e.g., opencode): write the
  extracted and normalized artifacts to the `.pipeline-cache/` paths above and
  reference them by path. Subsequent stages read them from there.
- **When no durable filesystem is available** (e.g., a Claude organizational
  skill): code execution still works — produce the same artifacts in the working
  sandbox and carry them forward to the analyze stage within the session, but do
  not assume a stable path like `.pipeline-cache/` persists or is user-visible.
  Surface the normalized dataset inline (and as downloadable/copyable output if
  the environment supports it) rather than pointing at a path.

Either way the *shape* of the output is identical — the same extracted, then
normalized dataset and the same manifest; only where (and whether) it lands on
disk changes.

## Non-Negotiable Rules

- **Never mutate source files.** Raw inputs are read-only. Every output goes to a new file.
- **Evidence before completion.** Never declare normalization complete without running the normalization evidence gates (row count reconciliation, schema conformity, and null-rate audit).
- **No silent installs.** If a required package isn't available, surface it to the user — don't install it silently.
- **Document judgment calls.** Anything that required interpretation (ambiguous columns, how missing values were handled) gets noted so the analysis stage and the user can see it.
- **Cache, don't reprocess.** If a normalized artifact already exists from earlier in the same session, reuse it.

## Step 1: Extract (per file)

Each input file is extracted by the appropriate parser into a workable form.

| Format | Tool | Output → `.pipeline-cache/extracted/` |
|---|---|---|
| PDF | `pdfplumber` or `pypdf` | `<basename>.json` (text + metadata) |
| XLSX/XLS | `openpyxl` / `pandas` | `<basename>.csv` (per-sheet, merged where sensible) |
| CSV/TSV | `pandas` | `<basename>.csv` (cleaned) |
| JSON | `json` / `pandas` | `<basename>.json` (schema-checked if applicable) |
| HTML tables | `BeautifulSoup` / `pandas.read_html` | `<basename>.csv` |
| Markdown tables | `pandas.read_html` or manual parsing | `<basename>.csv` |
| Plain text | shell (`sed`, `awk`) or Python | `<basename>.txt` (cleaned) |

**Each per-file extraction unit does exactly this:**
1. Read the source file with the right parser.
2. Extract the structured data.
3. Clean basic formatting issues (whitespace, encoding).
4. Save to `.pipeline-cache/extracted/<basename>.<ext>`.
5. Record: fields extracted, row count, and any warnings (missing/partial data).

Write extraction scripts to `scripts/` by default. They are session-scoped and
throwaway unless explicitly promoted (see *Tooling & Reuse*).

## Step 2: Choose Your Parallelism Rung

Extraction across multiple files is independent work — different files, no
shared state — so it parallelizes cleanly. **Match the mechanism to the scale.
Don't over-engineer trivial extractions.**

| Scale | Rung | Mechanism |
|---|---|---|
| **Single file** | Inline | Just extract it. No parallelism. |
| **2–5 files, same format** | In-process concurrency | One script, a thread/process pool (e.g. `concurrent.futures.ThreadPoolExecutor`) iterating the files. |
| **2–5 files, mixed formats** | Shell fan-out | One script per format, run concurrently: `python extract_pdfs.py & python extract_xlsx.py & wait`. |
| **Many files, or slow/heavy processing** | Sub-agent fan-out | Dispatch one worker per file (or per batch) so each gets isolated context and its own format tooling. |

**Climb only as high as the work justifies.** A single CSV needs no pool. Three
PDFs do not need sub-agents. Reserve sub-agent fan-out for genuinely heavy or
numerous inputs where isolated context actually helps.

### Note for orchestrating agents

If an orchestrator is driving this skill, it may dispatch the per-file
extraction unit (Step 1) as parallel sub-agents instead of running the in-process
pool — that's the top rung above. Either way the *output contract* is identical:
extracted artifacts land in `.pipeline-cache/extracted/`, and Step 3 converges
them. Whoever fans out owns waiting for all units to finish before Step 3.

## Step 3: Converge & Normalize

This is a **convergence step** — every extraction unit must finish before it
begins. Bring all extracted artifacts into one consistent, analysis-ready shape.

Handle the common messes:
- Inconsistent column names → align to one naming scheme
- Mixed date/number formats → normalize to one representation
- Whitespace, encoding problems → clean
- Merged cells, multi-header rows → flatten
- Missing values → handle explicitly (and document how)

Save the result(s) to `.pipeline-cache/normalized/<name>.csv` (or `.json` where
that fits the data better). If multiple inputs describe the same entity, join or
stack them here so analysis works from one source.

**Document every normalization decision that required judgment.** The analysis
stage and the user both need to trust the clean dataset.

### Data Normalization Evidence Gates

<HARD-GATE>
Never declare normalization complete without verifiable evidence: row count reconciliation against raw source files, schema conformity across all inputs, and column null-rate verification. No assumptions, estimations, or unverified claims.
</HARD-GATE>

Before declaring the normalized dataset ready for analysis, execute a verification script and record empirical evidence:

1. **Row Count Reconciliation:**
   - Sum total rows extracted from all raw sources ($\sum \text{source\_rows}$).
   - Count normalized rows ($\text{normalized\_rows}$).
   - Prove the reconciliation equation:
     $$\sum \text{source\_rows} - \text{dropped\_rows} = \text{normalized\_rows}$$
   - Any dropped rows must be accounted for with exact counts and documented reasons (e.g. duplicate keys, blank rows, trailing totals). Unexplained dropped rows indicate parser failure or silent record loss.

2. **Schema Conformity:**
   - Confirm unified column names match the target naming standard across all sources (no accidental variations like `CustomerID` vs `customer_id` or `Date` vs `Timestamp`).
   - Validate that data types conform across all merged files (numeric fields are strictly numeric, timestamps follow ISO-8601, booleans are normalized).
   - Check categorical values for consistent casing, whitespace trimming, and uniform representation.

3. **Column Null & Missing Value Rates:**
   - Calculate the percentage of null/missing values for every column in the normalized output.
   - Investigate unexpected null spikes: an abrupt surge in nulls often reveals misaligned CSV delimiters, bad column offsets, or regex parsing failures rather than legitimate missing data.
   - Ensure primary key / entity identifier columns contain exactly 0% nulls.

## Tooling & Reuse

- **Write scripts freely.** Wrangling data with a script is expected and encouraged.
- **Python is the natural default.** Prefer common libs: `pandas`, `openpyxl`, `pdfplumber`, `csv`, `json`, `tabulate`. Avoid exotic dependencies; call it out when one is genuinely necessary.
- **Session-scoped by default.** Scripts in `scripts/` are throwaway unless promoted.
- **Promotion path.** If you write substantially the same utility more than once in a session, consider extracting it into a named, documented function. Judgment call — do it when it saves real effort, and document the promotion.

## When You're in Over Your Head

It is always OK to stop and surface a problem rather than guess. Bad data is
worse than no data.

**Stop and report when:**
- A source file is corrupt, encrypted, or in a format you can't parse
- The data is too ambiguous to normalize without a decision only the user can make
- A required package is missing (surface it — never silently install)

## Report Format

When done, report using this format:

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED

Inputs:
- <file> (<format>, <rows/pages>)

Extracted artifacts:
- .pipeline-cache/extracted/<name> (<rows>, <warnings or "clean">)

Normalized output:
- .pipeline-cache/normalized/<name> (<rows> × <cols>)

Normalization evidence gates:
- Row count reconciliation: <sum of source rows> source rows in → <normalized rows> output rows (<dropped count> dropped: <reason>)
- Schema conformity: verified (<column count> columns aligned, types validated)
- Null rate audit: verified (highest null rate: <col> at <pct>%, zero nulls in ID columns)

Normalization decisions:
- [judgment calls made, or "none — clean passthrough"]

Concerns:
- [anything worth flagging, or "none"]
```

Hand off to the **analyze** skill (or back to the orchestrating agent) once the
normalized dataset exists.

## Red Flags

| Thought | Reality |
|---|---|
| "The script completed with exit code 0, so normalization is done" | Exit code 0 only means the script didn't crash. Verify row counts and null rates against source data. |
| "A few missing rows don't matter in a large dataset" | Unaccounted dropped rows indicate silent parsing failures, broken delimiters, or dropped records. Reconcile every row. |
| "I'll fill missing values with 0 or empty string silently" | Silent imputation corrupts downstream analysis. Document every default or imputation explicitly. |
| "The columns have similar names, so I'll just concatenate them" | Misaligned columns cause silent null-padding. Explicitly map schemas and check conformity. |
| "I don't need to check null rates because the source looked clean" | Parsing often silently converts unparseable strings to NaN/null. Verify null rates after ingestion. |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The file is CSV so `pd.read_csv` handled everything correctly" | CSV dialects, encoding issues, trailing commas, or embedded newlines silently corrupt rows. Check row counts and sample parsed lines. |
| "I can skip verification because this is just a quick exploratory analysis" | Downstream findings and decisions depend on normalized truth. Corrupted data leads to false conclusions. |
| "The row count mismatch is probably just header rows or blanks" | 'Probably' is not evidence. Count header and blank rows explicitly to prove the reconciliation math. |
| "I can fix schema discrepancies during the analyze stage" | Ingest owns normalization. Leaking unaligned schemas into analyze creates fragile, ad-hoc workarounds. |
| "The dataset is huge so checking null rates is too slow" | Summary statistics (e.g. `df.isnull().mean()`) take seconds even on millions of rows. Never skip null audits. |
