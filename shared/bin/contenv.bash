#!/bin/bash
## run with source
export PATH=$PATH:/root/shared/bin
export BINDIR=/root/shared/bin
## for easy access: cd $TORCHDIR:
## this is only for rocm images.. for nightlies its /tmp/pytorch
# export TORCHDIR=/var/lib/jenkins/pytorch
## this is better:
if [ -d "/var/lib/jenkins/pytorch" ]; then
    export TORCHDIR="/var/lib/jenkins/pytorch"
elif [ -d "/tmp/pytorch" ]; then
    export TORCHDIR="/tmp/pytorch"
else
    echo "WARNING: Neither pytorch directory found!"
fi
## where torch is actually imported & being executed from:
echo "probing torch installation.."
export TORCHEXE=$(python3 -c "import torch; import os; print(os.path.dirname(torch.__file__))")
echo "..done"
# 
export ROCPROFDIR=/var/lib/jenkins/rocmProfileData
export SHAREDIR=/root/shared
# in the case we have compiled pytorch ourselves, also use custom modules from shared/pythonenv:
export PYTHONPATH=/root/pytorch:$PYTHONPATH:/root/shared/pythonenv
export SHAREDUMP=/root/sharedump
# this should be avail if we have logged in correctly:
export CTXENV=/root/shared/env/$contextname
## export CTXENV=    # NOTE: this is set in your .bashrc (was written there by install.bash)
## better prompt
# export PS1='[$contextname->Container:\h]/\W> '
export PS1='[$contextname->Container]/\W> '
## short-hand commands for inductor runs:
alias indbg='rm -rf /tmp/torchinductor_root && rm -rf torch_compile_debug && TORCH_COMPILE_DEBUG=1 python'
alias tridbg='rm -rf /tmp/torchinductor_root && rm -rf torch_compile_debug && rm -rf ~/.triton/cache && TORCH_COMPILE_DEBUG=1 python'
alias indrun='rm -rf /tmp/torchinductor_root && python'
## memfault debugging:
alias memrun='HSA_TOOLS_LIB=/opt/rocm/lib/librocm-debug-agent.so.2 HSA_ENABLE_DEBUG=1 python'
#
alias subinit='git submodule deinit -f third_party/kineto && git submodule deinit -f third_party/ideep && rm -rf third_party/x86-simd-sort/ && git submodule update --init --recursive'
#
export BUILD_TEST=0
export USE_CAFFE2=0
#
## once you have ran get_torch.bash and clean_torch.bash, you can use devenv command"
alias localenv='export PYTHONPATH=$HOME/pytorch:$PYTHONPATH'
## this is in case your python code is in /var/lib/jenkins/pytorch or in /tmp/pytorch
alias devenv='export PYTHONPATH=$TORCHDIR:$PYTHONPATH'
## install torch from the current dir:
alias install-torch='pip uninstall -y torch && python setup.py install'
#
# Function to detect GPU and set architecture
detect_gpu_and_set_arch() {
    # First check for NVIDIA GPUs using nvidia-smi
    if command -v nvidia-smi &> /dev/null; then
        echo "NVIDIA GPU detected"
        echo "original arch list:"$TORCH_CUDA_ARCH_LIST
        # Get the GPU architecture using nvidia-smi
        # Extract compute capability (e.g., 7.5 for Turing, 8.0 for Ampere)
        CUDA_ARCH=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1)
        export TORCH_CUDA_ARCH_LIST="$CUDA_ARCH"
        echo "Set TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
        return 0
    fi

    # Check for AMD GPUs using rocminfo
    if command -v rocminfo &> /dev/null && rocminfo &> /dev/null; then
        echo "AMD GPU detected"
        # Extract the architecture (e.g., gfx906)
        export PYTORCH_ROCM_ARCH=$(rocminfo | grep -i "gfx" | grep -m1 "gfx[0-9]" | awk '{print $2}')
        # this god'damn env variable is not set in the nightly containers
        export PYTORCH_TEST_WITH_ROCM=1
        echo "Set PYTORCH_ROCM_ARCH=$PYTORCH_ROCM_ARCH"
        echo "Set PYTORCH_TEST_WITH_ROCM=$PYTORCH_TEST_WITH_ROCM"
        return 0
    fi

    echo "No supported GPU detected!"
    return 1
}
detect_gpu_and_set_arch
