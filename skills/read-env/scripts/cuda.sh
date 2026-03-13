#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "CUDA"

# CUDA toolkit via nvcc
if command -v nvcc &>/dev/null; then
    nvcc_ver=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' || echo "unknown")
    echo "  nvcc: $nvcc_ver ($(command -v nvcc))"
elif [[ -f /usr/local/cuda/bin/nvcc ]]; then
    nvcc_ver=$(/usr/local/cuda/bin/nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' || echo "unknown")
    echo "  nvcc: $nvcc_ver (/usr/local/cuda/bin/nvcc)"
else
    echo "  nvcc: not found"
fi

# CUDA_HOME / CUDA_PATH
if [[ -n "${CUDA_HOME:-}" ]]; then
    echo "  CUDA_HOME: $CUDA_HOME"
elif [[ -n "${CUDA_PATH:-}" ]]; then
    echo "  CUDA_PATH: $CUDA_PATH"
elif [[ -d /usr/local/cuda ]]; then
    echo "  CUDA location: /usr/local/cuda (CUDA_HOME not set)"
fi

# CUDA runtime version via nvidia-smi
if command -v nvidia-smi &>/dev/null; then
    cuda_driver_ver=$(nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[0-9.]+' || true)
    if [[ -n "$cuda_driver_ver" ]]; then
        echo "  CUDA driver version: $cuda_driver_ver"
    fi
fi

# cuDNN
cudnn_found=false
if command -v python3 &>/dev/null; then
    cudnn_ver=$(python3 -c "
try:
    import torch
    print(torch.backends.cudnn.version())
except:
    pass
" 2>/dev/null || true)
    if [[ -n "$cudnn_ver" ]]; then
        echo "  cuDNN (via torch): $cudnn_ver"
        cudnn_found=true
    fi
fi
if ! $cudnn_found; then
    # Check for cudnn header
    for header in /usr/include/cudnn_version.h /usr/local/cuda/include/cudnn_version.h /usr/include/cudnn.h /usr/local/cuda/include/cudnn.h; do
        if [[ -f "$header" ]]; then
            major=$(grep -m1 'CUDNN_MAJOR' "$header" 2>/dev/null | awk '{print $3}' || true)
            minor=$(grep -m1 'CUDNN_MINOR' "$header" 2>/dev/null | awk '{print $3}' || true)
            patch=$(grep -m1 'CUDNN_PATCHLEVEL' "$header" 2>/dev/null | awk '{print $3}' || true)
            if [[ -n "$major" ]]; then
                echo "  cuDNN: ${major}.${minor}.${patch} ($header)"
                cudnn_found=true
                break
            fi
        fi
    done
fi
if ! $cudnn_found; then
    echo "  cuDNN: not found"
fi

# NCCL
nccl_found=false
for header in /usr/include/nccl.h /usr/local/cuda/include/nccl.h; do
    if [[ -f "$header" ]]; then
        major=$(grep -m1 'NCCL_MAJOR' "$header" 2>/dev/null | awk '{print $3}' || true)
        minor=$(grep -m1 'NCCL_MINOR' "$header" 2>/dev/null | awk '{print $3}' || true)
        patch=$(grep -m1 'NCCL_PATCH' "$header" 2>/dev/null | awk '{print $3}' || true)
        if [[ -n "$major" ]]; then
            echo "  NCCL: ${major}.${minor}.${patch} ($header)"
            nccl_found=true
            break
        fi
    fi
done
if ! $nccl_found; then
    echo "  NCCL: not found"
fi
