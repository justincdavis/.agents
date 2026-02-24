# .agents

Collection of reusable skills for `.claude`, `.cursor`, and `.agents` tooling.

## Skills

### env-info

Gathers comprehensive environment information: system details, Python version, compilers, runtimes, build tools, and package managers. Read-only.

```
/env-info
```

### list-plans

Lists and summarizes recent Claude sessions across all projects. Accepts a timeframe argument. Read-only.

```
/list-plans 3d
```

## Install

```bash
./install.sh <target> [--local]
```

**Targets:** `claude`, `cursor`, `agents`

| Command | Installs to |
|---|---|
| `./install.sh claude` | `~/.claude/skills/` |
| `./install.sh cursor` | `~/.cursor/skills/` |
| `./install.sh agents` | `~/.agents/skills/` |
| `./install.sh claude --local` | `./.claude/skills/` (current directory) |

## Authoring skills with `{{SKILLS_DIR}}`

Skills often bundle helper scripts alongside the `SKILL.md`. To reference these scripts, use the `{{SKILLS_DIR}}` placeholder instead of hardcoding a path:

```markdown
1. Run the script:
   ```
   bash {{SKILLS_DIR}}/my-skill/scripts/run.sh
   ```
```

At install time, `install.sh` replaces `{{SKILLS_DIR}}` with the resolved skills directory based on the target and `--local` flag. For example:

| Install command | `{{SKILLS_DIR}}` becomes |
|---|---|
| `./install.sh claude` | `~/.claude/skills` |
| `./install.sh cursor --local` | `./.cursor/skills` |

This applies to all `.md` and `.sh` files in the skill directory, so you can use `{{SKILLS_DIR}}` in helper scripts too.

### Skill directory structure

```
skills/
  my-skill/
    SKILL.md              # Skill definition (uses {{SKILLS_DIR}})
    scripts/
      run.sh              # Helper scripts (can also use {{SKILLS_DIR}})
      lib.sh
```
