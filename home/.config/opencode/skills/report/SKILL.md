---
name: report
description: "Use when analysis findings exist and need to be delivered as a polished output in a specific format, once analysis is done."
---

# Report Skill

Deliver the findings. This is the final stage of a data pipeline: analysis is
done, and your job is to **present it the way the user actually wants to consume
it** — in one or more output formats.

**Always announce at start:** "I'm using the report skill to write up the findings."

**Work from:** the findings and analysis artifacts (from the analyze skill,
typically in `.pipeline-cache/analysis/`).

## Step 1: Confirm the Output Format

**If the user has not specified a format, ask before producing anything.** Never
generate a large artifact the user didn't ask for.

| Format | Good for |
|---|---|
| Markdown (`.md`) | Human-readable narrative reports with tables and structure |
| CSV | A clean result table for further spreadsheet work |
| XLSX | Multi-sheet results, formatted tables for non-technical recipients |
| JSON | Machine consumption / feeding another tool |
| Plain text | Simple summaries, logs |
| Inline (terminal) | Quick answers the user just wants to read now |

**One or more outputs are fine.** A common pattern: a Markdown narrative *plus* a
CSV of the underlying numbers. Confirm which combination the user wants.

## Step 2: Write the Report

- Lead with the answer. State the finding first, then support it.
- Match length to the question — a one-number answer doesn't need ten paragraphs.
- Include the supporting numbers, tables, or charts the finding rests on.
- **Tie all metrics directly to analysis artifacts.** Every number in the narrative and tables must be verified against analysis outputs.
- **Strict empirical grounding.** Frame conclusions strictly from observed data. Do not make unverified causal leaps or speculative assertions.
- Surface caveats and assumptions honestly (carried forward from analysis).
- Save file outputs to a sensible location (project root or a user-specified
  path), not buried in `.pipeline-cache/` — the report is a deliverable, not a
  cache artifact.

**Persistence is environment-adaptive.** The report content is the canonical
output in every environment — always render it inline (or in the requested
format) so the user receives the deliverable directly:

- **When a durable working directory is available** (e.g., opencode): write the
  requested file outputs (`.md`, `.csv`, `.xlsx`, etc.) to a sensible path and
  reference them.
- **When no durable filesystem is available** (e.g., a Claude organizational
  skill): code execution still works for generating files (e.g. building an XLSX
  in the sandbox) — produce the requested format and deliver it as
  downloadable/copyable output rather than assuming a stable on-disk path. For
  text-shaped formats (Markdown, plain text, JSON), inline delivery is the
  deliverable itself.

## Output Format & Metric Verification

<HARD-GATE>
Never deliver a report without verifying that every reported metric ties back directly to an analysis artifact or script output, the deliverable format strictly matches what the user requested, and narrative conclusions strictly reflect empirical findings without speculative extrapolation.
</HARD-GATE>

Before delivering the report, verify the following three gates:

1. **Metric Provenance Verification:**
   - **Direct tie-back:** Every number, percentage, delta, or count cited in the narrative, executive summary, or tables must trace directly to a verified artifact in `.pipeline-cache/analysis/` or output from `scripts/`.
   - **Internal consistency:** Cross-check numbers cited in text against accompanying tables or charts. Ensure rounded figures do not introduce arithmetic contradictions (e.g., percentages summing to 94% instead of 100%).
   - **Zero unverified claims:** If a metric cannot be tied back to an analysis output, remove it or run the analysis script to verify it before delivering.

2. **Deliverable Format Verification:**
   - **Format match:** Confirm the deliverable strictly matches the user's requested format(s) (Markdown, CSV, XLSX, JSON, plain text, or inline).
   - **Deliverable packaging:** If the user requested dual deliverables (e.g., Markdown narrative + CSV result table), verify that all requested files are written to their target paths.
   - **No unrequested formats:** Do not generate extra unsolicited formats (e.g. generating an unwanted XLSX when only a markdown summary was asked for). If format is unspecified, ask first.

3. **Empirical Narrative Grounding:**
   - **Reflect empirical truth:** Narrative conclusions, takeaways, and recommendations must strictly derive from observed analysis evidence.
   - **No causal leap:** Distinguish correlation from causation. Do not claim "feature X caused drop in retention" if the analysis only demonstrates correlation across time periods without a controlled experiment.
   - **Disclose caveats & uncertainty:** Explicitly carry forward any data limitations, sampling constraints, or anomalies identified in the ingest and analyze stages.

## Step 3: Artifacts & Scripts Section (Mandatory)

**Every report ends with an Artifacts & Scripts section. This is non-negotiable.**
It tells the user what was created, where it lives, and what each piece does — so
the work is reproducible and nothing is a mystery.

```markdown
## Artifacts & Scripts

**Outputs delivered:**
- `report.md` — the narrative report (this file)
- `results.csv` — the underlying result table

**Pipeline cache (intermediate, safe to delete):**
- `.pipeline-cache/extracted/` — raw per-file extractions
- `.pipeline-cache/normalized/` — the cleaned, unified dataset
- `.pipeline-cache/analysis/` — intermediate analysis tables

**Scripts (in `scripts/`):**
- `extract.py` — pulled data from the source files
- `analyze.py` — computed the findings

**Decisions worth knowing:**
- [normalization/analysis judgment calls that affect interpretation, or "none"]
```

**The section is mandatory in every environment**, but adapt how it references
artifacts: when a durable filesystem is available, list real paths as above.
When none is available (e.g., a Claude organizational skill), list each artifact
by name and how it was delivered (inline / downloadable) instead of a path that
won't persist — the goal is unchanged: the user knows exactly what was produced,
how it was computed, and what decisions shaped it.

## Hard Constraints

- **Ask before reporting if format is unspecified.** Never assume.
- **Never produce an unrequested output format.**
- **The Artifacts & Scripts section is mandatory** in every report.
- **Enforce metric provenance and empirical grounding.** Never state numbers that cannot be tied to analysis artifacts, and never assert causal claims unsupported by data.
- **No application logic changes** — you deliver findings, you don't touch application code.

## Report Format (status back to the orchestrator)

After delivering, report status using this format:

```
Status: DONE | DONE_WITH_CONCERNS

Delivered:
- [output files and/or inline summary, with paths]

Format(s):
- [what the user asked for]

Verification gates:
- Metric provenance: verified (all numbers trace directly to analysis artifacts/scripts)
- Format compliance: verified (matches requested deliverable format)
- Empirical grounding: verified (conclusions strictly grounded in observed evidence; zero causal overreach)

Concerns:
- [anything worth flagging, or "none"]
```

This is the terminal stage of the pipeline. Once the report is delivered, the
work is complete.

## Red Flags

| Thought | Reality |
|---|---|
| "I remember the number from earlier in the analysis" | Memories hallucinate or confuse preliminary queries with final runs. Verify every number against the actual saved analysis artifact. |
| "The narrative sounds more compelling with a strong causal statement" | Compelling narrative must never overstate empirical evidence. Restrict claims to what the data proves. |
| "I'll also generate an Excel sheet just in case they want it" | Unrequested formats waste time and clutter workspaces. Deliver only the requested format(s). |
| "The table says 42.4% but I'll write 'nearly half' in the headline" | Imprecise paraphrasing distorts findings. State '42.4%' clearly so the reader has the factual data. |
| "I'll round this intermediate number to make the text cleaner" | Casual rounding creates discrepancies between narrative text and supporting tables. Keep numbers consistent. |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The user asked for insights, so I should hypothesize on business causes" | Clearly distinguish verified empirical data from speculative hypotheses. Label hypotheses as speculative. |
| "A quick summary doesn't need to check back against analysis files" | Even a 2-line summary can misquote an aggregation or swap columns. Always cross-check numbers against artifacts. |
| "The difference between 12.3% and 12% doesn't matter" | Casual rounding leads to reconciliation errors when readers check supporting tables. Maintain precision. |
| "The user didn't specify a format, so Markdown is always fine" | Never assume. Always ask before producing deliverables if format was unspecified. |
| "The analysis script produced it, so I don't need to check the text" | Extraction errors and typos happen when transferring numbers to narrative. Audit every figure. |
