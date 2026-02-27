---
name: create-skill
description: Use when creating a new skill for Claude Code, Cursor, or .agents tooling - guides through brainstorming purpose, writing frontmatter, setting up directory structure, and choosing install location
disable-model-invocation: false
user-invocable: true
context: fork
model: sonnet
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Create Skill

Guide for creating new skills. Brainstorm with the user, then generate a well-structured skill directory with proper frontmatter and optional helper scripts.

## Process

```dot
digraph create_skill {
    "Brainstorm" [shape=box];
    "Decide structure" [shape=diamond];
    "Write SKILL.md" [shape=box];
    "Create scripts/?" [shape=diamond];
    "Write helper scripts" [shape=box];
    "Verify" [shape=box];

    "Brainstorm" -> "Decide structure";
    "Decide structure" -> "Write SKILL.md";
    "Write SKILL.md" -> "Create scripts/?";
    "Create scripts/?" -> "Write helper scripts" [label="yes"];
    "Create scripts/?" -> "Verify" [label="no"];
    "Write helper scripts" -> "Verify";
}
```

## Step 1: Brainstorm

Ask the user these questions **one at a time** using `AskUserQuestion`. Skip any the user already answered.

### Required Questions

1. **Purpose** — "What should this skill do?" (open-ended)
2. **Name** — Suggest a kebab-case name based on their answer. Verb-first, active voice (`create-widget` not `widget-creation`).
3. **Invocation type** — "Should this be user-invocable (called with `/skill-name`) or model-invocable (triggered automatically by context)?"
4. **Tools needed** — "What tools does this skill need?" Common sets:
   - Read-only: `Bash, Read, Glob, Grep`
   - File creation: `Bash, Read, Write, Edit, Glob, Grep`
   - Interactive: add `AskUserQuestion`
   - Full: `Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Task`

### Situational Questions

Ask these only when relevant:

- **Install location** — "Should this skill be installed globally or locally?"
  - **Global** (`~/.claude/skills/`): Available in all projects. Good for general-purpose skills.
  - **Local** (`./.claude/skills/` in current project): Project-specific. Good for skills tied to a particular codebase.
- **Helper scripts** — "Does this need bash helper scripts, or is the SKILL.md body sufficient?" Ask when the skill involves running commands or complex logic.
- **Model** — Default to `haiku` for simple/scripted skills, `sonnet` for skills needing reasoning. Only ask if unclear.
- **Arguments** — "Does this skill take arguments?" If yes, ask for the `argument-hint` format. Only relevant for user-invocable skills.
- **Context** — Default to `fork` (isolated). Use `conversation` only if the skill needs access to the current conversation context.

## Step 2: Directory Structure

Based on the user's install location choice, create the skill directory:

- **Global:** `~/.claude/skills/{name}/`
- **Local:** `./.claude/skills/{name}/`

```
{name}/
  SKILL.md              # Required
  scripts/              # Optional
    {name}.sh           # Helper script(s)
```

Skills must be **self-contained directories**. Everything the skill needs lives inside its directory.

## Step 3: Write SKILL.md

### Frontmatter Reference

```yaml
---
name: skill-name                    # kebab-case, letters/numbers/hyphens only
description: Use when [triggers]... # Start with "Use when", describe WHEN not WHAT
disable-model-invocation: false     # true = only user can invoke
user-invocable: true                # true = shows as /skill-name command
context: fork                       # fork (isolated) or conversation (in-context)
model: haiku                        # haiku | sonnet | opus
allowed-tools: Bash, Read           # comma-separated tool list
argument-hint: "[arg] (default: x)" # optional, for user-invocable skills
---
```

### Frontmatter Rules

- **`description`**: Describe WHEN to use, not WHAT it does. Start with "Use when...". Write in third person. Never summarize the workflow — agents may shortcut to the description and skip the body.
- **`name`**: Letters, numbers, hyphens only. No special characters.
- **`model`**: `haiku` for scripted/simple skills. `sonnet` for reasoning-heavy skills. `opus` rarely needed.
- **`allowed-tools`**: Only list tools the skill actually uses.

### Body Structure

```markdown
# Skill Title

One-line summary of what this does.

## Instructions

Numbered steps the agent follows.

## [Additional Sections as Needed]

Keep concise. Agents have limited context.
```

### Referencing Scripts

If the skill has helper scripts, reference them using a path relative to the skill's install location. Use the resolved absolute path based on where the skill was created (global or local).

### Writing Guidelines

- **Be concise.** Target <200 words for frequently-loaded skills, <500 words otherwise.
- **One good example > many mediocre ones.** Don't repeat patterns across languages.
- **Flowcharts only for non-obvious decisions.** Use numbered lists for linear steps.
- **No narrative storytelling.** Skills are references, not journals.

## Step 4: Helper Scripts

If the skill needs scripts, create them in `scripts/` inside the skill directory.

### Script Conventions

```bash
#!/usr/bin/env bash
set -euo pipefail

# Script logic here
```

- Start with `set -euo pipefail`
- Use embedded `python3` for complex data processing (JSON parsing, etc.)
- Keep scripts self-contained — don't depend on external tools beyond standard unix + python3

## Step 5: Verify

After generating the skill files:

1. **Check frontmatter** — all required fields present, description starts with "Use when"
2. **Check script references** — paths correctly resolve based on install location
3. **Check structure** — SKILL.md exists, scripts/ has executable `.sh` files if needed
4. **Read it back** — read the generated files and confirm they look correct

## Quick Reference

| Decision | Default | Override When |
|----------|---------|---------------|
| Model | `haiku` | Skill needs reasoning → `sonnet` |
| Context | `fork` | Needs conversation history → `conversation` |
| User-invocable | Ask user | — |
| Scripts dir | Skip | Skill runs bash commands |
| argument-hint | Skip | User-invocable + takes args |
