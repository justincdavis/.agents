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

### create-skill

Guides through creating a new skill for Claude Code, Cursor, or .agents tooling. Brainstorms purpose and requirements with you, then generates the skill directory with proper frontmatter, `{{SKILLS_DIR}}` usage, and optional helper scripts.

```
/create-skill
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

## Plugins

Third-party plugins are managed by `plugins.sh`, driven by JSON configs in `config/plugins/`.

```bash
./plugins.sh <target> [target...] [--only <plugin>]
```

**Targets:** `claude`, `cursor`, `agents`

| Command | Effect |
|---|---|
| `./plugins.sh claude` | Install via Claude Code plugin marketplace |
| `./plugins.sh cursor` | Symlink into `~/.cursor/plugins/` |
| `./plugins.sh agents` | Symlink into `~/.agents/plugins/` |
| `./plugins.sh cursor agents` | Both targets at once |
| `./plugins.sh agents --only superpowers` | Install a specific plugin only |

### Adding a new plugin

Create a JSON file in `config/plugins/`:

```json
{
  "name": "my-plugin",
  "repo": "https://github.com/owner/repo.git",
  "enabled": true,
  "targets": {
    "claude": {
      "marketplace": "owner/repo-marketplace",
      "plugin": "my-plugin@repo-marketplace"
    },
    "cursor": {
      "type": "symlink",
      "path": "."
    },
    "agents": {
      "type": "symlink",
      "path": "."
    }
  }
}
```

- `enabled`: set to `false` to skip unless explicitly named with `--only`
- `targets`: omit a key if the plugin doesn't support that target
- `path`: subdirectory within the cloned repo to symlink (`.` for root)

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
