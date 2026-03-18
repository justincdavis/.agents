# .agents

Collection of reusable skills and plugins for `.claude`, `.cursor`, and `.agents` tooling.

## Install

```bash
./install.sh [--skills|--plugins|--all] <target> [target...] [options]
```

**Targets:** `claude`, `cursor`, `agents`

| Command | Effect |
|---|---|
| `./install.sh --skills claude` | Skills to `~/.claude/skills/` |
| `./install.sh --skills claude cursor` | Skills to both targets |
| `./install.sh --skills claude --local` | Skills to `./.claude/skills/` (current directory) |
| `./install.sh --plugins claude` | Plugins via Claude Code marketplace |
| `./install.sh --plugins cursor agents` | Plugins to both targets |
| `./install.sh --plugins agents --only superpowers` | Single plugin only |
| `./install.sh --all claude` | Skills + plugins to claude |

## Skills

<details>
<summary><strong>read-env</strong> — Gather environment info by category</summary>

Detects system details, compilers, Python, CUDA, runtimes, build tools, packages, containers, VCS, and dev tools. Run with specific modules or no arguments for everything.

```
/read-env                          # all modules
/read-env system cuda              # just system + CUDA
/read-env compilers python         # just compilers + Python
```

Modules: `system`, `compilers`, `python`, `cuda`, `runtimes`, `build-tools`, `packages`, `containers`, `vcs`, `dev-tools`
</details>

<details>
<summary><strong>list-plans</strong> — List recent AI coding sessions</summary>

Scans Claude Code, Cursor, and Agents data directories for recent plan files. Shows session summaries with project, branch, and timeframe info.

```
/list-plans          # last 24h (default)
/list-plans 3d       # last 3 days
/list-plans 1w       # last week
```
</details>

<details>
<summary><strong>create-skill</strong> — Create a new skill from scratch</summary>

Interactive guide for creating new skills. Brainstorms purpose, name, invocation type, and tools needed, then generates the skill directory with proper frontmatter and optional helper scripts.

```
/create-skill
```
</details>

<details>
<summary><strong>create-skill-from-chat</strong> — Extract a skill from the current conversation</summary>

Analyzes the current conversation to identify a repeatable process, then extracts it into a properly structured skill with supporting files (templates, scripts, references). Useful when you've just worked through something worth reusing.

```
/create-skill-from-chat
```
</details>

<details>
<summary><strong>make-data-viewer</strong> — Build an interactive data viewer</summary>

Builds a single-file Flask + Plotly.js browser-based viewer for exploring datasets. Handles time-series, traces, scientific data with filtering, overlaying, and distance comparison. Starts from a bundled template and customizes for your data format.

```
/make-data-viewer
```
</details>

## Plugins

<details>
<summary><strong>superpowers</strong> — Structured workflows for planning, debugging, TDD, and code review</summary>

Adds skills for brainstorming, writing/executing plans, test-driven development, systematic debugging, code review, git worktrees, and parallel agent dispatch. Enforces disciplined development workflows.

[obra/superpowers](https://github.com/obra/superpowers)
</details>

<details>
<summary><strong>planning-with-files</strong> — Manus-style file-based planning</summary>

Creates `task_plan.md`, `findings.md`, and `progress.md` for complex multi-step tasks. Supports session recovery after `/clear` and provides a `/status` command for at-a-glance progress.

[OthmanAdi/planning-with-files](https://github.com/OthmanAdi/planning-with-files)
</details>

## Authoring

### Adding a skill

Skills are self-contained directories under `skills/`, each with a `SKILL.md` and optional `scripts/`.

```
skills/
  my-skill/
    SKILL.md              # Skill definition (uses {{SKILLS_DIR}})
    scripts/
      run.sh              # Helper scripts (can also use {{SKILLS_DIR}})
      lib.sh
```

To reference helper scripts from `SKILL.md`, use the `{{SKILLS_DIR}}` placeholder instead of hardcoding a path:

```markdown
1. Run the script:
   ```
   bash {{SKILLS_DIR}}/my-skill/scripts/run.sh
   ```
```

At install time, `install.sh` replaces `{{SKILLS_DIR}}` with the resolved skills directory based on the target and `--local` flag:

| Install command | `{{SKILLS_DIR}}` becomes |
|---|---|
| `./install.sh --skills claude` | `~/.claude/skills` |
| `./install.sh --skills cursor --local` | `./.cursor/skills` |

This applies to all `.md` and `.sh` files in the skill directory.

### Adding a plugin

Create a JSON file in `configs/plugins/`:

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
