#!/bin/bash

## summary: # in the case someone asks wtf you are doing
summary='
rm -rf build
python setup.py clean
git reset --hard
git clean -fd
git submodule deinit -f third_party/kineto
rm -rf third_party/x86-simd-sort/
rm -rf third_party/kleidiai/
git submodule update --init --recursive
python tools/amd_build/build_amd.py
python setup.py develop
pip uninstall -y torch
python setup.py install
'

target="/root/sharedump/out.txt"

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
    echo "Will do git reset --hard (discard non-committed) and other cleanup and recursive submodule update"
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

echo " " > $target

if [ ! -z "$PYTORCH_ROCM_ARCH" ]; then
    echo " " >> $target
    echo ">>>>>1 RUNNING build_amd.py" >> $target
    echo " " >> $target
    python tools/amd_build/build_amd.py >> $target 2>&1
    echo " " >> $target
fi
### TIP: look for text "fatal error" if compilation crashes
echo
echo COMPILING
echo
echo see progress with:
echo
echo "tail -f $target"
echo
echo " " >> $target
echo ">>>>>2 RUNNING SETUP DEVELOP" >> $target
echo " " >> $target
python setup.py develop >> $target 2>&1
if [ $? -ne 0 ]; then
    echo "FATAL"
    echo "Failed to compile"
    echo
    exit 1
fi
echo
echo "#### INSTALL PHASE #####" >> $target 2>&1
echo
echo RUNNING UNINSTALL
echo
echo " " >> $target
echo ">>>>>3 RUNNING UNINSTALL" >> $target
echo " " >> $target
pip uninstall -y torch >> $target 2>&1
echo
echo RUNNING INSTALL
echo
echo " " >> $target
echo ">>>>>4 RUNNING INSTALL" >> $target
echo " " >> $target
python setup.py install >> $target 2>&1
##
## better idea:
# python setup.py develop
## ..but that doesn't really make any difference - this could work:
## Find your site-packages directory
#SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
## Create symbolic links for specific libraries
#ln -sf /root/pytorch/build/lib/libc10.so $SITE_PACKAGES/torch/lib/
##
## for quick-rebuild after modifying the cpp code, please use the "rebuild" alias
##
if [ $? -ne 0 ]; then
    echo "FATAL"
    echo "Failed to install"
    echo
    exit 1
fi
echo
echo "Please run showenvs.bash to test"
echo
