#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "Dev Tools"

check_tool curl "curl --version | head -1" "curl"
check_tool wget "wget --version | head -1" "wget"
check_tool jq "jq --version" "jq"
check_simple tmux "tmux"
check_simple screen "screen"
