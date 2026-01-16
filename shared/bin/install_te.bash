#!/bin/bash

# Transformer Engine Installation Script
# Supports both NVIDIA and ROCm versions

LOG_FILE="$HOME/te_install.log"
TE_DIR="$HOME/TransformerEngine"

echo "=========================================="
echo "  Transformer Engine Installation"
echo "=========================================="
echo
echo "Log file: $LOG_FILE"
echo

# Initialize log file
echo "=== Transformer Engine Installation Log ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Function to log and display
log_msg() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Cleanup existing installation
if [ -d "$TE_DIR" ]; then
    echo "Existing TransformerEngine directory found at $TE_DIR"
    read -p "Remove it and start fresh? (y/n): " remove_existing
    if [ "$remove_existing" = "y" ] || [ "$remove_existing" = "Y" ]; then
        log_msg "Removing existing directory..."
        rm -rf "$TE_DIR"
    else
        log_msg "Keeping existing directory. Will use it for branch selection."
    fi
fi

# Step 1: Auto-detect GPU type and select repository
echo
echo "Detecting GPU type..."
echo "=========================================="

if [ -d "/opt/rocm" ] && command -v hipcc &> /dev/null; then
    # ROCm detected
    DETECTED_GPU="AMD/ROCm"
    REPO_URL="https://github.com/ROCm/TransformerEngine.git"
    REPO_NAME="ROCm/TransformerEngine"
    
    # Get ROCm version for display
    if [ -L "/opt/rocm" ]; then
        ROCM_VERSION=$(readlink -f /opt/rocm | sed 's/.*rocm-//')
    else
        ROCM_VERSION=$(cat /opt/rocm/.info/version 2>/dev/null || echo "unknown")
    fi
    log_msg "Detected: AMD ROCm $ROCM_VERSION"
    
elif command -v nvidia-smi &> /dev/null; then
    # NVIDIA detected
    DETECTED_GPU="NVIDIA/CUDA"
    REPO_URL="https://github.com/NVIDIA/TransformerEngine.git"
    REPO_NAME="NVIDIA/TransformerEngine"
    
    # Get CUDA version for display
    CUDA_VERSION=$(nvidia-smi 2>/dev/null | grep "CUDA Version" | sed -n 's/.*CUDA Version: \([0-9]*\.[0-9]*\).*/\1/p')
    log_msg "Detected: NVIDIA CUDA $CUDA_VERSION"
    
else
    # Neither detected - ask user
    echo "WARNING: Could not auto-detect GPU type"
    echo
    echo "Select Transformer Engine source manually:"
    echo "1) ROCm/TransformerEngine  (AMD GPUs)"
    echo "2) NVIDIA/TransformerEngine (NVIDIA GPUs)"
    echo
    read -p "Select repository (1 or 2): " repo_choice

    case $repo_choice in
        1)
            REPO_URL="https://github.com/ROCm/TransformerEngine.git"
            REPO_NAME="ROCm/TransformerEngine"
            DETECTED_GPU="AMD/ROCm (manual)"
            ;;
        2)
            REPO_URL="https://github.com/NVIDIA/TransformerEngine.git"
            REPO_NAME="NVIDIA/TransformerEngine"
            DETECTED_GPU="NVIDIA/CUDA (manual)"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi

log_msg "GPU Type: $DETECTED_GPU"
log_msg "Auto-selected: $REPO_NAME"

echo
read -p "Use $REPO_NAME? (Y/n): " confirm_repo
if [ "$confirm_repo" = "n" ] || [ "$confirm_repo" = "N" ]; then
    echo
    echo "Select repository manually:"
    echo "1) ROCm/TransformerEngine  (AMD GPUs)"
    echo "2) NVIDIA/TransformerEngine (NVIDIA GPUs)"
    read -p "Select (1 or 2): " manual_choice
    case $manual_choice in
        1)
            REPO_URL="https://github.com/ROCm/TransformerEngine.git"
            REPO_NAME="ROCm/TransformerEngine"
            ;;
        2)
            REPO_URL="https://github.com/NVIDIA/TransformerEngine.git"
            REPO_NAME="NVIDIA/TransformerEngine"
            ;;
    esac
    log_msg "Manually selected: $REPO_NAME"
fi

log_msg "Selected repository: $REPO_NAME"
log_msg "URL: $REPO_URL"

# Step 2: Clone repository if needed
if [ ! -d "$TE_DIR" ]; then
    echo
    log_msg "Cloning $REPO_NAME into $TE_DIR..."
    git clone "$REPO_URL" "$TE_DIR" 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        log_msg "ERROR: Failed to clone repository"
        exit 1
    fi
fi

cd "$TE_DIR" || exit 1

# Fetch all branches and tags
log_msg "Fetching all branches and tags..."
git fetch --all --tags 2>&1 | tee -a "$LOG_FILE"

# Step 3: Find and display release branches
echo
echo "=========================================="
echo "  Available Release Branches/Tags"
echo "=========================================="
echo

# Get release branches (remote branches containing 'release')
echo "Release branches:"
RELEASE_BRANCHES=$(git branch -r | grep -i 'release' | sed 's/origin\///' | sort -V)

if [ -z "$RELEASE_BRANCHES" ]; then
    echo "  (No release branches found)"
else
    echo "$RELEASE_BRANCHES" | nl -w2 -s') '
fi

echo
echo "Release tags:"
RELEASE_TAGS=$(git tag | grep -iE '^v?[0-9]+\.[0-9]+' | sort -V | tail -20)

if [ -z "$RELEASE_TAGS" ]; then
    echo "  (No release tags found)"
else
    echo "$RELEASE_TAGS" | nl -w2 -s') '
fi

# Combine for selection
ALL_RELEASES=$(echo -e "$RELEASE_BRANCHES\n$RELEASE_TAGS" | grep -v '^$' | sort -V | uniq)
RELEASE_ARRAY=()
while IFS= read -r line; do
    [ -n "$line" ] && RELEASE_ARRAY+=("$line")
done <<< "$ALL_RELEASES"

echo
echo "=========================================="
echo "Options:"
echo "  - Enter a number from the list above"
echo "  - Type 'main' or 'master' for latest development"
echo "  - Type a specific branch/tag name"
echo "=========================================="
echo
read -p "Select branch/tag: " branch_input

# Determine the actual branch/tag to checkout
if [[ "$branch_input" =~ ^[0-9]+$ ]]; then
    # User entered a number
    idx=$((branch_input - 1))
    if [ $idx -ge 0 ] && [ $idx -lt ${#RELEASE_ARRAY[@]} ]; then
        SELECTED_BRANCH="${RELEASE_ARRAY[$idx]}"
    else
        echo "Invalid selection. Using 'main'."
        SELECTED_BRANCH="main"
    fi
else
    # User entered a name directly
    SELECTED_BRANCH="$branch_input"
fi

log_msg "Selected branch/tag: $SELECTED_BRANCH"

# Checkout the selected branch
echo
log_msg "Checking out $SELECTED_BRANCH..."
git checkout "$SELECTED_BRANCH" 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log_msg "WARNING: Checkout may have failed, attempting to continue..."
fi

# Initialize submodules
log_msg "Initializing submodules..."
git submodule update --init --recursive 2>&1 | tee -a "$LOG_FILE"

# Step 4: Uninstall existing transformer-engine
echo
log_msg "Removing existing transformer-engine installation..."
pip uninstall -y transformer-engine transformer-engine-torch transformer-engine-jax 2>&1 | tee -a "$LOG_FILE"

# Step 5: Set environment variables
echo
log_msg "Setting up environment variables..."

# Set MAX_JOBS for faster parallel compilation
if [ -z "$MAX_JOBS" ]; then
    export MAX_JOBS=$(nproc)
fi
log_msg "MAX_JOBS=$MAX_JOBS (parallel compilation jobs)"

# Detect GPU type and set appropriate variables
if [ -d "/opt/rocm" ]; then
    log_msg "Detected ROCm environment"
    
    # Basic paths
    export ROCM_PATH=/opt/rocm
    export HIP_PATH=/opt/rocm
    export CMAKE_PREFIX_PATH=/opt/rocm/lib/cmake:${CMAKE_PREFIX_PATH:-}
    
    # TE framework settings
    export NVTE_FRAMEWORK=pytorch
    export NVTE_USE_ROCM=1
    export NVTE_WITH_USERBUFFERS=0
    
    # ROCm architecture - detect or use default
    # Try to detect GPU architecture from rocminfo
    DETECTED_ARCH=$(rocminfo 2>/dev/null | grep -oP 'gfx\d+[a-z]?' | head -1)
    if [ -n "$DETECTED_ARCH" ]; then
        export NVTE_ROCM_ARCH="$DETECTED_ARCH"
    else
        # Default to MI300X architecture
        export NVTE_ROCM_ARCH="gfx942"
    fi
    
    # Set CU count based on architecture
    case "$NVTE_ROCM_ARCH" in
        gfx942)  # MI300X / MI300A
            export CU_NUM=304
            ;;
        gfx90a)  # MI250X / MI210
            export CU_NUM=110
            ;;
        gfx908)  # MI100
            export CU_NUM=120
            ;;
        *)
            export CU_NUM=128  # Safe default
            ;;
    esac
    
    echo "  ROCM_PATH=$ROCM_PATH" | tee -a "$LOG_FILE"
    echo "  HIP_PATH=$HIP_PATH" | tee -a "$LOG_FILE"
    echo "  NVTE_FRAMEWORK=$NVTE_FRAMEWORK" | tee -a "$LOG_FILE"
    echo "  NVTE_USE_ROCM=$NVTE_USE_ROCM" | tee -a "$LOG_FILE"
    echo "  NVTE_ROCM_ARCH=$NVTE_ROCM_ARCH" | tee -a "$LOG_FILE"
    echo "  CU_NUM=$CU_NUM" | tee -a "$LOG_FILE"
    echo "  NVTE_WITH_USERBUFFERS=$NVTE_WITH_USERBUFFERS" | tee -a "$LOG_FILE"
elif command -v nvidia-smi &> /dev/null; then
    log_msg "Detected NVIDIA environment"
    export NVTE_FRAMEWORK=pytorch
    echo "  NVTE_FRAMEWORK=$NVTE_FRAMEWORK" | tee -a "$LOG_FILE"
fi

# Step 6: Build and install
echo
echo "=========================================="
echo "  Starting Build (this will take a while)"
echo "=========================================="
echo

# Clean previous build to avoid stale cached cmake paths
if [ -d "$TE_DIR/build" ]; then
    log_msg "Cleaning previous build directory..."
    rm -rf "$TE_DIR/build"
fi
rm -rf "$TE_DIR"/*.egg-info 2>/dev/null

log_msg "Running: pip install . --no-build-isolation"
log_msg "Build started at: $(date)"
echo
echo "Build output is being logged to: $LOG_FILE"
echo "You can monitor progress with: tail -f $LOG_FILE"
echo

# Use unbuffered output and capture everything
# The --progress-bar off helps with the animation issue
pip install . --no-build-isolation --progress-bar off 2>&1 | tee -a "$LOG_FILE"
BUILD_STATUS=${PIPESTATUS[0]}

echo "" >> "$LOG_FILE"
log_msg "Build finished at: $(date)"

# Step 7: Report result
echo
echo "=========================================="
if [ $BUILD_STATUS -eq 0 ]; then
    log_msg "SUCCESS: Transformer Engine installed successfully!"
    echo
    echo "Verifying installation..."
    python3 -c "import transformer_engine; print(f'Transformer Engine version: {transformer_engine.__version__}')" 2>&1 | tee -a "$LOG_FILE"
else
    log_msg "ERROR: Build failed with exit code $BUILD_STATUS"
    echo
    echo "Check the log file for details: $LOG_FILE"
    echo
    echo "Common issues:"
    echo "  - Missing dependencies (cmake, ninja)"
    echo "  - ROCm/CUDA environment not set up correctly"
    echo "  - Incompatible PyTorch version"
fi
echo "=========================================="
echo
echo "Full log available at: $LOG_FILE"

