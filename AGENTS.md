# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What This Repo Is

A collection of reusable skills and plugin configurations for `.claude`, `.cursor`, and `.agents` tooling. It provides two mechanisms for extending AI coding assistants: **skills** (first-party, in `skills/`) and **plugins** (third-party, managed via `configs/plugins/`).

## Key Commands

```bash
# Install skills
./install.sh --skills claude            # -> ~/.claude/skills/
./install.sh --skills cursor --local    # -> ./.cursor/skills/ (current directory)

# Install third-party plugins
./install.sh --plugins claude            # via Claude Code plugin marketplace
./install.sh --plugins cursor agents     # symlink into both targets
./install.sh --plugins agents --only superpowers  # single plugin only

# Install both
./install.sh --all claude
```

There are no build, lint, or test commands. The repo is pure bash scripts and markdown.

## Architecture

### Skills (`skills/`)

Each skill is a directory containing a `SKILL.md` (frontmatter + instructions) and optional `scripts/` directory. Skills use `{{SKILLS_DIR}}` as a placeholder for the resolved install path -- `install.sh` replaces this token at install time based on the target and `--local` flag.

Skill frontmatter fields: `name`, `description`, `user-invocable`, `context`, `model`, `allowed-tools`, `argument-hint`.

### Plugins (`configs/plugins/`)

Third-party plugins are defined as JSON configs. `install.sh --plugins` reads these, clones repos into `plugins/repos/` (gitignored), and either installs via Claude Code marketplace or symlinks into the target directory. The `enabled` field controls whether a plugin is installed by default or only when explicitly named with `--only`.

### Install flow

`install.sh` is a unified script with `--skills`, `--plugins`, and `--all` modes. Skills mode stages to a temp directory, runs `sed` to replace `{{SKILLS_DIR}}` in all `.md` and `.sh` files, then copies into the destination. This staging avoids issues when source and destination overlap (e.g., installing to `~/.agents/skills/` from within `~/.agents/`).

Plugins mode requires `python3` (for JSON parsing) and `git`. For Claude target, it uses `claude plugin marketplace add` and `claude plugin install`. For cursor/agents targets, it shallow-clones repos and creates symlinks.

## Conventions

- Skills are self-contained directories under `skills/` -- each must have a `SKILL.md`.
- Helper scripts go in `scripts/` within the skill directory, and can also use `{{SKILLS_DIR}}`.
- Plugin configs go in `configs/plugins/` as individual JSON files.
- The `plugins/` directory (where repos are cloned) is gitignored.
