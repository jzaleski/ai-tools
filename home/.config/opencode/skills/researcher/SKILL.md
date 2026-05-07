---
name: researcher
description: "Mandatory pre-work step — explores project context, asks clarifying questions one at a time, proposes approaches, presents design for user approval. Terminal state: user-approved design doc ready for planning."
---

# Researcher — Design & Discovery Skill

Turn vague ideas into approved designs through structured dialogue. This is the mandatory first phase before any implementation planning or coding happens.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

**Always announce at start:** "I'm using the researcher skill to design this before implementing."

## Scope Detection

Before asking questions, assess whether the request describes multiple independent subsystems (e.g., "build a platform with chat, file storage, billing, and analytics"). If so:
- Flag this immediately — don't refine details of something that needs decomposing first
- Help the user decompose into sub-projects: independent pieces, relationships, build order
- Brainstorm the FIRST sub-project through the normal flow. Each sub-project gets its own design → plan → implement cycle.

## Process Checklist

Complete these items in order. Don't skip steps:

1. **Explore project context** — read files, docs, recent commits, existing patterns
2. **Ask clarifying questions** — one at a time (purpose, constraints, success criteria)
3. **Propose 2-3 approaches** — with trade-offs and your recommendation
4. **Present design** — in sections scaled to complexity, get user approval after each section
5. **Write design doc** — save to `docs/specs/YYYY-MM-DD-<topic>-design.md`
6. **Spec self-review** — fix placeholders, contradictions, ambiguity, scope issues inline
7. **User reviews written spec** — ask user to review before proceeding
8. **Transition to planning** — invoke the planner skill (this is the only skill you hand off to)

## The Process

### 1. Explore Project Context

Check out current project state first:
- Files, docs, recent commits, existing patterns
- If working in an existing codebase: follow established patterns
- Where existing code has problems that affect the work (large files, unclear boundaries), include targeted improvements as part of the design — but don't propose unrelated refactoring

### 2. Ask Clarifying Questions

- **One question per message.** If a topic needs more exploration, break it into multiple questions.
- Prefer multiple choice when possible; open-ended is fine too.
- Focus on: purpose, constraints, success criteria, any non-negotiables.
- Don't overwhelm — the user should always know what you're asking about before moving to the next topic.

### 3. Propose Approaches

Propose 2-3 different approaches with trade-offs:
- Lead with your recommended option and explain why
- Present options conversationally, not as a rigid list
- Be ready to modify or combine approaches based on user feedback

### 4. Present the Design

Present the design in sections scaled to their complexity:
- A few sentences for straightforward items; up to 200-300 words for nuanced topics
- Cover: architecture, components, data flow, error handling, testing approach
- Ask after each section whether it looks right so far before moving on
- Be ready to iterate — if something doesn't make sense, go back and clarify

**Design principles to enforce:**
- Break the system into smaller units with one clear purpose
- Each unit should communicate through well-defined interfaces
- Smaller, well-bounded units are easier for sub-agents to reason about
- A file growing large is often a signal it's doing too much — include splits where appropriate

### 5. Write Design Doc

Save the validated design to `docs/specs/YYYY-MM-DD-<topic>-design.md`:
- Use clear, concise language (avoid jargon when a simple word works)
- Commit the document to git after writing

### 6. Spec Self-Review

After writing the spec, review it yourself:

1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections, or vague requirements? Fix them.
2. **Internal consistency:** Do any sections contradict each other? Does the architecture match the feature descriptions?
3. **Scope check:** Is this focused enough for a single implementation plan, or does it need decomposition?
4. **Ambiguity check:** Could any requirement be interpreted two different ways? If so, pick one and make it explicit.

Fix issues inline. No need to re-review — just fix and move on.

### 7. User Review Gate

After the self-review loop passes, ask the user:

> "Spec written and committed to `<path>`. Please review it and let me know if you want to make any changes before we start planning the implementation."

Wait for approval. If they request changes, make them and re-run the self-review loop. Only proceed once approved.

### 8. Transition to Planning

The terminal state is invoking the **planner** skill. Do NOT invoke any other skill or step into implementation directly.

> "Design approved. Switching to planning — I'll decompose this into executable tasks next."

Load: `skills/planner`

## Key Principles

- **One question at a time** — don't overwhelm
- **Multiple choice preferred** — easier to answer than open-ended
- **YAGNI ruthlessly** — remove unnecessary features from all designs
- **Explore alternatives** — always propose 2-3 approaches before settling
- **Incremental validation** — present design, get approval before moving on
- **Be flexible** — go back and clarify when something doesn't make sense
