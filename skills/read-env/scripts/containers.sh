#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "Container & Virtualization"

check_tool docker "docker --version" "docker"
check_tool podman "podman --version" "podman"
check_tool kubectl "kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -1" "kubectl"
check_tool helm "helm version --short 2>/dev/null" "helm"
