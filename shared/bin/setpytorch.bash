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

if [ -f "$HOME/pytorch/.ci/docker/triton_version.txt" ]; then
    # Get expected version from file
    expected_version=$(cat "$HOME/pytorch/.ci/docker/triton_version.txt")
    
    # Get installed triton version using Python
    actual_version=$(python3 -c "import triton; print(triton.__version__)")
    
    if [ "$expected_version" = "$actual_version" ]; then
        echo "Triton versions match: $actual_version"
        echo 
        echo when linting, run first "initlinter.bash" and then use the "lintrun" alias to run lintunner in the virtualenv
        echo
        exit 0
    else
        echo "FATAL: Triton version mismatch"
        echo "Expected: $expected_version"
        echo "Actual: $actual_version"
        read -p "Would you like to install the compatible version? (y/n) " answer
        if [[ $answer == [Yy]* ]]; then
            expected_generic=$(echo "$expected_version" | sed -E 's/([0-9]+\.[0-9]+)\.[0-9]+/\1.x/') # into 3.2.x etc.
            install_triton.bash "$expected_generic"
            exit $?
        else
            exit 1
        fi
    fi
else
    echo "WARNING: Triton version file not found"
    exit 1
fi

