#!/bin/bash
# the idea here is, that you use get_torch_*.bash scripts to git clone different pytorch versions into $HOME
# then start using one of them, by running this script which softlinks $HOME/pytorch -> your desired torch
#
if [ -z "$1" ]; then
    echo "Error: name tag missing"
    exit 1
fi
rm -f $HOME/pytorch
ln -s $HOME/pytorch-$1 $HOME/pytorch

## let's do this in a separate script instead..
#cd $HOME/pytorch
#if [ -d "venv" ]; then
#    echo "lintrunner venv directory exists"
#else
#    export PYTHONNOUSERSITE=1
#    export PIP_NO_CACHE_DIR=1
#    echo "will create venv and install lintrunner therein"
#    python -m venv $HOME/pytorch/venv
#    $HOME/pytorch/venv/bin/pip install lintrunner
#    
#    echo "Installing required linters"
#    $HOME/pytorch/venv/bin/lintrunner init
#    echo "Installed required linters"
#    unset PYTHONNOUSERSITE
#    unset PIP_NO_CACHE_DIR
#    echo
#fi

TRITON_PIN_FILE="$HOME/pytorch/.ci/docker/ci_commit_pins/triton.txt"

if [ -f "$TRITON_PIN_FILE" ]; then
    # Get expected commit hash from pin file
    expected_hash=$(head -n1 "$TRITON_PIN_FILE" | tr -d '[:space:]')
    expected_hash_short=$(echo "$expected_hash" | head -c 8)
    
    # Get installed triton git hash using Python
    actual_hash=$(python3 -c "import triton; print(getattr(triton, '__git_hash__', 'unknown'))" 2>/dev/null || echo "unknown")
    actual_hash_short=$(echo "$actual_hash" | head -c 8)
    
    # Also get version for display
    actual_version=$(python3 -c "import triton; print(triton.__version__)" 2>/dev/null || echo "not installed")
    
    if [ "$expected_hash_short" = "$actual_hash_short" ]; then
        echo "Triton commit matches: $actual_hash_short (version $actual_version)"
        echo 
        echo "When linting, run first \"initlinter.bash\" and then use the \"lintrun\" alias to run lintrunner in the virtualenv"
        echo
        exit 0
    else
        echo "WARNING: Triton commit mismatch"
        echo "Expected: $expected_hash_short ($expected_hash)"
        echo "Actual:   $actual_hash_short (version $actual_version)"
        echo
        read -p "Would you like to install the pinned commit? (y/n) " answer
        if [[ $answer == [Yy]* ]]; then
            install_triton_hash.bash "$expected_hash"
            exit $?
        else
            exit 1
        fi
    fi
else
    echo "WARNING: Triton pin file not found: $TRITON_PIN_FILE"
    exit 1
fi

