---
name: researcher
description: "Use before writing any implementation plan or code — when requirements need clarifying, approaches need exploring, or a design needs approval."
---

# Researcher — Design & Discovery Skill

Turn vague ideas into approved designs through structured dialogue. This is the mandatory first phase before any implementation planning or coding happens.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, install dependencies, create projects, or take any implementation action until you have presented a design and the user has approved it (the short doc for small changes, the full design doc for projects). This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

**Always announce at start:** "I'm using the researcher skill to design this before implementing."

## Scope Detection

Before asking questions, assess whether the request describes multiple independent subsystems (e.g., "build a platform with chat, file storage, billing, and analytics"). If so:
- Flag this immediately — don't refine details of something that needs decomposing first.
- Help the user decompose into sub-projects: independent pieces, relationships, build order.
- Design the FIRST sub-project through the normal flow. Each sub-project gets its own design → plan → implement cycle.

## Look Before You Ask

In an existing project, or when context has been provided (a spec, a plan, a handoff, files pointed at, earlier conversation), dig in before your first message:
- Read what was referenced and the code or material it connects to.
- Keep reading until you can explain how the relevant parts work today and what this change would touch.
- Follow established project conventions and architectural boundaries.
- **Never ask what the project or context already answers.**

## Your First Message

Move the work forward with a structured first message (~200 words total):
- **Echo the request back:** Restate what they want, who it's for, and why in your own words so they can see whether you've grasped its shape.
- **Highlight project connections & constraints:** State what you found in the codebase that bears on it — how relevant parts work today, existing patterns, and what the change would touch.
- **Surface non-obvious factors:** If you found a constraint, conflict, or cheaper path that changes what they're asking for or how it must be built, say so plainly.
- **Close cleanly:** End with one line inviting corrections, followed by **ONE open question** addressing the biggest unsettled requirement whose answer would most change what gets built.

## The Conversation & Socratic Probing

Each subsequent message should advance understanding through disciplined dialogue:

- **One question per message.** A single sentence with no sprawling list of example answers hanging off it.
- **Get them describing.** Open questions come first. Their own words carry intent that pre-packaged options cannot. Offer a short menu only when they are stuck. When they say "what do you think?", propose something concrete with rationale.
- **How it gets made.** Every project rests on choices about platform, programming language, tools, and libraries. Probe early on which choices the user wants to own vs. which they want to delegate to sensible defaults:
  - Strong views or constraints: talk them through.
  - Relying on you: provide sensible defaults in plain words.
  - Existing work: build on what the project already uses.
  - Any choice you make goes into the design as your call, never as something the user mandated.
- **Ground to cover:**
  - Intent, purpose, and what makes it special
  - Success criteria and why now
  - Goals, non-goals, and anti-goals (what would make this a failure even if it technically works)
  - Prior art: what they've seen elsewhere, loved or hated
  - Current state and technical constraints
- **Propose 2-3 approaches.** Once you understand what they want, lay out approaches in a message of their own before writing the spec:
  - Ground each option in what the project actually does and state tradeoffs.
  - Lead with your recommended option and explain why.
  - Ask which direction they want to pursue.

## Size the Work

Once requirements are clear and an approach is chosen, size the work in plain words:

| Size | The Design Doc |
|---|---|
| A small change | A short design doc: intent, why, constraints, and approach in a few concise lines. Goes straight to user review without builder check. |
| A project | Full written design doc (see structure below), validated with the builder check before user review. |

Both short and full designs must include the **Approaches** considered, their tradeoffs, which one was chosen, and why.
If the work grows mid-task, stop, say so, and step up a size.

## The Written Design

Save the validated design to `docs/specs/YYYY-MM-DD-<topic>-design.md` (or user's preferred path):
- Intent and the why
- Goals, non-goals, anti-goals
- Constraints (version floors, platform limits, dependencies)
- Approaches considered, tradeoffs, and rationale for selected approach
- Architecture, components, and data flow
- Error handling and testing approach
- What was decided vs. what is left to the builder

## Builder Check (For Projects)

Before presenting the spec for final user approval, run an internal builder perspective check:
1. Read the document as a talented engineer who must plan and build it without talking to the author.
2. Identify places where a builder would have to guess and a wrong guess would matter.
3. Sort open items into three categories:
   - **Already Answered:** Answered by conversation or project context — add directly to the document.
   - **Minor (Author's Call):** Sensible builder could settle without changing what gets built — settle it yourself and mark in the document as your call.
   - **Theirs:** Only the user can answer, and the answer changes what gets built.
4. If any items fall into "Theirs", bring them to the user in a single, focused round of questions (most important first). Update the document with their answers and list your calls.

## Spec Self-Review

After writing the spec (and completing the builder check if a project), check it yourself:
1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections, or vague requirements? Fix them.
2. **Internal consistency:** Do any sections contradict each other? Does the architecture match feature descriptions?
3. **Scope check:** Is this focused enough for a single implementation plan, or does it need decomposition?
4. **Ambiguity check:** Could any requirement be interpreted two different ways? Pick one and make it explicit.

Fix issues inline before proceeding.

## User Review Gate

Ask the user for review and approval:

> "Spec written and committed to `<path>`. Please review it and let me know if you want to make any changes before we start planning the implementation."

Wait for approval. If they request changes, update the spec and re-verify. Only proceed once approved.

## Transition to Planning

The terminal state is invoking the **planner** skill. Do NOT invoke any other skill or step into implementation directly:

> "Design approved. Switching to planning — I'll decompose this into executable tasks next."

Load: `skills/planner`

## Red Flags

| Thought | Reality |
|---|---|
| "I'll offer a menu of what they might want" | Options steer. Ask them to describe it first in their own words. |
| "I'll fill in sensible defaults silently" | Say them out loud. A default they never heard is one they couldn't reject. |
| "I've answered their questions, so I'll write the doc" | Lay out the approaches first, in a message of their own with tradeoffs and recommendations. |
| "I should explain the process first" | Ask your question. The process shows itself. |
| "They said 'sounds good' to the idea" | Approval covers what you showed them. A design doc you haven't written isn't approved. |
| "The request looks small, so I can skip the design doc" | Even small changes get a short design doc approved before planning or coding. |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The user gave a detailed prompt, so requirements are already clear" | Prompts often specify solutions, not intent or constraints. Read context first, echo understanding, and confirm. |
| "I already know what files to edit, so I can start coding" | Knowing files is not having an approved design. Code without an approved design violates the hard gate. |
| "I'll ask 5 questions at once to save round-trips" | Overwhelms the user and leads to shallow answers. Ask one focused question at a time. |
| "I'll assume standard libraries without asking" | Probe technical ownership early. The user may have strict constraints on dependencies or stack. |
| "I don't need a builder check because my spec is thorough" | Authors miss their own blind spots. Reading from a builder's perspective catches ambiguities before planning. |
