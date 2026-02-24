#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config/plugins"
REPOS_DIR="$SCRIPT_DIR/plugins/repos"

# --- Usage ---

usage() {
    cat <<EOF
Usage: plugins.sh <target> [target...] [--only <plugin>]

Installs third-party plugins from config/plugins/*.json.

Targets:
  claude    Install via Claude Code plugin marketplace
  cursor    Symlink into ~/.cursor/plugins/
  agents    Symlink into ~/.agents/plugins/

Options:
  --only <name>   Install only the named plugin (by JSON "name" field)

Examples:
  plugins.sh claude            # all enabled plugins -> Claude Code
  plugins.sh cursor agents     # all enabled plugins -> both targets
  plugins.sh agents --only superpowers
EOF
    exit 1
}

# --- Parse args ---

TARGETS=()
ONLY=""

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
    case "$1" in
        claude|cursor|agents) TARGETS+=("$1") ;;
        --only)
            [[ $# -lt 2 ]] && { echo "ERROR: --only requires a plugin name"; usage; }
            ONLY="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "ERROR: Unknown argument: $1"; usage ;;
    esac
    shift
done

[[ ${#TARGETS[@]} -eq 0 ]] && { echo "ERROR: No target specified."; usage; }

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

install_claude() {
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

install_symlink() {
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

    local needs_clone=false

    for target in "${TARGETS[@]}"; do
        local line
        line=$(echo "$output" | grep "^${target}|") || continue

        local type field3 field4
        IFS='|' read -r _ type field3 field4 <<< "$line"

        # Skip if target not configured for this plugin
        [[ -z "$type" ]] && continue

        if [[ "$target" == "claude" && "$type" == "marketplace" ]]; then
            install_claude "$name" "$field3" "$field4"
        elif [[ "$type" == "symlink" ]]; then
            needs_clone=true
            install_symlink "$name" "$repo" "$field3" "$target"
        fi
    done
}

# --- Main ---

main() {
    echo "Installing plugins for: ${TARGETS[*]}"

    if ! command -v python3 &>/dev/null; then
        echo "ERROR: python3 is required for JSON parsing"
        exit 1
    fi

    if ! command -v git &>/dev/null; then
        echo "ERROR: git is required"
        exit 1
    fi

    if [[ ! -d "$CONFIG_DIR" ]]; then
        echo "ERROR: No config directory at ${CONFIG_DIR}"
        exit 1
    fi

    local count=0
    for json_file in "$CONFIG_DIR"/*.json; do
        [[ -f "$json_file" ]] || continue
        process_plugin "$json_file"
        ((count++)) || true
    done

    if [[ "$count" -eq 0 ]]; then
        echo "No plugin configs found in ${CONFIG_DIR}"
        exit 1
    fi

    echo ""
    echo "Done. Processed ${count} plugin config(s)."
}

main
