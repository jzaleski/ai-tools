---
name: report
description: "Deliver analysis findings as a polished output in one or more formats — Markdown, CSV, XLSX, JSON, plain text, or inline. Use as the final pipeline stage once analysis is done. Always asks for the format if unspecified, and always documents the artifacts and scripts it created."
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
