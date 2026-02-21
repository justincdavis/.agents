---
name: list-plans
description: List and summarize recent plans Claude has been working on across all projects
disable-model-invocation: false
user-invocable: true
context: fork
model: haiku
allowed-tools: Bash
argument-hint: "[timeframe: 1h, 6h, 24h, 3d, 1w] (default: 24h)"
---

# List Recent Claude Plans

List and summarize recent Claude sessions across all projects.

## Instructions

1. Run the listing script with the user's timeframe argument:
   ```
   bash {{SKILLS_DIR}}/list-plans/scripts/list-plans.sh $ARGUMENTS
   ```
   If `$ARGUMENTS` is empty, the script defaults to `24h`.

2. Present the output cleanly to the user, preserving the section structure.

3. After the output, add a brief **Observations** section highlighting:
   - Which projects had the most activity
   - How many sessions used plan mode
   - Any notable patterns (e.g., many short sessions, long-running sessions, branches with heavy activity)

This skill is **read-only** — do not modify any files.
