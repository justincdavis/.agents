#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "System Info"

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    echo "  OS: ${PRETTY_NAME:-${NAME:-unknown}}"
fi

echo "  Kernel: $(uname -sr)"
echo "  Architecture: $(uname -m)"
echo "  Hostname: $(hostname)"

# Environment detection
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "  Environment: WSL"
elif [[ -f /.dockerenv ]]; then
    echo "  Environment: Docker container"
elif grep -q 'container=' /proc/1/environ 2>/dev/null; then
    echo "  Environment: Container (generic)"
else
    echo "  Environment: Native"
fi

section "Shell"

echo "  Current shell: ${SHELL:-unknown}"
check_tool bash "bash --version | head -1" "Bash"
check_tool zsh "zsh --version" "Zsh"

section "Hardware"

if command -v lscpu &>/dev/null; then
    cpu_model=$(lscpu | grep -m1 'Model name' | sed 's/.*:\s*//')
    cpu_cores=$(nproc 2>/dev/null || lscpu | grep -m1 '^CPU(s):' | sed 's/.*:\s*//')
    echo "  CPU: $cpu_model ($cpu_cores cores)"
fi

if command -v free &>/dev/null; then
    total_ram=$(free -h | awk '/^Mem:/{print $2}')
    echo "  RAM: $total_ram total"
fi

if command -v nvidia-smi &>/dev/null; then
    gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "detected but query failed")
    echo "  NVIDIA GPU: $gpu_info"
fi

if command -v rocm-smi &>/dev/null; then
    echo "  AMD ROCm: $(rocm-smi --showproductname 2>/dev/null | head -3 || echo "detected")"
fi
