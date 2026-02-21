#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"

# --- Usage ---

usage() {
    cat <<EOF
Usage: install.sh <target> [--local]

Installs skills to the specified target directory.

Targets:
  claude    Install to ~/.claude/skills/
  cursor    Install to ~/.cursor/skills/
  agents    Install to ~/.agents/skills/

Options:
  --local   Install to ./<target>/skills/ in the current directory
            instead of the home directory.

Examples:
  install.sh claude            # -> ~/.claude/skills/
  install.sh cursor --local    # -> ./.cursor/skills/
EOF
    exit 1
}

# --- Parse args ---

TARGET=""
LOCAL=false

[[ $# -eq 0 ]] && usage

for arg in "$@"; do
    case "$arg" in
        claude|cursor|agents) TARGET="$arg" ;;
        --local) LOCAL=true ;;
        -h|--help) usage ;;
        *) echo "ERROR: Unknown argument: $arg"; usage ;;
    esac
done

[[ -z "$TARGET" ]] && { echo "ERROR: No target specified."; usage; }

# --- Determine destination ---

if $LOCAL; then
    DEST_BASE="./.$TARGET"
else
    DEST_BASE="$HOME/.$TARGET"
fi

DEST_SKILLS="$DEST_BASE/skills"

echo "Installing skills to: $DEST_SKILLS"

# --- Resolve template path ---

if $LOCAL; then
    SKILLS_PATH="./.$TARGET/skills"
else
    SKILLS_PATH="~/.$TARGET/skills"
fi

# --- Stage to temp dir (avoids issues when source and dest overlap) ---

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

cp -r "$SKILLS_SRC"/* "$STAGING"/

# Replace {{SKILLS_DIR}} in staged files
find "$STAGING" -type f \( -name '*.md' -o -name '*.sh' \) \
    -exec sed -i "s|{{SKILLS_DIR}}|$SKILLS_PATH|g" {} +

# --- Install from staging ---

mkdir -p "$DEST_SKILLS"

for skill_dir in "$STAGING"/*/; do
    skill_name="$(basename "$skill_dir")"
    dest_skill="$DEST_SKILLS/$skill_name"

    rm -rf "$dest_skill"
    cp -r "$skill_dir" "$dest_skill"

    echo "  Installed: $skill_name"
done

echo ""
echo "Done. Installed $(ls -1d "$STAGING"/*/ 2>/dev/null | wc -l) skill(s) to $DEST_SKILLS"
