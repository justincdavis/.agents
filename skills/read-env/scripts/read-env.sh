#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# All available modules (order matters for full output)
ALL_MODULES=(system compilers python cuda runtimes build-tools packages containers vcs dev-tools)

usage() {
    echo "Usage: read-env.sh [module ...]"
    echo ""
    echo "Available modules: ${ALL_MODULES[*]}"
    echo ""
    echo "Run with no arguments to execute all modules."
    exit 1
}

run_module() {
    local mod="$1"
    local script="$SCRIPT_DIR/${mod}.sh"
    if [[ ! -f "$script" ]]; then
        echo "ERROR: Unknown module '$mod'" >&2
        echo "Available modules: ${ALL_MODULES[*]}" >&2
        exit 1
    fi
    bash "$script"
}

# Parse arguments
modules=("$@")

# No arguments = run all
if [[ ${#modules[@]} -eq 0 ]]; then
    modules=("${ALL_MODULES[@]}")
fi

# Handle help flag
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage ;;
    esac
done

for mod in "${modules[@]}"; do
    run_module "$mod"
done

echo ""
echo "=== Done ==="
