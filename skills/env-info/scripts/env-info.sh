#!/usr/bin/env bash
set -euo pipefail

# --- Helpers ---

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

# --- System Info ---

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

# --- Shell ---

section "Shell"

echo "  Current shell: ${SHELL:-unknown}"
check_tool bash "bash --version | head -1" "Bash"
check_tool zsh "zsh --version" "Zsh"

# --- Hardware ---

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

# --- Python ---

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

# --- Compilers ---

section "Compilers"

check_tool gcc "gcc --version | head -1" "gcc"
check_tool g++ "g++ --version | head -1" "g++"
check_tool clang "clang --version | head -1" "clang"
check_tool clang++ "clang++ --version | head -1" "clang++"
check_tool rustc "rustc --version" "rustc"
check_tool go "go version" "go"
check_tool javac "javac -version 2>&1" "javac"

# --- Build Tools ---

section "Build Tools"

check_tool make "make --version | head -1" "make"
check_tool cmake "cmake --version | head -1" "cmake"
check_tool ninja "ninja --version" "ninja"
check_tool meson "meson --version" "meson"
check_tool autoconf "autoconf --version | head -1" "autoconf"
check_tool automake "automake --version | head -1" "automake"
check_tool libtool "libtool --version | head -1" "libtool"
check_simple pkg-config "pkg-config"

# --- Language Runtimes ---

section "Language Runtimes"

check_tool node "node --version" "Node.js"
check_tool ruby "ruby --version" "Ruby"
check_tool perl "perl -v | grep version | head -1" "Perl"
check_tool java "java -version 2>&1 | head -1" "Java"
check_tool php "php --version | head -1" "PHP"
check_tool lua "lua -v 2>&1" "Lua"

# --- Package Managers ---

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

# --- Container & Virtualization ---

section "Container & Virtualization"

check_tool docker "docker --version" "docker"
check_tool podman "podman --version" "podman"
check_tool kubectl "kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -1" "kubectl"
check_tool helm "helm version --short 2>/dev/null" "helm"

# --- Version Control ---

section "Version Control"

check_tool git "git --version" "git"
check_tool hg "hg --version | head -1" "hg"
check_tool svn "svn --version | head -1" "svn"

# --- Dev Tools ---

section "Dev Tools"

check_tool curl "curl --version | head -1" "curl"
check_tool wget "wget --version | head -1" "wget"
check_tool jq "jq --version" "jq"
check_simple tmux "tmux"
check_simple screen "screen"

echo ""
echo "=== Done ==="
