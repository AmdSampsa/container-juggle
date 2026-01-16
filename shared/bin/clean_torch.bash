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
just_install=false
for arg in "$@"; do
    if [ "$arg" = "-y" ] || [ "$arg" = "--yes" ]; then
        auto_yes=true
    elif [ "$arg" = "--just-install" ]; then
        just_install=true
    fi
done

# ============================================================
# JUST INSTALL MODE - Skip cleanup and compilation
# ============================================================
if [ "$just_install" = true ]; then
    echo "=========================================="
    echo "  JUST INSTALL MODE"
    echo "=========================================="
    echo
    echo "⚠️  IMPORTANT: This assumes torch has already been compiled!"
    echo "   (i.e., you have run 'python setup.py develop' successfully)"
    echo
    echo "This will:"
    echo "  1. Uninstall the current torch package"
    echo "  2. Install torch from the compiled source"
    echo
    if [ "$auto_yes" = false ]; then
        read -p "Continue? (y/n): " choice
        if [[ $choice != "y" && $choice != "Y" ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
    echo
    echo "Running uninstall..."
    pip uninstall -y torch
    if [ $? -ne 0 ]; then
        echo
        echo "WARNING: Failed to uninstall torch"
        echo
    fi
    echo
    echo "Running install..."
    python setup.py install
    if [ $? -ne 0 ]; then
        echo "FATAL: Failed to install"
        exit 1
    fi
    echo
    echo "✓ Installation complete!"
    echo "Did pytorch install at $(date '+%Y-%m-%d %H:%M:%S') in ${PWD}" >> /tmp/torchlog.txt
    echo
    echo "Please run showenvs.bash to test"
    echo
    exit 0
fi
# ============================================================
# END JUST INSTALL MODE
# ============================================================

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

# ============================================================
# ROCm GCC TOOLCHAIN CHECK
# ============================================================
if [ ! -z "$PYTORCH_ROCM_ARCH" ]; then
    echo
    echo "Checking ROCm compiler toolchain requirements..."
    
    ROCM_CLANG="/opt/rocm/llvm/bin/clang++"
    if [ -x "$ROCM_CLANG" ]; then
        # Get the GCC version that ROCm's clang expects
        required_gcc=$($ROCM_CLANG -v -x c++ -E /dev/null 2>&1 | grep "include.*search" -A5 | grep "/usr/lib/gcc/x86_64-linux-gnu/" | head -1 | sed 's|.*/usr/lib/gcc/x86_64-linux-gnu/\([0-9]*\)/.*|\1|')
        
        if [ -n "$required_gcc" ]; then
            echo "  ROCm clang expects GCC: $required_gcc"
            
            # Check if that GCC version's libstdc++ is installed
            if [ -d "/usr/lib/gcc/x86_64-linux-gnu/$required_gcc" ] && [ -d "/usr/include/c++/$required_gcc" ]; then
                echo "  ✓ GCC $required_gcc toolchain found"
            else
                echo
                echo "  ⚠️  WARNING: ROCm clang requires GCC $required_gcc but it's not installed!"
                echo
                echo "  This WILL cause compilation to fail with errors like:"
                echo "    fatal error: 'cstdlib' file not found"
                echo "    fatal error: 'cmath' file not found"
                echo
                
                # Check if the required package is available
                pkg_available=$(apt-cache show "g++-$required_gcc" 2>/dev/null | grep -c "Package:")
                
                if [ "$pkg_available" -gt 0 ]; then
                    echo "  Fix: Install GCC $required_gcc with:"
                    echo "    apt-get update && apt-get install -y g++-$required_gcc libstdc++-$required_gcc-dev"
                    echo
                    
                    if [ "$auto_yes" = false ]; then
                        echo "  Options:"
                        echo "    [i] Install GCC $required_gcc now"
                        echo "    [c] Continue anyway (will likely fail)"
                        echo "    [a] Abort"
                        echo
                        read -p "  Choice [i/c/a]: " gcc_choice
                        case $gcc_choice in
                            i|I)
                                echo
                                echo "  Installing GCC $required_gcc..."
                                apt-get update && apt-get install -y "g++-$required_gcc" "libstdc++-$required_gcc-dev"
                                if [ $? -eq 0 ]; then
                                    echo "  ✓ GCC $required_gcc installed successfully"
                                else
                                    echo "  ✗ Failed to install GCC $required_gcc"
                                    exit 1
                                fi
                                ;;
                            c|C)
                                echo "  Continuing anyway..."
                                ;;
                            *)
                                echo "  Aborted."
                                exit 1
                                ;;
                        esac
                    else
                        echo "  Auto-yes mode: Attempting to install GCC $required_gcc..."
                        apt-get update && apt-get install -y "g++-$required_gcc" "libstdc++-$required_gcc-dev"
                        if [ $? -ne 0 ]; then
                            echo "  ✗ Failed to install GCC $required_gcc"
                            exit 1
                        fi
                        echo "  ✓ GCC $required_gcc installed successfully"
                    fi
                else
                    echo "  ✗ GCC $required_gcc package not available in apt!"
                    echo "  You may need to add a PPA or use a different ROCm version."
                    echo
                    if [ "$auto_yes" = false ]; then
                        read -p "  Continue anyway? (y/n): " cont_choice
                        if [[ $cont_choice != "y" && $cont_choice != "Y" ]]; then
                            echo "  Aborted."
                            exit 1
                        fi
                    else
                        echo "  Auto-yes mode: Aborting due to missing toolchain."
                        exit 1
                    fi
                fi
            fi
        else
            echo "  ⚠️  Could not determine required GCC version from ROCm clang"
        fi
    else
        echo "  ⚠️  ROCm clang not found at $ROCM_CLANG"
    fi
    echo
fi
# ============================================================
# END ROCm GCC TOOLCHAIN CHECK
# ============================================================

export CMAKE_ARGS="-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
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
    # git reset --hard
    git reset --hard --recurse-submodules
    ## -> discards everything not committed
    git clean -fd
    # git clean -fd --recurse-submodules
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
    echo "Did pytorch cleanup at $(date '+%Y-%m-%d %H:%M:%S') in ${PWD}" >> /tmp/torchlog.txt
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

# ============================================================
# VERSION CONSISTENCY CHECK & CLEANUP
# ============================================================
echo
echo "Checking version consistency..."
if [ -f "version.txt" ]; then
    # Extract version from version.txt (e.g., "2.10.0a0" -> major=2, minor=10)
    version_txt=$(cat version.txt | head -n1)
    txt_major=$(echo "$version_txt" | cut -d. -f1)
    txt_minor=$(echo "$version_txt" | cut -d. -f2)
    
    echo "  version.txt: ${version_txt} (${txt_major}.${txt_minor})"
    
    # Check for environment variables that override version.txt
    if [ -n "$PYTORCH_BUILD_VERSION" ]; then
        echo
        echo "⚠️  WARNING: PYTORCH_BUILD_VERSION is set to: $PYTORCH_BUILD_VERSION"
        echo "  This will OVERRIDE version.txt during build!"
        echo "  Unsetting PYTORCH_BUILD_VERSION and PYTORCH_BUILD_NUMBER..."
        unset PYTORCH_BUILD_VERSION
        unset PYTORCH_BUILD_NUMBER
        unset PYTORCH_VERSION
        echo "  ✓ Environment variables cleared"
    fi
    
    # Check for cached torch/version.py
    if [ -f "torch/version.py" ]; then
        cached_version=$(grep "^__version__" torch/version.py 2>/dev/null | cut -d"'" -f2)
        if [ -n "$cached_version" ]; then
            echo "  torch/version.py (cached): $cached_version"
            if [[ ! "$cached_version" =~ ^${txt_major}\.${txt_minor} ]]; then
                echo "  ⚠️  Cached version mismatch! Removing torch/version.py..."
                rm -f torch/version.py
                echo "  ✓ Removed cached torch/version.py"
            fi
        fi
    fi
    
    # Check if stale generated version.h exists (it should be deleted by git clean)
    if [ -f "torch/headeronly/version.h" ]; then
        # Extract version from torch/headeronly/version.h
        header_major=$(grep "^#define TORCH_VERSION_MAJOR" torch/headeronly/version.h 2>/dev/null | awk '{print $3}')
        header_minor=$(grep "^#define TORCH_VERSION_MINOR" torch/headeronly/version.h 2>/dev/null | awk '{print $3}')
        
        if [ -n "$header_major" ] && [ -n "$header_minor" ]; then
            echo "  torch/headeronly/version.h: ${header_major}.${header_minor}"
            
            if [ "$txt_major" != "$header_major" ] || [ "$txt_minor" != "$header_minor" ]; then
                echo "  ⚠️  Stale version.h detected! Removing..."
                rm -f torch/headeronly/version.h
                echo "  ✓ Removed stale version.h"
            fi
        fi
    fi
    
    echo "  ✓ Version consistency check complete"
else
    echo "  ⚠️  Could not find version.txt"
fi
echo
# ============================================================
# END VERSION CONSISTENCY CHECK & CLEANUP
# ============================================================

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
echo "Did pytorch compile at $(date '+%Y-%m-%d %H:%M:%S') in ${PWD}" >> /tmp/torchlog.txt
echo
echo "#### INSTALL PHASE #####" >> $target 2>&1
echo
echo "=========================================="
echo "  COMPILATION COMPLETE!"
echo "=========================================="
echo
echo "Next steps:"
echo "  1. Uninstall current torch package"
echo "  2. Install the newly compiled torch"
echo
if [ "$auto_yes" = false ]; then
    read -p "Continue with installation? (y/n): " install_choice
    if [[ $install_choice != "y" && $install_choice != "Y" ]]; then
        echo
        echo "Installation skipped. PyTorch has been compiled but not installed."
        echo "You can install it later by running:"
        echo "  $0 --just-install"
        echo
        exit 0
    fi
fi
echo
echo RUNNING UNINSTALL
echo
echo " " >> $target
echo ">>>>>3 RUNNING UNINSTALL" >> $target
echo " " >> $target
pip uninstall -y torch >> $target 2>&1
if [ $? -ne 0 ]; then
    echo
    echo "WARNING"
    echo "Failed to uninstall"
    echo
fi
echo
echo "Did pytorch uninstall at $(date '+%Y-%m-%d %H:%M:%S') in ${PWD}" >> /tmp/torchlog.txt
echo
echo RUNNING INSTALL
echo
echo " " >> $target
echo ">>>>>4 RUNNING INSTALL" >> $target
echo " " >> $target
python setup.py install >> $target 2>&1
echo
if [ $? -ne 0 ]; then
    echo "FATAL"
    echo "Failed to install"
    echo
    exit 1
fi
echo "Did pytorch install at $(date '+%Y-%m-%d %H:%M:%S') in ${PWD}" >> /tmp/torchlog.txt
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
