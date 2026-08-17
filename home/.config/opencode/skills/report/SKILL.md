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
- **No application logic changes** — you deliver findings, you don't touch application code.

## Report Format (status back to the orchestrator)

After delivering, report status using this format:

```
Status: DONE | DONE_WITH_CONCERNS

Delivered:
- [output files and/or inline summary, with paths]

Format(s):
- [what the user asked for]

Concerns:
- [anything worth flagging, or "none"]
```

This is the terminal stage of the pipeline. Once the report is delivered, the
work is complete.
