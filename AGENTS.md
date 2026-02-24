# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A collection of reusable skills and plugin configurations for `.claude`, `.cursor`, and `.agents` tooling. It provides two mechanisms for extending AI coding assistants: **skills** (first-party, in `skills/`) and **plugins** (third-party, managed via `config/plugins/`).

## Key Commands

```bash
# Install skills to a target
./install.sh claude            # -> ~/.claude/skills/
./install.sh cursor --local    # -> ./.cursor/skills/ (current directory)

# Install third-party plugins
./plugins.sh claude            # via Claude Code plugin marketplace
./plugins.sh cursor agents     # symlink into both targets
./plugins.sh agents --only superpowers  # single plugin only
```

There are no build, lint, or test commands. The repo is pure bash scripts and markdown.

## Architecture

### Skills (`skills/`)

Each skill is a directory containing a `SKILL.md` (frontmatter + instructions) and optional `scripts/` directory. Skills use `{{SKILLS_DIR}}` as a placeholder for the resolved install path -- `install.sh` replaces this token at install time based on the target and `--local` flag.

Skill frontmatter fields: `name`, `description`, `user-invocable`, `context`, `model`, `allowed-tools`, `argument-hint`.

### Plugins (`config/plugins/`)

Third-party plugins are defined as JSON configs. `plugins.sh` reads these, clones repos into `plugins/repos/` (gitignored), and either installs via Claude Code marketplace or symlinks into the target directory. The `enabled` field controls whether a plugin is installed by default or only when explicitly named with `--only`.

### Install flow

`install.sh` stages skills to a temp directory, runs `sed` to replace `{{SKILLS_DIR}}` in all `.md` and `.sh` files, then copies into the destination. This staging avoids issues when source and destination overlap (e.g., installing to `~/.agents/skills/` from within `~/.agents/`).

`plugins.sh` requires `python3` (for JSON parsing) and `git`. For Claude target, it uses `claude plugin marketplace add` and `claude plugin install`. For cursor/agents targets, it shallow-clones repos and creates symlinks.

## Conventions

- Skills are self-contained directories under `skills/` -- each must have a `SKILL.md`.
- Helper scripts go in `scripts/` within the skill directory, and can also use `{{SKILLS_DIR}}`.
- Plugin configs go in `config/plugins/` as individual JSON files.
- The `plugins/` directory (where repos are cloned) is gitignored.
