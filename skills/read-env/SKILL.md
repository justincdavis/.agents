---
name: read-env
description: Gather environment information by category. Run with arguments (e.g., system, cuda, python, compilers) to get specific info, or with no arguments for everything.
disable-model-invocation: false
user-invocable: true
context: fork
model: haiku
allowed-tools: Bash
argument-hint: "[system|compilers|python|cuda|runtimes|build-tools|packages|containers|vcs|dev-tools] ..."
---

# read-env

Gather and present environment information by category.

## Instructions

1. Run the detection script:
   ```
   bash {{SKILLS_DIR}}/read-env/scripts/read-env.sh $ARGUMENTS
   ```
2. Present the output cleanly to the user, preserving the section structure.
3. After the output, add a brief **Summary** section highlighting the most notable findings.

This skill is **read-only** — do not modify any files or install anything.
