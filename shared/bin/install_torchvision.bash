#!/bin/bash

# TorchVision & TorchAudio Installation Script
# Supports both source builds and pre-built wheels

LOG_FILE="$HOME/torchvision_torchaudio_install.log"

echo "=========================================="
echo "  TorchVision & TorchAudio Installation"
echo "=========================================="
echo
echo "Log file: $LOG_FILE"
echo
echo "1) Install from GitHub (build from source)"
echo "   - Use this if you have a custom PyTorch build"
echo "2) Install from PyPI (pre-built wheel)"
echo "   - Use this for standard PyTorch installations"
echo
read -p "Select installation method (1 or 2): " choice

# Initialize log
echo "=== TorchVision & TorchAudio Installation ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

case $choice in
    1)
        echo
        echo "=========================================="
        echo "  Building from Source"
        echo "=========================================="
        echo
        echo "This will compile against your current PyTorch:"
        python3 -c "import torch; print(f'  PyTorch: {torch.__version__}')"
        python3 -c "import torch; print(f'  Location: {torch.__file__}')"
        echo
        
        # =====================
        # TORCHVISION
        # =====================
        echo "----------------------------------------"
        echo "  Step 1/2: TorchVision"
        echo "----------------------------------------"
        
        VISION_DIR="$HOME/torchvision"
        
        if [ -d "$VISION_DIR" ]; then
            echo "Existing torchvision directory found."
            read -p "Remove and re-clone? (y/n): " reclone_vision
            if [ "$reclone_vision" = "y" ] || [ "$reclone_vision" = "Y" ]; then
                rm -rf "$VISION_DIR"
            fi
        fi
        
        if [ ! -d "$VISION_DIR" ]; then
            echo "Cloning torchvision..."
            git clone https://github.com/pytorch/vision.git "$VISION_DIR" 2>&1 | tee -a "$LOG_FILE"
        fi
        
        cd "$VISION_DIR" || exit 1
        
        echo "Fetching tags and branches..."
        git fetch --all --tags 2>&1 | tee -a "$LOG_FILE"
        
        # Get PyTorch version to match torchvision release
        TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__.split('+')[0])")
        echo "PyTorch version: $TORCH_VERSION"
        
        # Find matching torchvision tag
        MATCHING_TAG=$(git tag | grep "^v${TORCH_VERSION}" | sort -V | tail -1)
        if [ -z "$MATCHING_TAG" ]; then
            # Fall back to latest release tag
            MATCHING_TAG=$(git tag | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
            echo "No exact match, using latest: $MATCHING_TAG"
        fi
        
        echo "Using torchvision tag: $MATCHING_TAG"
        git checkout "$MATCHING_TAG" 2>&1 | tee -a "$LOG_FILE"
        
        echo "Uninstalling existing torchvision..."
        pip uninstall -y torchvision 2>&1 | tee -a "$LOG_FILE"
        
        echo "Building torchvision from source..."
        echo "Build started: $(date)" >> "$LOG_FILE"
        pip install . --no-build-isolation --progress-bar off 2>&1 | tee -a "$LOG_FILE"
        VISION_STATUS=${PIPESTATUS[0]}
        
        if [ $VISION_STATUS -eq 0 ]; then
            echo "✓ TorchVision built successfully!"
        else
            echo "✗ TorchVision build failed!"
            echo "Check log: $LOG_FILE"
        fi
        
        # =====================
        # TORCHAUDIO
        # =====================
        echo
        echo "----------------------------------------"
        echo "  Step 2/2: TorchAudio"
        echo "----------------------------------------"
        
        AUDIO_DIR="$HOME/torchaudio"
        
        if [ -d "$AUDIO_DIR" ]; then
            echo "Existing torchaudio directory found."
            read -p "Remove and re-clone? (y/n): " reclone_audio
            if [ "$reclone_audio" = "y" ] || [ "$reclone_audio" = "Y" ]; then
                rm -rf "$AUDIO_DIR"
            fi
        fi
        
        if [ ! -d "$AUDIO_DIR" ]; then
            echo "Cloning torchaudio..."
            git clone https://github.com/pytorch/audio.git "$AUDIO_DIR" 2>&1 | tee -a "$LOG_FILE"
        fi
        
        cd "$AUDIO_DIR" || exit 1
        
        echo "Fetching tags and branches..."
        git fetch --all --tags 2>&1 | tee -a "$LOG_FILE"
        
        # Get PyTorch version to match torchaudio release
        TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__.split('+')[0])")
        echo "PyTorch version: $TORCH_VERSION"
        
        # Find matching torchaudio tag
        MATCHING_TAG=$(git tag | grep "^v${TORCH_VERSION}" | sort -V | tail -1)
        if [ -z "$MATCHING_TAG" ]; then
            # Fall back to latest release tag
            MATCHING_TAG=$(git tag | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
        fi
        
        echo "Using torchaudio tag: $MATCHING_TAG"
        git checkout "$MATCHING_TAG" 2>&1 | tee -a "$LOG_FILE"
        
        # Initialize submodules (torchaudio has third-party deps)
        echo "Initializing submodules..."
        git submodule update --init --recursive 2>&1 | tee -a "$LOG_FILE"
        
        echo "Uninstalling existing torchaudio..."
        pip uninstall -y torchaudio 2>&1 | tee -a "$LOG_FILE"
        
        echo "Building torchaudio from source..."
        echo "Build started: $(date)" >> "$LOG_FILE"
        # Note: pip install doesn't work well with torchaudio, use setup.py
        python setup.py install 2>&1 | tee -a "$LOG_FILE"
        AUDIO_STATUS=${PIPESTATUS[0]}
        
        if [ $AUDIO_STATUS -eq 0 ]; then
            echo "✓ TorchAudio built successfully!"
        else
            echo "✗ TorchAudio build failed!"
            echo "Check log: $LOG_FILE"
        fi
        
        # Summary
        echo
        echo "=========================================="
        echo "  Build Summary"
        echo "=========================================="
        [ $VISION_STATUS -eq 0 ] && echo "  TorchVision: ✓ SUCCESS" || echo "  TorchVision: ✗ FAILED"
        [ $AUDIO_STATUS -eq 0 ] && echo "  TorchAudio:  ✓ SUCCESS" || echo "  TorchAudio:  ✗ FAILED"
        echo "=========================================="
        ;;
        
    2)
        echo
        echo "Installing from PyPI (pre-built wheels)..."
        echo
        
        # Detect if we're on NVIDIA or AMD system
        if command -v nvidia-smi &> /dev/null; then
            echo "Detected NVIDIA GPU system"
            
            # Get CUDA version
            cuda_version=$(nvidia-smi | grep "CUDA Version" | sed -n 's/.*CUDA Version: \([0-9]*\.[0-9]*\).*/\1/p')
            echo "Detected CUDA version: $cuda_version"
            
            # Convert to URL format (e.g., 12.1 -> cu121, 11.8 -> cu118)
            cuda_url_version="cu$(echo $cuda_version | sed 's/\.//')"
            echo "Using CUDA URL version: $cuda_url_version"
            echo
            
            pip3 install --no-deps --pre torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/$cuda_url_version 2>&1 | tee -a "$LOG_FILE"
            
        elif [ -d "/opt/rocm" ]; then
            echo "Detected AMD ROCm system"
            
            # Get ROCm version dynamically
            rocm_full_version=$(readlink -f /opt/rocm | sed 's/.*rocm-//')
            echo "Detected ROCm version: $rocm_full_version"
            
            # Extract major.minor version (e.g., 7.0.0 -> 7.0)
            rocm_short_version=$(echo "$rocm_full_version" | sed -E 's/([0-9]+\.[0-9]+).*/\1/')
            rocm_url_version="rocm${rocm_short_version}"
            
            echo "Using ROCm URL version: $rocm_url_version"
            echo
            
            pip3 install --no-deps --pre torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/$rocm_url_version 2>&1 | tee -a "$LOG_FILE"
            
        else
            echo "WARNING: Could not detect GPU type (neither NVIDIA nor AMD ROCm found)"
            echo "Falling back to CPU-only installation..."
            echo
            pip3 install --no-deps --pre torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cpu 2>&1 | tee -a "$LOG_FILE"
        fi
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo
echo "=========================================="
echo "  Verifying Installation"
echo "=========================================="
python3 -c "
import sys
try:
    import torch
    print(f'  torch:       {torch.__version__}')
except ImportError as e:
    print(f'  torch:       NOT INSTALLED ({e})')
    
try:
    import torchvision
    print(f'  torchvision: {torchvision.__version__}')
except ImportError as e:
    print(f'  torchvision: NOT INSTALLED ({e})')
    
try:
    import torchaudio
    print(f'  torchaudio:  {torchaudio.__version__}')
except ImportError as e:
    print(f'  torchaudio:  NOT INSTALLED ({e})')
"
echo "=========================================="
echo
echo "Log file: $LOG_FILE"
