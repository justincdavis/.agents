#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "Python"

if command -v python3 &>/dev/null; then
    py3_ver=$(python3 --version 2>&1)
    py3_loc=$(command -v python3)
    py3_major=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "unknown")
    echo "  Python3: $py3_ver ($py3_loc) [series: $py3_major]"
fi

if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    echo "  Active virtualenv: $VIRTUAL_ENV"
fi

if command -v python2 &>/dev/null; then
    check_tool python2 "python2 --version 2>&1" "Python2"
fi
