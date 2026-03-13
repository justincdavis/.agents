---
name: create-skill-from-chat
description: Use when the current conversation contains a repeatable process worth extracting into a reusable skill — the user says something like "make a skill from this", "extract this into a skill", "turn this chat into a skill", or "save this process"
disable-model-invocation: false
user-invocable: true
context: conversation
model: sonnet
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
---

# Create Skill from Chat

Extract a repeatable process from the current conversation into a properly structured skill with supporting files.

## Step 1: Analyze the Conversation

Before asking the user anything, silently review the current conversation and extract:

1. **The repeatable process** — what sequence of steps was followed? What was built?
2. **User questions and decisions** — what did the user ask for at each stage? What choices were made?
3. **User criticisms and refinements** — where did the user push back? What UX or design feedback was given? These become the "lessons learned" in the skill.
4. **Tech stack and tools** — what libraries, frameworks, languages, and patterns were used?
5. **Iterative changes** — how did the deliverable evolve across rounds of feedback? The final version embeds all these lessons.
6. **Supporting artifacts** — were there scripts, templates, configs, data files, or helper code created along the way?

## Step 2: Inquire

Ask the user (skip any already answered):

1. **Skill name** — propose a kebab-case name based on the process. Verb-first, active voice.
2. **Purpose** — confirm or refine: "Based on this conversation, the skill would [do X]. Is that right, or should it be scoped differently?"
3. **Invocation type** — user-invocable (`/skill-name`) or model-invocable (auto-triggered)?

## Step 3: Propose Design

Present a structured proposal for approval. Include:

- **Frontmatter** — name, description (starts with "Use when..."), model, context, tools
- **Process steps** — the extracted workflow as numbered steps
- **Lessons / UX rules** — distilled from user criticisms and iterative feedback
- **Supporting files** — propose which optional files to include (see menu below)

### Supporting Files Menu

Present these as optional (not required). Be creative — think about what would help a future agent reproduce this work without the original conversation:

| File | When to include | Example |
|------|----------------|---------|
| `scripts/template.py` (or .sh, .ts) | A code artifact was built that could be a starter template | Flask app, CLI tool, data pipeline |
| `scripts/explore.sh` | The process involved non-obvious discovery/exploration commands | Directory scanning, format detection |
| `scripts/setup.sh` | Dependencies needed installing or env setup was non-trivial | `uv pip install`, `apt install`, venv creation |
| `scripts/verify.sh` | Smoke tests or verification steps were used | API test, round-trip validation, server health check |
| `scripts/examples/` | Sample inputs, configs, or expected outputs were created | Test fixtures, example configs, seed data |
| `references/decisions.md` | Key design decisions were made with trade-offs discussed | "Why Flask over FastAPI", "Why inline HTML" |
| `references/pitfalls.md` | Non-obvious gotchas were discovered during the process | Edge cases, performance traps, format quirks |

Ask the user which (if any) supporting files they want, or let them suggest others.

## Step 4: Implement

Create a TaskCreate checklist and work through it:

### Required
- [ ] Create `~/.claude/skills/{name}/SKILL.md` with proper frontmatter and body
- [ ] Verify frontmatter: description starts with "Use when", model is appropriate, tools list is minimal

### For Each Supporting File
- [ ] Create the file in the appropriate subdirectory
- [ ] Ensure it is self-contained (no references to files outside the skill directory)
- [ ] Pre-seed with as much reusable content as possible — a future agent should be able to copy-paste and customize, not start from scratch

### Final Verification
- [ ] Read back all created files
- [ ] Confirm `~/.claude/skills` token is used for all internal path references
- [ ] Confirm SKILL.md body is under 500 words (agents have limited context)
- [ ] Tell the user the skill is ready and how to invoke it

## Writing Guidelines

These apply to ALL files in the skill:

- **Pre-seed aggressively** — templates should be 80% complete, not skeletons. Include working code, real patterns, actual CSS/HTML, concrete examples. A future agent customizes, not creates from scratch.
- **Embed lessons as rules** — user criticisms become "MUST" / "NEVER" / "always" rules in the skill body. Don't just document what happened; prescribe what to do next time.
- **Include the "why"** — for each rule or pattern, briefly note why (e.g. "debounce at 600ms — user reported lag at 300ms"). This helps future agents judge edge cases.
- **Keep SKILL.md concise** — put detailed code in supporting files, not in SKILL.md. The skill body is a process guide, not a code dump.
- **Name files by purpose** — `template.py` not `code.py`, `verify.sh` not `test.sh`, `pitfalls.md` not `notes.md`.
