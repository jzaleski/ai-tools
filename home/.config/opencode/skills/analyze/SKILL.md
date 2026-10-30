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
4. **Execute convergence and distribution anomaly checks.** Never report summary
   metrics without mathematically reconciling aggregations against raw totals,
   checking distributions for skew, and isolating extreme outliers.
5. **Surface the unexpected.** If you notice something noteworthy that wasn't
   part of the original question (a data quality issue, a surprising outlier, a
   stronger pattern elsewhere), flag it — don't bury it.
6. Save intermediate analysis outputs to `.pipeline-cache/analysis/` if they're
   worth keeping for the report stage (e.g. a summary table, an aggregated CSV).

## Convergence & Distribution Anomaly Checks

<HARD-GATE>
Never report aggregated numbers, averages, or summary metrics without explicit sanity checks against raw totals and underlying distributions. A single-pass analysis must prove mathematical consistency and disclose anomalies.
</HARD-GATE>

Every analysis script must incorporate explicit sanity-checking routines:

1. **Convergence & Total Reconciliation:**
   - **Sum of parts equals the whole:** Whenever computing grouped totals (e.g., revenue by segment, counts by status), verify that $\sum \text{subgroup\_totals} == \text{grand\_total}$.
   - **Row conservation:** Confirm that grouped counts account for 100% of rows in the normalized dataset. Account for any rows excluded due to null group keys.
   - **Filter accounting:** When filtering data subsets, compute and report exact retention: `retained_rows + excluded_rows == total_rows`.

2. **Distribution Auditing & Skew Detection:**
   - **Beyond central tendency:** Do not rely solely on the mean. Always calculate the median, standard deviation, and key percentiles (p5, p25, p50, p75, p95, p99).
   - **Detecting data skew:** When mean and median diverge significantly, identify the underlying skew (e.g., long-tail distribution, Pareto distribution). Report both and explain the divergence.
   - **Bimodal & clustered distributions:** Check whether data clusters around multiple modes or zero-points that make a single average misleading.

3. **Outlier & Anomaly Isolation:**
   - **Extreme value scanning:** Scan for extreme values (e.g. > 3 standard deviations from mean or > 1.5× IQR).
   - **Classification:** Determine whether outliers reflect real extreme phenomena, default/sentinel values (e.g., `999`, `-1`), or data corruption.
   - **Sensitivity testing:** Run a sensitivity check—compare findings with and without the extreme values. If a handful of outliers drive the majority of the metric, highlight this prominently.

4. **Join Integrity Checks:**
   - When joining multiple normalized tables, verify cardinality before and after the join.
   - Confirm the join did not produce unintended row duplication (cartesian product) or silent record loss (unintended inner join exclusions).

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
- **Never report summaries without convergence and anomaly checks.** Reconcile subgroup sums against raw grand totals and audit distributions for skew and outliers.

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

Convergence & Anomaly Checks:
- Total reconciliation: [e.g., sum of 5 categories ($1,245,500) matches population grand total ($1,245,500)]
- Distribution checks: [e.g., median ($42) vs mean ($115) indicates heavy positive skew; p95 = $350]
- Outliers identified: [e.g., 3 records > $10,000 isolated; sensitivity check shows they drive 18% of volume]
- Join integrity: [e.g., 1:1 join verified; 0 dropped records, 0 row inflation]

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

## Red Flags

| Thought | Reality |
|---|---|
| "The average is 45, so that represents the dataset" | Averages without distributions hide severe skew, outliers, or bimodal patterns. Check medians and percentiles. |
| "The group-by sums look reasonable" | 'Looks reasonable' is not proof. Reconcile group sums against the grand total to ensure no dropped or double-counted rows. |
| "The join finished, so the data is aligned" | Joins can silently drop records (inner join) or cause cartesian explosions (many-to-many). Verify row counts pre- and post-join. |
| "I'll omit these extreme values since they look weird" | Never silently discard outliers. Investigate whether they are data glitches or real, impactful events, and report them. |
| "The chart looks smooth so the aggregation is valid" | Visual smoothing masks underlying anomalies and data gaps. Verify the underlying distribution numerically. |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The user only asked for the total, so I don't need distribution checks" | Extreme outliers or corrupted records might make up 80% of the total. Anomaly checks ensure the total is trustworthy. |
| "The discrepancy between sum of parts and total is small, so it's rounding" | Prove it is rounding. Small discrepancies often hide missing categories, null keys, or filter leaks. |
| "A single-pass query in pandas is always correct" | Filtering, NaN handling in groupbys, and integer overflow can silently alter results. Sanity-check results against independent counts. |
| "There were only a few null keys in the join so it doesn't matter" | Null keys in joins mean unmapped records that vanish from the analysis. Account for every unmapped row. |
| "I don't have time to compute percentiles" | Computing `.describe()` or quantiles takes milliseconds. Skipping it risks presenting distorted insights. |
