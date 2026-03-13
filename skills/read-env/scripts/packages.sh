#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "Package Managers (System)"

check_simple apt "apt"
check_simple dnf "dnf"
check_simple yum "yum"
check_simple pacman "pacman"
check_simple brew "brew"
check_simple snap "snap"
check_simple flatpak "flatpak"

section "Package Managers (Language)"

check_tool pip "pip --version" "pip"
check_tool pip3 "pip3 --version" "pip3"
check_tool uv "uv --version" "uv"
check_tool npm "npm --version" "npm"
check_tool yarn "yarn --version" "yarn"
check_tool pnpm "pnpm --version" "pnpm"
check_tool cargo "cargo --version" "cargo"
check_tool gem "gem --version" "gem"
