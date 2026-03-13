#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "Build Tools"

check_tool make "make --version | head -1" "make"
check_tool cmake "cmake --version | head -1" "cmake"
check_tool ninja "ninja --version" "ninja"
check_tool meson "meson --version" "meson"
check_tool autoconf "autoconf --version | head -1" "autoconf"
check_tool automake "automake --version | head -1" "automake"
check_tool libtool "libtool --version | head -1" "libtool"
check_simple pkg-config "pkg-config"
