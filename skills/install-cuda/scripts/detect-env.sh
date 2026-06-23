#!/usr/bin/env bash
set -euo pipefail

# Detect current OS/distro/arch for CUDA install targeting

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_SLUG="x86_64" ;;
    aarch64) ARCH_SLUG="arm64-sbsa" ;;
    *) ARCH_SLUG="$ARCH" ;;
esac

# Detect WSL
IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    IS_WSL=true
fi

# Detect distro
DISTRO_NAME="unknown"
DISTRO_SLUG="unknown"
DISTRO_VERSION=""

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_NAME="${NAME:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-}"
    ID_LOWER=$(echo "${ID:-}" | tr '[:upper:]' '[:lower:]')
    VERSION_NODOT="${DISTRO_VERSION//./}"

    if $IS_WSL; then
        DISTRO_SLUG="wsl-ubuntu"
    else
        case "$ID_LOWER" in
            ubuntu)   DISTRO_SLUG="ubuntu${VERSION_NODOT}" ;;
            debian)   DISTRO_SLUG="debian${DISTRO_VERSION}" ;;
            rhel)     DISTRO_SLUG="rhel${DISTRO_VERSION%%.*}" ;;
            rocky)    DISTRO_SLUG="rhel${DISTRO_VERSION%%.*}" ;;
            centos)   DISTRO_SLUG="rhel${DISTRO_VERSION%%.*}" ;;
            fedora)   DISTRO_SLUG="fedora${DISTRO_VERSION}" ;;
            sles|opensuse-leap) DISTRO_SLUG="sles${DISTRO_VERSION%%.*}" ;;
            amzn)     DISTRO_SLUG="amzn${DISTRO_VERSION}" ;;
            *)        DISTRO_SLUG="${ID_LOWER}${DISTRO_VERSION}" ;;
        esac
    fi
fi

# Detect package manager
PKG_MGR="unknown"
if command -v apt-get &>/dev/null; then PKG_MGR="apt"; fi
if command -v dnf &>/dev/null;     then PKG_MGR="dnf"; fi
if command -v yum &>/dev/null && [[ "$PKG_MGR" == "unknown" ]]; then PKG_MGR="yum"; fi
if command -v zypper &>/dev/null;  then PKG_MGR="zypper"; fi

# Detect existing CUDA
CUDA_INSTALLED="none"
if command -v nvcc &>/dev/null; then
    CUDA_INSTALLED=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' || echo "unknown")
elif [[ -f /usr/local/cuda/bin/nvcc ]]; then
    CUDA_INSTALLED=$(/usr/local/cuda/bin/nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' || echo "unknown")
fi

echo "arch=$ARCH_SLUG"
echo "is_wsl=$IS_WSL"
echo "distro_name=$DISTRO_NAME"
echo "distro_slug=$DISTRO_SLUG"
echo "distro_version=$DISTRO_VERSION"
echo "pkg_mgr=$PKG_MGR"
echo "cuda_installed=$CUDA_INSTALLED"
