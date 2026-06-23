#!/usr/bin/env bash
set -euo pipefail

# Generate CUDA install commands for a given distro/arch/version/type
# Usage: generate-install.sh --distro <slug> --arch <arch> --cuda-version <X.Y> --type <deb_local|deb_network|rpm_local|rpm_network>

DISTRO=""
ARCH="x86_64"
CUDA_VERSION=""
INSTALLER_TYPE="deb_local"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --distro)       DISTRO="$2";        shift 2 ;;
        --arch)         ARCH="$2";          shift 2 ;;
        --cuda-version) CUDA_VERSION="$2";  shift 2 ;;
        --type)         INSTALLER_TYPE="$2";shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$DISTRO" || -z "$CUDA_VERSION" ]]; then
    echo "Usage: $0 --distro <slug> --arch <arch> --cuda-version <X.Y> --type <type>" >&2
    exit 1
fi

# Normalize version: "13.0" -> major=13, minor=0, dash="13-0", nodot="130"
CUDA_MAJOR="${CUDA_VERSION%%.*}"
CUDA_MINOR="${CUDA_VERSION##*.}"
CUDA_DASH="${CUDA_MAJOR}-${CUDA_MINOR}"
CUDA_NODOT="${CUDA_MAJOR}${CUDA_MINOR}"

BASE_URL="https://developer.download.nvidia.com/compute/cuda"
REPO_BASE="${BASE_URL}/repos/${DISTRO}/${ARCH}"

echo ""
echo "### CUDA ${CUDA_VERSION} install commands — distro: ${DISTRO}, arch: ${ARCH}, type: ${INSTALLER_TYPE}"
echo ""

case "$INSTALLER_TYPE" in

  deb_local)
    LOCAL_DEB="cuda-repo-${DISTRO}-${CUDA_DASH}-local_${CUDA_VERSION}.0-1_${ARCH}.deb"
    LOCAL_DEB_URL="${BASE_URL}/${CUDA_VERSION}/local_installers/${LOCAL_DEB}"
    echo '```bash'
    echo "wget ${LOCAL_DEB_URL}"
    echo "sudo dpkg -i ${LOCAL_DEB}"
    echo "sudo cp /var/cuda-repo-${DISTRO}-${CUDA_DASH}-local/cuda-*-keyring.gpg /usr/share/keyrings/"
    echo "sudo apt-get update"
    echo "sudo apt-get -y install cuda-toolkit-${CUDA_DASH}"
    if [[ "$DISTRO" == wsl-ubuntu* ]]; then
        echo ""
        echo "# WSL note: do NOT install the driver package — the driver is managed by Windows."
    fi
    echo '```'
    ;;

  deb_network)
    echo '```bash'
    echo "wget ${REPO_BASE}/cuda-keyring_1.1-1_all.deb"
    echo "sudo dpkg -i cuda-keyring_1.1-1_all.deb"
    echo "sudo apt-get update"
    echo "sudo apt-get -y install cuda-toolkit-${CUDA_DASH}"
    if [[ "$DISTRO" == wsl-ubuntu* ]]; then
        echo ""
        echo "# WSL note: do NOT install the driver package — the driver is managed by Windows."
    fi
    echo '```'
    ;;

  rpm_local)
    LOCAL_RPM="cuda-repo-${DISTRO}-${CUDA_DASH}-local-${CUDA_VERSION}.0-1.${ARCH}.rpm"
    LOCAL_RPM_URL="${BASE_URL}/${CUDA_VERSION}/local_installers/${LOCAL_RPM}"
    echo '```bash'
    echo "wget ${LOCAL_RPM_URL}"
    echo "sudo rpm -i ${LOCAL_RPM}"
    # RHEL/Rocky need EPEL and the module
    if [[ "$DISTRO" == rhel* ]]; then
        echo "sudo dnf config-manager --add-repo ${REPO_BASE}/cuda-${DISTRO}.repo"
    fi
    echo "sudo dnf clean all"
    echo "sudo dnf -y install cuda-toolkit-${CUDA_DASH}"
    echo '```'
    ;;

  rpm_network)
    echo '```bash'
    if [[ "$DISTRO" == rhel* ]]; then
        echo "sudo dnf config-manager --add-repo ${REPO_BASE}/cuda-${DISTRO}.repo"
    elif [[ "$DISTRO" == fedora* ]]; then
        echo "sudo dnf config-manager --add-repo ${REPO_BASE}/cuda-${DISTRO}.repo"
    elif [[ "$DISTRO" == sles* ]]; then
        echo "sudo zypper addrepo ${REPO_BASE}/cuda-${DISTRO}.repo"
        echo "sudo zypper --gpg-auto-import-keys install cuda-toolkit-${CUDA_DASH}"
        echo '```'
        exit 0
    fi
    echo "sudo dnf clean all"
    echo "sudo dnf -y install cuda-toolkit-${CUDA_DASH}"
    echo '```'
    ;;

  *)
    echo "Unknown installer type: $INSTALLER_TYPE" >&2
    echo "Supported: deb_local, deb_network, rpm_local, rpm_network" >&2
    exit 1
    ;;
esac

echo ""
echo "### Post-install: set up PATH"
echo ""
echo '```bash'
echo 'echo "export PATH=/usr/local/cuda/bin:\$PATH" >> ~/.bashrc'
echo 'echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc'
echo 'source ~/.bashrc'
echo '```'
echo ""
echo "### Verify"
echo ""
echo '```bash'
echo 'nvcc --version'
echo 'nvidia-smi'
echo '```'
