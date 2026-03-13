#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "Version Control"

check_tool git "git --version" "git"
check_tool hg "hg --version | head -1" "hg"
check_tool svn "svn --version | head -1" "svn"
