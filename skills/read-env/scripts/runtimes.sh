#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "Language Runtimes"

check_tool node "node --version" "Node.js"
check_tool ruby "ruby --version" "Ruby"
check_tool perl "perl -v | grep version | head -1" "Perl"
check_tool java "java -version 2>&1 | head -1" "Java"
check_tool php "php --version | head -1" "PHP"
check_tool lua "lua -v 2>&1" "Lua"
