#!/bin/bash

set -e

# Parse command line arguments
VERSION_ARG=""
if [ $# -gt 0 ]; then
    VERSION_ARG="$1"
fi

# Function to prompt for input with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        result="${result:-$default}"
    else
        read -p "$prompt: " result
    fi
    
    echo "$result"
}

# Ask for installation method
echo "====================================="
echo "Triton Installation Script"
echo "====================================="
echo
echo "Select installation method:"
echo "  1) Git repo & compile (pip install .)"
echo "  2) Git repo & make dev-install-llvm"
echo "  3) Install from PyPI (pip install --no-deps triton==VERSION)"
echo
read -p "Enter choice [1-3]: " INSTALL_METHOD

case "$INSTALL_METHOD" in
    1|2)
        # Git repo installation
        echo
        echo "Select git repository source:"
        echo "  1) triton-lang/triton"
        echo "  2) ROCm/triton"
        echo
        read -p "Enter choice [1-2]: " REPO_CHOICE
        
        case "$REPO_CHOICE" in
            1)
                REPO_SOURCE="triton-lang"
                ;;
            2)
                REPO_SOURCE="ROCm"
                ;;
            *)
                echo "Error: Invalid choice"
                exit 1
                ;;
        esac
        
        # Determine branch/version
        if [ -n "$VERSION_ARG" ]; then
            BRANCH="release/$VERSION_ARG"
            echo
            echo "Using version from argument: $VERSION_ARG"
            echo "Will checkout: $BRANCH"
        else
            echo
            BRANCH=$(prompt_with_default "Enter branch name" "main")
        fi
        
        # Set the destination directory
        if [ "$REPO_SOURCE" = "triton-lang" ]; then
            TRITON_DIR="$HOME/triton"
        else
            TRITON_DIR="$HOME/triton-$REPO_SOURCE"
        fi
        
        echo
        echo "Repository: https://github.com/$REPO_SOURCE/triton"
        echo "Branch: $BRANCH"
        echo "Directory: $TRITON_DIR"
        echo
        
        # Clone repository if it doesn't exist
        if [ ! -d "$TRITON_DIR" ]; then
            echo "Cloning repository..."
            git clone --shallow-since="3 months ago" "https://github.com/$REPO_SOURCE/triton" "$TRITON_DIR"
        fi
        
        cd "$TRITON_DIR"
        
        # Configure git to fetch all branches
        git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
        
        echo "Fetching latest changes..."
        git fetch --all
        
        # Checkout the desired branch
        echo "Checking out $BRANCH..."
        if [ "$BRANCH" = "main" ]; then
            git checkout main
            git pull
        else
            git checkout "$BRANCH"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to checkout $BRANCH"
                echo "NOTE: Release tags are typically in format: release/3.2.x"
                exit 1
            fi
            git pull || true
        fi
        
        # Uninstall existing triton installations
        echo
        echo "Uninstalling existing triton installations..."
        pip uninstall -y triton 2>/dev/null || true
        pip uninstall -y pytorch-triton-rocm 2>/dev/null || true
        rm -rf ~/.triton 2>/dev/null || true
        
        # Install based on method
        if [ "$INSTALL_METHOD" = "1" ]; then
            # Method 1: Compile (pip install .)
            echo
            echo "Installing triton with pip install..."
            
            # Find the installable directory (repo structure varies)
            INSTALL_DIR=""
            if [ -f "$TRITON_DIR/python/setup.py" ] || [ -f "$TRITON_DIR/python/pyproject.toml" ]; then
                INSTALL_DIR="$TRITON_DIR/python"
            elif [ -f "$TRITON_DIR/setup.py" ] || [ -f "$TRITON_DIR/pyproject.toml" ]; then
                INSTALL_DIR="$TRITON_DIR"
            else
                echo "ERROR: Could not find setup.py or pyproject.toml in triton repo"
                echo "Searched: $TRITON_DIR and $TRITON_DIR/python"
                exit 1
            fi
            
            echo "Installing from: $INSTALL_DIR"
            cd "$INSTALL_DIR"
            pip install .
            
            if [ $? -ne 0 ]; then
                echo
                echo "ERROR: pip install failed"
                echo "You may want to try method 2 (make dev-install-llvm)"
                exit 1
            fi
            
            echo
            echo "✓ Triton installed successfully!"
        else
            # Method 2: make dev-install-llvm
            echo
            echo "Installing triton with make dev-install-llvm..."
            cd "$TRITON_DIR"
            
            if [ ! -f "Makefile" ]; then
                echo "Error: Makefile not found in $TRITON_DIR"
                exit 1
            fi
            
            # ============================================================
            # CLANG COMPILER CHECK (required for building LLVM from source)
            # ============================================================
            echo
            echo "Checking for clang compiler (required for LLVM build)..."
            
            if command -v clang &> /dev/null && command -v clang++ &> /dev/null; then
                echo "  ✓ clang found: $(which clang)"
            else
                echo "  ⚠️  clang/clang++ not found in PATH!"
                echo
                echo "  Building LLVM from source requires clang. Options:"
                echo
                
                # Check if ROCm clang exists
                if [ -x "/opt/rocm/llvm/bin/clang" ]; then
                    echo "    [r] Use ROCm's clang (/opt/rocm/llvm/bin/clang)"
                fi
                echo "    [i] Install system clang (apt-get install clang lld)"
                echo "    [a] Abort"
                echo
                read -p "  Choice: " clang_choice
                
                case $clang_choice in
                    r|R)
                        if [ -x "/opt/rocm/llvm/bin/clang" ]; then
                            export CC=/opt/rocm/llvm/bin/clang
                            export CXX=/opt/rocm/llvm/bin/clang++
                            echo "  ✓ Using ROCm clang: $CC"
                        else
                            echo "  ✗ ROCm clang not found"
                            exit 1
                        fi
                        ;;
                    i|I)
                        echo "  Installing clang..."
                        apt-get update && apt-get install -y clang lld
                        if [ $? -eq 0 ]; then
                            echo "  ✓ clang installed"
                        else
                            echo "  ✗ Failed to install clang"
                            exit 1
                        fi
                        ;;
                    *)
                        echo "  Aborted."
                        exit 1
                        ;;
                esac
            fi
            echo
            # ============================================================
            # END CLANG COMPILER CHECK
            # ============================================================
            
            make dev-install-llvm
            
            if [ $? -ne 0 ]; then
                echo
                echo "ERROR: make dev-install-llvm failed"
                exit 1
            fi
            
            echo
            echo "✓ Triton installed successfully!"
        fi
        ;;
        
    3)
        # PyPI installation
        if [ -n "$VERSION_ARG" ]; then
            TRITON_VERSION="$VERSION_ARG"
            echo
            echo "Using version from argument: $TRITON_VERSION"
        else
            echo
            TRITON_VERSION=$(prompt_with_default "Enter triton version (e.g., 3.2.0)" "")
            if [ -z "$TRITON_VERSION" ]; then
                echo "Error: Version is required for PyPI installation"
                exit 1
            fi
        fi
        
        # Convert .x suffix to .* for pip wildcard matching
        TRITON_VERSION_PATTERN="${TRITON_VERSION%.x}.*"
        
        # ============================================================
        # CHECK IF VERSION IS AVAILABLE ON PYPI
        # ============================================================
        echo
        echo "Checking if triton==$TRITON_VERSION_PATTERN is available on PyPI..."
        
        # Get available versions from PyPI
        available_versions=$(pip index versions triton 2>/dev/null | grep -oP '(?<=Available versions: ).*' | tr ',' '\n' | tr -d ' ')
        
        if [ -z "$available_versions" ]; then
            echo "  ⚠️  Could not fetch available versions from PyPI"
            echo "  Continuing anyway..."
        else
            # Check if requested version pattern matches any available version
            # Handle wildcard pattern (e.g., 3.2.*)
            version_base="${TRITON_VERSION_PATTERN%.*}"
            matching_versions=$(echo "$available_versions" | grep "^${version_base}\." | head -5)
            
            if [ -z "$matching_versions" ]; then
                echo "  ✗ No versions matching '$TRITON_VERSION_PATTERN' found on PyPI!"
                echo
                echo "  Available versions (latest first):"
                echo "$available_versions" | head -10 | sed 's/^/    /'
                echo
                read -p "  Enter a different version or 'q' to quit: " new_version
                if [ "$new_version" = "q" ] || [ -z "$new_version" ]; then
                    echo "  Aborted."
                    exit 1
                fi
                TRITON_VERSION_PATTERN="${new_version%.x}.*"
                echo "  Using: triton==$TRITON_VERSION_PATTERN"
            else
                echo "  ✓ Found matching versions:"
                echo "$matching_versions" | head -3 | sed 's/^/      /'
            fi
        fi
        echo
        # ============================================================
        # END VERSION CHECK
        # ============================================================
        
        echo "Installing triton==$TRITON_VERSION_PATTERN from PyPI..."
        
        # Uninstall existing triton installations
        pip uninstall -y triton 2>/dev/null || true
        pip uninstall -y pytorch-triton-rocm 2>/dev/null || true
        rm -rf ~/.triton 2>/dev/null || true
        
        pip install --no-deps "triton==$TRITON_VERSION_PATTERN"
        
        if [ $? -ne 0 ]; then
            echo
            echo "ERROR: Failed to install triton from PyPI"
            exit 1
        fi
        
        echo
        echo "✓ Triton installed successfully!"
        ;;
        
    *)
        echo "Error: Invalid choice"
        exit 1
        ;;
esac

echo
echo "Installation complete!"
echo "====================================="
