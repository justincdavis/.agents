#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
CONFIG_DIR="$SCRIPT_DIR/configs/plugins"
REPOS_DIR="$SCRIPT_DIR/plugins/repos"

# --- Usage ---

usage() {
    cat <<EOF
Usage: install.sh [--skills|--plugins|--all] <target> [target...] [options]
       install.sh --statusline [claude]

Modes (pick one):
  --skills    Install first-party skills from skills/
  --plugins   Install third-party plugins from configs/plugins/
  --all       Install both skills, plugins, and statusline (claude)

Targets:
  claude      ~/.claude/{skills,plugins}/
  cursor      ~/.cursor/{skills,plugins}/
  agents      ~/.agents/{skills,plugins}/

Options:
  --local         Install skills to ./<target>/skills/ instead of home directory
  --only <name>   Install only the named plugin (plugins only)
  --statusline    Install cship statusline (claude only, can be standalone)
  -h, --help      Show this help

Examples:
  install.sh --skills claude              # skills -> ~/.claude/skills/
  install.sh --skills claude cursor       # skills -> both targets
  install.sh --skills claude --local      # skills -> ./.claude/skills/
  install.sh --plugins claude             # plugins via Claude Code marketplace
  install.sh --plugins cursor agents      # plugins -> both targets
  install.sh --plugins agents --only superpowers
  install.sh --all claude                 # skills + plugins + statusline -> claude
  install.sh --statusline                 # statusline only -> claude
  install.sh --skills claude --statusline # skills + statusline -> claude
EOF
    exit 1
}

# --- Parse args ---

MODE=""
TARGETS=()
LOCAL=false
ONLY=""
STATUSLINE=false

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skills)  MODE="skills" ;;
        --plugins) MODE="plugins" ;;
        --all)     MODE="all" ;;
        claude|cursor|agents) TARGETS+=("$1") ;;
        --local)   LOCAL=true ;;
        --statusline) STATUSLINE=true ;;
        --only)
            [[ $# -lt 2 ]] && { echo "ERROR: --only requires a plugin name"; usage; }
            ONLY="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "ERROR: Unknown argument: $1"; usage ;;
    esac
    shift
done

# --- Validate ---

# --statusline can run standalone (no mode required), default target to claude
if [[ -z "$MODE" ]] && $STATUSLINE; then
    [[ ${#TARGETS[@]} -eq 0 ]] && TARGETS+=("claude")
elif [[ -z "$MODE" ]]; then
    echo "ERROR: No mode specified (use --skills, --plugins, or --all)."; usage
fi

[[ ${#TARGETS[@]} -eq 0 ]] && { echo "ERROR: No target specified."; usage; }

if [[ "$MODE" == "plugins" ]] && $LOCAL; then
    echo "WARNING: --local is ignored for plugins"
fi

if [[ "$MODE" == "skills" ]] && [[ -n "$ONLY" ]]; then
    echo "WARNING: --only is ignored for skills"
fi

# --all with claude target implies --statusline
if [[ "$MODE" == "all" ]]; then
    for t in "${TARGETS[@]}"; do
        [[ "$t" == "claude" ]] && STATUSLINE=true
    done
fi

if $STATUSLINE; then
    has_claude=false
    for t in "${TARGETS[@]}"; do
        [[ "$t" == "claude" ]] && has_claude=true
    done
    if ! $has_claude; then
        echo "WARNING: --statusline only applies to the claude target, ignoring"
        STATUSLINE=false
    fi
fi

# =============================================================================
# Skills
# =============================================================================

install_skills_to_target() {
    local target="$1"

    if $LOCAL; then
        local dest_base="./.$target"
        local skills_path="./.$target/skills"
    else
        local dest_base="$HOME/.$target"
        local skills_path="~/.$target/skills"
    fi

    local dest_skills="$dest_base/skills"
    echo "Installing skills to: $dest_skills"

    local staging
    staging=$(mktemp -d)

    cp -r "$SKILLS_SRC"/* "$staging"/

    # Replace {{SKILLS_DIR}} in staged files
    find "$staging" -type f \( -name '*.md' -o -name '*.sh' \) \
        -exec sed -i "s|{{SKILLS_DIR}}|$skills_path|g" {} +

    mkdir -p "$dest_skills"

    for skill_dir in "$staging"/*/; do
        local skill_name
        skill_name="$(basename "$skill_dir")"
        rm -rf "$dest_skills/$skill_name"
        cp -r "$skill_dir" "$dest_skills/$skill_name"
        echo "  Installed: $skill_name"
    done

    local count
    count=$(ls -1d "$staging"/*/ 2>/dev/null | wc -l)
    echo "Done. Installed ${count} skill(s) to $dest_skills"
    echo ""

    rm -rf "$staging"
}

# =============================================================================
# Plugins
# =============================================================================

# --- JSON reader (python3) ---

read_config() {
    local json_file="$1"
    python3 - "$json_file" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    c = json.load(f)

print(c.get("name", ""))
print(c.get("repo", ""))
print("true" if c.get("enabled", True) else "false")

targets = c.get("targets", {})
for t in ("claude", "cursor", "agents"):
    tc = targets.get(t)
    if tc is None:
        print(f"{t}||")
    elif "marketplace" in tc:
        mp = tc["marketplace"]
        pl = tc["plugin"]
        print(f"{t}|marketplace|{mp}|{pl}")
    else:
        ty = tc.get("type", "symlink")
        pa = tc.get("path", ".")
        print(f"{t}|{ty}|{pa}")
PYEOF
}

# --- Clone ---

clone_repo() {
    local repo_url="$1"
    local name="$2"
    local target="${REPOS_DIR}/${name}"

    if [[ -d "${target}/.git" ]]; then
        echo "  Updating: ${name}"
        git -C "$target" pull --ff-only 2>/dev/null || {
            echo "  Pull failed, re-cloning: ${name}"
            rm -rf "$target"
            git clone --depth 1 "$repo_url" "$target"
        }
    else
        echo "  Cloning: ${name}"
        mkdir -p "$REPOS_DIR"
        git clone --depth 1 "$repo_url" "$target"
    fi
}

# --- Symlink helper ---

ensure_symlink() {
    local target="$1"
    local link="$2"

    mkdir -p "$(dirname "$link")"

    if [[ -L "$link" ]]; then
        rm "$link"
    elif [[ -e "$link" ]]; then
        echo "  Backing up: ${link} -> ${link}.bak"
        mv "$link" "${link}.bak"
    fi

    ln -s "$target" "$link"
}

# --- Install functions ---

install_claude_plugin() {
    local name="$1"
    local marketplace="$2"
    local plugin="$3"

    if ! command -v claude &>/dev/null; then
        echo "  ERROR: claude CLI not found, skipping ${name}"
        return 1
    fi

    echo "  Adding marketplace: ${marketplace}"
    claude plugin marketplace add "$marketplace" 2>&1 || echo "  (marketplace may already exist)"

    echo "  Installing: ${plugin}"
    claude plugin install "$plugin" 2>&1 || echo "  (plugin may already be installed)"

    echo "  Installed: ${name} (claude)"
}

install_symlink_plugin() {
    local name="$1"
    local repo="$2"
    local subpath="$3"
    local target_name="$4"

    local dest_base="$HOME/.${target_name}"
    if [[ ! -d "$dest_base" ]]; then
        echo "  ERROR: ${dest_base} does not exist, skipping ${name}"
        return 1
    fi

    # Clone if not already present
    clone_repo "$repo" "$name"

    # Resolve symlink source
    local src="${REPOS_DIR}/${name}"
    if [[ "$subpath" != "." && -n "$subpath" ]]; then
        src="${src}/${subpath}"
    fi

    if [[ ! -e "$src" ]]; then
        echo "  ERROR: ${src} does not exist, skipping ${name}"
        return 1
    fi

    local link="${dest_base}/plugins/${name}"
    ensure_symlink "$src" "$link"
    echo "  Installed: ${name} -> ${link} (${target_name})"
}

# --- Process a single plugin config ---

process_plugin() {
    local json_file="$1"

    local output
    output=$(read_config "$json_file") || {
        echo "  ERROR: Failed to read ${json_file}"
        return 0
    }

    local name repo enabled
    name=$(echo "$output" | sed -n '1p')
    repo=$(echo "$output" | sed -n '2p')
    enabled=$(echo "$output" | sed -n '3p')

    # Filter by --only
    if [[ -n "$ONLY" && "$name" != "$ONLY" ]]; then
        return 0
    fi

    # Skip disabled unless explicitly named
    if [[ "$enabled" != "true" && -z "$ONLY" ]]; then
        echo "  Skipped (disabled): ${name}"
        return 0
    fi

    for target in "${TARGETS[@]}"; do
        local line
        line=$(echo "$output" | grep "^${target}|") || continue

        local type field3 field4
        IFS='|' read -r _ type field3 field4 <<< "$line"

        # Skip if target not configured for this plugin
        [[ -z "$type" ]] && continue

        if [[ "$target" == "claude" && "$type" == "marketplace" ]]; then
            install_claude_plugin "$name" "$field3" "$field4"
        elif [[ "$type" == "symlink" ]]; then
            install_symlink_plugin "$name" "$repo" "$field3" "$target"
        fi
    done
}

install_plugins() {
    echo "Installing plugins for: ${TARGETS[*]}"

    if ! command -v python3 &>/dev/null; then
        echo "ERROR: python3 is required for JSON parsing"
        return 1
    fi

    if ! command -v git &>/dev/null; then
        echo "ERROR: git is required"
        return 1
    fi

    if [[ ! -d "$CONFIG_DIR" ]]; then
        echo "ERROR: No config directory at ${CONFIG_DIR}"
        return 1
    fi

    local count=0
    for json_file in "$CONFIG_DIR"/*.json; do
        [[ -f "$json_file" ]] || continue
        process_plugin "$json_file"
        ((count++)) || true
    done

    if [[ "$count" -eq 0 ]]; then
        echo "No plugin configs found in ${CONFIG_DIR}"
        return 1
    fi

    echo ""
    echo "Done. Processed ${count} plugin config(s)."
}

# =============================================================================
# Main
# =============================================================================

if [[ "$MODE" == "skills" || "$MODE" == "all" ]]; then
    for target in "${TARGETS[@]}"; do
        install_skills_to_target "$target"
    done
fi

if [[ "$MODE" == "plugins" || "$MODE" == "all" ]]; then
    install_plugins
fi

# --- Install cship statusline (Claude only, requires --statusline) ---

if $STATUSLINE; then
    echo ""
    echo "Installing cship statusline..."
    bash "$SCRIPT_DIR/scripts/install_cship.sh"
fi
