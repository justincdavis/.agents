---
name: env-info
description: Gather comprehensive environment information including system details, Python version, compilers, runtimes, build tools, and package managers. Use when you need to understand what tools are available in the current environment.
disable-model-invocation: false
user-invocable: true
context: fork
model: haiku
allowed-tools: Bash
---

# env-info

Gather and present comprehensive environment information.

## Instructions

1. Run the detection script:
   ```
   bash ~/.claude/skills/env-info/scripts/env-info.sh
   ```
2. Present the output cleanly to the user, preserving the section structure.
3. After the output, add a brief **Summary** section highlighting:
   - Python version and location
   - Available compilers
   - Notable build tools
   - Platform notes (e.g., WSL, Docker, native)

This skill is **read-only** — do not modify any files or install anything.
