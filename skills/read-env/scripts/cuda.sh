#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_helpers.sh"

section "CUDA"

# CUDA toolkit via nvcc
if command -v nvcc &>/dev/null; then
    nvcc_ver=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' || echo "unknown")
    echo "  nvcc: $nvcc_ver ($(command -v nvcc))"
    nvcc_archs=$(nvcc --list-gpu-arch 2>/dev/null | tr '\n' ' ' || true)
    [[ -n "$nvcc_archs" ]] && echo "  nvcc supported archs: $nvcc_archs"
elif [[ -f /usr/local/cuda/bin/nvcc ]]; then
    nvcc_ver=$(/usr/local/cuda/bin/nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' || echo "unknown")
    echo "  nvcc: $nvcc_ver (/usr/local/cuda/bin/nvcc)"
    nvcc_archs=$(/usr/local/cuda/bin/nvcc --list-gpu-arch 2>/dev/null | tr '\n' ' ' || true)
    [[ -n "$nvcc_archs" ]] && echo "  nvcc supported archs: $nvcc_archs"
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

# CUDA-related env vars
for var in CUDA_VISIBLE_DEVICES CUDA_DEVICE_ORDER CUDA_LAUNCH_BLOCKING; do
    [[ -n "${!var:-}" ]] && echo "  $var: ${!var}"
done

# nvidia-smi: driver, per-GPU info, topology
if command -v nvidia-smi &>/dev/null; then
    driver_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)
    [[ -n "$driver_ver" ]] && echo "  nvidia driver: $driver_ver"
    cuda_driver_ver=$(nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[0-9.]+' || true)
    [[ -n "$cuda_driver_ver" ]] && echo "  CUDA driver version: $cuda_driver_ver"

    gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -1 || echo 0)
    if [[ "${gpu_count:-0}" -gt 0 ]]; then
        echo "  GPUs: $gpu_count"
        nvidia-smi --query-gpu=index,name,compute_cap,memory.total,memory.free,temperature.gpu,clocks.current.sm,pcie.link.gen.current,pcie.link.width.current,ecc.mode.current,mig.mode.current \
            --format=csv,noheader,nounits 2>/dev/null \
            | while IFS=',' read -r idx gname cap memtot memfree temp sm_clk pcie_gen pcie_w ecc mig; do
            echo "  GPU $idx:$gname"
            echo "    compute capability:$cap"
            echo "    memory:${memtot}MiB total,${memfree}MiB free"
            echo "    temp:${temp}C  SM clock:${sm_clk}MHz  PCIe gen${pcie_gen}x${pcie_w}"
            ecc_clean="${ecc//[[:space:]]/}"; ecc_clean="${ecc_clean//[/}"; ecc_clean="${ecc_clean//]/}"
            if [[ "$ecc_clean" != "N/A" ]]; then echo "    ECC:$ecc  MIG:$mig"; fi
        done
    fi

    if [[ "${gpu_count:-0}" -gt 1 ]]; then
        echo "  topology:"
        nvidia-smi topo -m 2>/dev/null | sed 's/^/    /' || true
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

# Additional CUDA libraries from headers
declare -A cuda_libs=(
    ["cuBLAS"]="cublas_api.h:CUBLAS_VER_MAJOR:CUBLAS_VER_MINOR:CUBLAS_VER_PATCH"
    ["cuSPARSE"]="cusparse.h:CUSPARSE_VER_MAJOR:CUSPARSE_VER_MINOR:CUSPARSE_VER_PATCH"
    ["cuRAND"]="curand.h:CURAND_VER_MAJOR:CURAND_VER_MINOR:CURAND_VER_PATCH"
    ["cuFFT"]="cufft.h:CUFFT_VER_MAJOR:CUFFT_VER_MINOR:CUFFT_VER_PATCH"
)
for include_dir in "${CUDA_HOME:-}/include" "${CUDA_PATH:-}/include" /usr/local/cuda/include /usr/include; do
    [[ -d "$include_dir" ]] || continue
    found_any=false
    for libname in "${!cuda_libs[@]}"; do
        IFS=':' read -r header maj_macro min_macro pat_macro <<< "${cuda_libs[$libname]}"
        header_path="$include_dir/$header"
        [[ -f "$header_path" ]] || continue
        major=$(grep -m1 "#define $maj_macro" "$header_path" 2>/dev/null | awk '{print $3}' || true)
        [[ -z "$major" ]] && continue
        minor=$(grep -m1 "#define $min_macro" "$header_path" 2>/dev/null | awk '{print $3}' || true)
        patch=$(grep -m1 "#define $pat_macro" "$header_path" 2>/dev/null | awk '{print $3}' || true)
        echo "  $libname: ${major}.${minor}.${patch} ($header_path)"
        found_any=true
    done
    if $found_any; then break; fi
done

# CUDA profiling/debug tools
check_tool "nsys"     "nsys --version 2>&1 | head -1"         "Nsight Systems"
check_tool "ncu"      "ncu --version 2>&1 | head -1"          "Nsight Compute"
check_tool "cuda-gdb" "cuda-gdb --version 2>&1 | head -1"     "cuda-gdb"
