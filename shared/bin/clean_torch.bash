#!/bin/bash

auto_yes=false
for arg in "$@"; do
    if [ "$arg" = "-y" ] || [ "$arg" = "--yes" ]; then
        auto_yes=true
    fi
done

# Detect GPU and set architecture
#detect_gpu_and_set_arch
#if [ $? -ne 0 ]; then
#    echo "Error: Could not detect a supported GPU"
#    exit 1
#fi
if [ ! -z "$TORCH_CUDA_ARCH_LIST" ]; then
    echo "NVIDIA GPU support enabled with architectures: $TORCH_CUDA_ARCH_LIST"
elif [ ! -z "$PYTORCH_ROCM_ARCH" ]; then
    echo "ROCm GPU support enabled with architectures: $PYTORCH_ROCM_ARCH"
else
    echo "Neither NVIDIA nor ROCm GPU architectures specified"
    exit 1
fi

## how about these?
#export BUILD_TEST=0
#export USE_CAFFE2=0
## -> they are now automagically loaded from contenv.bash
##
## run this to clean any trace of a previous install and compilation of pytorch
## you need to be in /tmp/pytorch or /var/lib/jenkins/pytorch
# pip uninstall -y torch  # let's not do this as we might want to use torch while the new version is compiling..
rm -rf build
python setup.py clean
echo
if [ "$auto_yes" = true ]; then
    choice="y"
else
    echo "Will do git reset --hard and other cleanup and recursive submodule update"
    read -p "Continue with cleanup? (y/n): " choice
fi
echo
if [[ $choice == "y" || $choice == "Y" ]]; then
    git reset --hard
    ## -> discards everything not committed
    git clean -fd
    ## -> removes all .so and .pyc build artifacts
    # git submodule foreach --recursive 
    # .. that one needs a subcommand
    ## stubborn kineto..
    git submodule deinit -f third_party/kineto
    # Simply remove the directory if you don't need it
    rm -rf third_party/x86-simd-sort/
    rm -rf third_party/kleidiai/
    #git submodule update --init --recursive third_party/kineto
    #git submodule update --init --recursive third_party/composable_kernel
    git submodule update --init --recursive
    if [ $? -ne 0 ]; then
        echo "FATAL"
        echo "Failed to update submodules"
        echo
        exit 1
    fi
    #
    echo
    echo "GIT STATUS:"
    git status -uno
    # -> doesn't show uncommitted files
else
    echo "no cleanup"
fi
if [ ! -z "$PYTORCH_ROCM_ARCH" ]; then
    echo "AMD: $PYTORCH_ROCM_ARCH"
elif [ ! -z "$TORCH_CUDA_ARCH_LIST" ]; then
    echo "NVIDIA: $TORCH_CUDA_ARCH_LIST"
fi
echo
if [ "$auto_yes" = false ]; then
    echo "Press any key to proceed with compilation, CTRL-C to abort.."
    read -n1
    echo
fi
if [ ! -z "$PYTORCH_ROCM_ARCH" ]; then
    python tools/amd_build/build_amd.py &>/root/sharedump/out.txt
fi
echo
echo COMPILING
echo
echo see progress with:
echo
echo "tail -f /root/sharedump/out.txt"
echo 
python setup.py develop >> /root/sharedump/out.txt 2>&1
if [ $? -ne 0 ]; then
    echo "FATAL"
    echo "Failed to compile"
    echo
    exit 1
fi
echo
echo "#### INSTALL PHASE #####" >> /root/sharedump/out.txt 2>&1
echo
echo RUNNING UNINSTALL
echo
pip uninstall -y torch >> /root/sharedump/out.txt 2>&1
echo
echo RUNNING INSTALL
echo
python setup.py install >> /root/sharedump/out.txt 2>&1
if [ $? -ne 0 ]; then
    echo "FATAL"
    echo "Failed to install"
    echo
    exit 1
fi
echo
echo "Please run showenvs.bash to test"
echo
