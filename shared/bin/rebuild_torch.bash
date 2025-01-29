#!/bin/bash

echo
echo USE clean_torch.bash instead to compile pytorch
echo
exit 2

# Function to detect GPU and set architecture
detect_gpu_and_set_arch() {
    # First check for NVIDIA GPUs using nvidia-smi
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        echo "NVIDIA GPU detected"
        # Get the GPU architecture using nvidia-smi
        # Extract compute capability (e.g., 7.5 for Turing, 8.0 for Ampere)
        CUDA_ARCH=$(nvidia-smi --query-gpu=compute_capability --format=csv,noheader | head -n1 | tr -d '.' )
        export TORCH_CUDA_ARCH_LIST="$CUDA_ARCH"
        echo "Set TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
        return 0
    fi

    # Check for AMD GPUs using rocminfo
    if command -v rocminfo &> /dev/null && rocminfo &> /dev/null; then
        echo "AMD GPU detected"
        # Extract the architecture (e.g., gfx906)
        export PYTORCH_ROCM_ARCH=$(rocminfo | grep -i "gfx" | grep -m1 "gfx[0-9]" | awk '{print $2}')
        echo "Set PYTORCH_ROCM_ARCH=$PYTORCH_ROCM_ARCH"
        return 0
    fi

    echo "No supported GPU detected!"
    return 1
}

# Detect GPU and set architecture
detect_gpu_and_set_arch
if [ $? -ne 0 ]; then
    echo "Error: Could not detect a supported GPU"
    exit 1
fi

echo
echo "You will be compiling for the following architecture(s):"
if [ ! -z "$PYTORCH_ROCM_ARCH" ]; then
    echo "AMD: $PYTORCH_ROCM_ARCH"
elif [ ! -z "$TORCH_CUDA_ARCH_LIST" ]; then
    echo "NVIDIA: $TORCH_CUDA_ARCH_LIST"
fi

echo "Press any key to continue, CTRL-C to abort"
echo
read -n1
echo

echo "COMPILING - see output in /root/sharedump/out.txt"
echo 
python setup.py develop &>/root/sharedump/out.txt
echo
echo "Remember to run python setup.py install"
echo
