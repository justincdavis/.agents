#!/usr/bin/env bash
# Shared helpers for read-env scripts. Source this, don't execute it.

section() {
    echo ""
    echo "=== $1 ==="
}

check_tool() {
    local cmd="$1"
    local version_cmd="$2"
    local label="$3"
    if command -v "$cmd" &>/dev/null; then
        local loc
        loc=$(command -v "$cmd")
        local ver
        ver=$(eval "$version_cmd" 2>/dev/null | head -1) || true
        [[ -z "$ver" ]] && ver="unknown version"
        echo "  $label: $ver ($loc)"
    fi
}

check_simple() {
    local cmd="$1"
    local label="$2"
    if command -v "$cmd" &>/dev/null; then
        local loc
        loc=$(command -v "$cmd")
        echo "  $label: $loc"
    fi
}
