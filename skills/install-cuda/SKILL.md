---
name: jcd:install-cuda
description: Use when the user wants to install CUDA Toolkit, cuDNN, or related NVIDIA GPU libraries on Linux. Handles distribution selection, version selection, and produces the correct install commands for deb-based (Ubuntu, Debian, WSL-Ubuntu) and rpm-based (RHEL, Fedora, SLES) distros.
disable-model-invocation: false
user-invocable: true
context: fork
model: sonnet
allowed-tools: Bash, Read, WebFetch, AskFollowUp
argument-hint: "[cuda-version] [distro]"
---

# Install CUDA

Guide the user through selecting and installing CUDA Toolkit (and optionally cuDNN/NCCL) on Linux.

## Step 1: Detect or Ask OS/Distro

Run the detection script to determine the current environment, then confirm with the user or let them override:

```bash
bash {{SKILLS_DIR}}/install-cuda/scripts/detect-env.sh
```

Ask the user to confirm or change:
1. **OS type** — Linux (only Linux is supported by this skill)
2. **Architecture** — `x86_64` or `arm64-sbsa`
3. **Distribution** — see table below
4. **CUDA version** — e.g. `13.0`, `12.6`, `12.4` (default: latest stable)
5. **Installer type** — `deb_local` (recommended) or `deb_network`

### Distribution Map

| User-friendly name | Repo slug | Notes |
|--------------------|-----------|-------|
| WSL-Ubuntu | `wsl-ubuntu` | For Ubuntu running inside WSL2 |
| Ubuntu 24.04 | `ubuntu2404` | |
| Ubuntu 22.04 | `ubuntu2204` | |
| Ubuntu 20.04 | `ubuntu2004` | |
| Debian 12 | `debian12` | |
| Debian 11 | `debian11` | |
| RHEL / Rocky 9 | `rhel9` | yum/dnf |
| RHEL / Rocky 8 | `rhel8` | yum/dnf |
| Fedora 39+ | `fedora39` (etc.) | dnf |
| SLES 15 | `sles15` | zypper |
| Amazon Linux 2023 | `amzn2023` | dnf |

For other distros listed on https://developer.download.nvidia.com/compute/cuda/repos/ use the slug directly.

## Step 2: Generate Install Commands

Use the script to generate the install commands:

```bash
bash {{SKILLS_DIR}}/install-cuda/scripts/generate-install.sh \
  --distro <slug> \
  --arch <arch> \
  --cuda-version <version> \
  --type <deb_local|deb_network|rpm_local|rpm_network>
```

Present the commands to the user as a copy-pasteable block.

## Step 3: Optional — cuDNN and NCCL

After CUDA installs, ask if they want cuDNN or NCCL. If yes, provide the apt/dnf install command for the matching version:

```bash
# cuDNN (deb-based)
sudo apt install cudnn9-cuda-<major>

# NCCL (deb-based)
sudo apt install libnccl2 libnccl-dev
```

For rpm-based:
```bash
sudo dnf install cudnn9-cuda-<major>
sudo dnf install libnccl libnccl-devel
```

## Step 4: Verify Installation

After the user runs the commands, verify with:

```bash
nvcc --version
nvidia-smi
python3 -c "import torch; print(torch.cuda.is_available())"
```

## Notes

- For WSL2: driver is managed by Windows — do NOT install the driver package, only the toolkit.
- The `cuda-toolkit` meta-package installs a specific version. Use `cuda-toolkit-X-Y` to pin to a version.
- After install, ensure `/usr/local/cuda/bin` is on PATH and `/usr/local/cuda/lib64` is on LD_LIBRARY_PATH.
