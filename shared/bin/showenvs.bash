#!/bin/bash
echo
# echo WARNING: DO NOT RUN ME IN THE pytorch/ DIRECTORY!
# let's do this instead:
cd $HOME
echo
echo
echo "RELEVANT BUILD FLAGS"
echo
set | grep -E 'TORCH|ROCM|CUDA|DEBUG'
echo
echo "PYTHON & TORCH ENV"
echo
echo "*** THOU python COMMAND SHALL THUS USE ***"
which python
echo "******************************************"
echo
python3 -c "
import sys
print('Python version:')
print(sys.version)
print('\nPython path:')
print(sys.path)
print()
import torch
import inspect
print(f'Torch is imported from: {inspect.getfile(torch)}')
print(f'torch.random is imported from: {inspect.getfile(torch.random)}')
print(f'Torch version: {torch.__version__}')
print('cuda avail:',torch.cuda.is_available())
# print('torch has triton', torch.utils._triton.has_triton())
print('cuda dev cap', torch.cuda.get_device_capability())
torch.cuda.init()
print('cuda is initd:',torch.cuda.is_initialized())
print('cuda device count:',torch.cuda.device_count())
print()
import triton
print(f'Triton is imported from: {inspect.getfile(triton)}')
print(f'Triton version: {triton.__version__}')
print()
print(torch.__config__.show())
"
echo 
echo CHECKING TORCHVISION
python3 -c "import torchvision"
echo
# Check if pytorch directory exists
if [ -d "$HOME/pytorch" ]; then
    echo "Custom-compiled python found:"
    ls -ld $HOME/pytorch
    echo
    echo "GIT REVISION"
    cd $HOME/pytorch
    git rev-parse HEAD
    echo
    # Check if version file exists
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
else
    echo 'WARNING: $HOME/pytorch softlink not found -> no custom-compiled python available'
    echo
fi
