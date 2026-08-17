---
name: analyze
description: "Use after data has been ingested and normalized, when you need aggregations, groupings, comparisons, trends, outliers, distributions, or joins — insight rather than just extraction."
---

# Analyze Skill

Answer the question being asked of a clean dataset. This is the middle stage of
a data pipeline: the data is already extracted and normalized — your job is to
**turn it into findings**. This is a single-pass stage; no parallelism needed.

**Always announce at start:** "I'm using the analyze skill to work through the data."

**Work from:** the normalized artifacts in `.pipeline-cache/normalized/` (produced
by the ingest skill). If they don't exist yet, stop — the data must be ingested
and normalized first.

## Before You Begin

Be clear on **what question you're answering.** If the analysis goal is vague
("look at this data"), ask the user what they actually want to know before
producing numbers. Aimless analysis wastes effort and buries the real answer.

Good clarifying questions:
- What decision will this analysis inform?
- Are there specific metrics, segments, or time periods that matter?
- Is there a comparison or baseline you care about?

## Common Analysis Types

Match the technique to the question — don't run every analysis reflexively.

| Question shape | Technique |
|---|---|
| "How much / how many in total or per group?" | Aggregation, group-by |
| "How does X compare to Y?" | Comparison, ratios, deltas |
| "Is it going up or down over time?" | Trend detection, moving averages |
| "What's unusual here?" | Outlier / anomaly identification |
| "How is X distributed?" | Frequency distribution, histograms, percentiles |
| "How do these two datasets relate?" | Join across datasets, correlation |

## How to Work

1. Load the normalized dataset(s) from `.pipeline-cache/normalized/`.
2. Apply the analysis that answers the question. Write a script in `scripts/` —
   data work belongs in reproducible code, not ad-hoc mental math.
3. Match depth to the task. A simple total doesn't need a regression; a "why did
   sales drop" question may need several cuts of the data.
4. **Surface the unexpected.** If you notice something noteworthy that wasn't
   part of the original question (a data quality issue, a surprising outlier, a
   stronger pattern elsewhere), flag it — don't bury it.
5. Save intermediate analysis outputs to `.pipeline-cache/analysis/` if they're
   worth keeping for the report stage (e.g. a summary table, an aggregated CSV).

## Persistence (Environment-Adaptive)

**Findings are the canonical output in every environment** — always render them
inline (the *Report Format* block below). The findings, not a file, are the
deliverable of this stage.

Intermediate analysis artifacts and scripts are the *persistence layer*, and the
mechanism adapts to the environment:

- **When a durable working directory is available** (e.g., opencode): write
  intermediate tables to `.pipeline-cache/analysis/` and analysis code to
  `scripts/`, and reference them by path.
- **When no durable filesystem is available** (e.g., a Claude organizational
  skill): code execution still works — run the analysis and produce the same
  intermediate artifacts in the working sandbox, but do not assume a stable path
  persists. Surface any table the report stage needs inline (and as
  downloadable/copyable output if supported) rather than pointing at a path.

Either way the analysis is reproducible code, not ad-hoc mental math; only where
(and whether) the intermediate artifacts land on disk changes.

## Tooling & Reuse

- **Python is the natural default.** Prefer `pandas`, `numpy` and the standard library. Avoid exotic dependencies; call it out when one is genuinely necessary.
- **No silent installs.** Surface missing packages to the user.
- **Reproducible, not ad-hoc.** The analysis script is the record of how a finding was reached — keep it in `scripts/`.
- **Session-scoped by default.** Scripts are throwaway unless explicitly promoted.

## Hard Constraints

- **No application logic changes.** You analyze data; you do not fix, refactor, or change any application source code. If you notice application code that looks relevant or broken, note it and leave it alone.
- **Never mutate source or normalized inputs.** Read them; write new outputs.

## When You're in Over Your Head

It's always OK to stop. A wrong conclusion is worse than an honest "the data
can't answer this."

**Stop and report when:**
- The data can't actually answer the question asked (say so plainly)
- The analysis needs a domain decision only the user can make
- Results look implausible and you suspect an upstream data problem (flag it back toward ingest)

## Report Format

When done, report findings using this format:

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED

Question:
- [what you set out to answer]

Findings:
- [the answer(s), with the numbers that support them]

Unexpected / noteworthy:
- [anything surprising surfaced along the way, or "none"]

Analysis artifacts:
- .pipeline-cache/analysis/<name> (what it contains)
- scripts/<name> (what it computes)

Concerns / caveats:
- [data limitations, assumptions, or "none"]
```

Hand off to the **report** skill (or back to the orchestrating agent) to deliver
the findings in the format the user wants.
