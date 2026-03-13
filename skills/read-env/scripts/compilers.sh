#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "Compilers"

check_tool gcc "gcc --version | head -1" "gcc"
check_tool g++ "g++ --version | head -1" "g++"
check_tool clang "clang --version | head -1" "clang"
check_tool clang++ "clang++ --version | head -1" "clang++"
check_tool rustc "rustc --version" "rustc"
check_tool go "go version" "go"
check_tool javac "javac -version 2>&1" "javac"
