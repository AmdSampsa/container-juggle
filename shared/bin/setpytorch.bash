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

cd $HOME/pytorch
echo
echo "Installing required linters"
echo
lintrunner init
echo
echo "Installed required linters"
echo

if [ -f "$HOME/pytorch/.ci/docker/triton_version.txt" ]; then
    # Get expected version from file
    expected_version=$(cat "$HOME/pytorch/.ci/docker/triton_version.txt")
    
    # Get installed triton version using Python
    actual_version=$(python3 -c "import triton; print(triton.__version__)")
    
    if [ "$expected_version" = "$actual_version" ]; then
        echo "Triton versions match: $actual_version"
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
