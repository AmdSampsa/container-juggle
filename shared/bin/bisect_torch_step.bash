#!/usr/bin/env bash
#
# One scripted path for ROCm PyTorch bisect rebuilds:
#   1) clean source tree (--just-clean)
#   2) optional git checkout (ref from bisect or manual)
#   3) clean_torch.bash --yes  (HIPify + compile + install torch)
#   4) optional install_torchvision.bash -y --github|--pypi (matches custom torch; resnet needs torchvision)
#   5) install_triton.bash -y   (PyPI triton matching .ci/docker/triton_version.txt)
#   6) optional bisect_kernel_check.py
#
# Typical git bisect wrapper calls this with the current SHA already checked out;
# pass --ref only when you want this script to run git checkout itself.
#
# Always prints the "bisect_torch_step: done." line when finishing (including when the
# kernel check exits 1 for "bad"); final process exit follows bisect_kernel_check if it ran.
#
set -euo pipefail

BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTORCH_ROOT="${PYTORCH_ROOT:-$HOME/pytorch}"
CLEAN_TORCH="${CLEAN_TORCH:-$BIN/clean_torch.bash}"
INSTALL_TRITON="${INSTALL_TRITON:-$BIN/install_triton.bash}"
INSTALL_TORCHVISION="${INSTALL_TORCHVISION:-$BIN/install_torchvision.bash}"
DEFAULT_KERNEL="$BIN/../tests/resnet_perf/bisect_kernel_check.py"

usage() {
    echo "usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Runs from PYTORCH_ROOT (default: \$HOME/pytorch, override with PYTORCH_ROOT=)."
    echo
    echo "Options:"
    echo "  --just-clean-only     Only run clean_torch.bash --just-clean -y (reset tree + submodules)."
    echo "  --ref GIT_REF         After clean, git checkout GIT_REF (detached OK)."
    echo "  --skip-triton         After torch install, skip install_triton.bash -y."
    echo "  --torchvision MODE    After PyTorch: install_torchvision.bash -y; MODE is github or pypi."
    echo "                         For github+dev PyTorch (a0/git), TORCHVISION_GIT_REF=main is sensible (see install script)."
    echo "  --kernel-check        Run bisect_kernel_check.py after triton (see KERNEL_CHECK env)."
    echo "  --no-post-clean       Skip final clean_torch.bash --just-clean -y before exiting."
    echo "  -h, --help            Show this help."
    echo
    echo "Default flow: just-clean → optional checkout → clean_torch --yes → optional torchvision → triton → optional kernel check."
    echo "Kernel script default: $DEFAULT_KERNEL"
}

JUST_CLEAN_ONLY=false
GIT_REF=""
SKIP_TRITON=false
DO_KERNEL=false
POST_CLEAN=true
TORCHVISION_MODE=""
TORCHVISION_MATCH_BY_DATE_DEFAULT="${TORCHVISION_MATCH_BY_DATE_DEFAULT:-true}"

while [ $# -gt 0 ]; do
    case "$1" in
        --just-clean-only)
            JUST_CLEAN_ONLY=true
            shift
            ;;
        --ref)
            if [ $# -lt 2 ]; then echo "FATAL: --ref requires an argument"; exit 2; fi
            GIT_REF="$2"
            shift 2
            ;;
        --skip-triton)
            SKIP_TRITON=true
            shift
            ;;
        --kernel-check)
            DO_KERNEL=true
            shift
            ;;
        --torchvision)
            if [ $# -lt 2 ]; then echo "FATAL: --torchvision requires github or pypi"; exit 2; fi
            case "$2" in
                github|pypi) TORCHVISION_MODE="$2" ;;
                *)
                    echo "FATAL: --torchvision must be 'github' or 'pypi', got: $2"
                    exit 2
                    ;;
            esac
            shift 2
            ;;
        --no-post-clean)
            POST_CLEAN=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

if [ ! -d "$PYTORCH_ROOT" ]; then
    echo "FATAL: PYTORCH_ROOT is not a directory: $PYTORCH_ROOT"
    exit 1
fi
if [ ! -f "$PYTORCH_ROOT/setup.py" ]; then
    echo "FATAL: $PYTORCH_ROOT does not look like a PyTorch checkout (no setup.py)"
    exit 1
fi
if [ ! -x "$CLEAN_TORCH" ] && [ ! -f "$CLEAN_TORCH" ]; then
    echo "FATAL: clean_torch.bash not found: $CLEAN_TORCH"
    exit 1
fi

cd "$PYTORCH_ROOT"
echo ">>> [$PWD] clean_torch.bash --just-clean -y"
bash "$CLEAN_TORCH" --just-clean -y

if [ -n "$GIT_REF" ]; then
    echo ">>> git checkout $GIT_REF"
    git checkout "$GIT_REF"
fi

if [ "$JUST_CLEAN_ONLY" = true ]; then
    echo ">>> --just-clean-only: stopping before compile."
    echo ">>> bisect_torch_step: done. (exit 0)"
    exit 0
fi

echo ">>> clean_torch.bash --yes"
bash "$CLEAN_TORCH" --yes

if [ -n "$TORCHVISION_MODE" ]; then
    TV_EXTRA_ARGS=()
    if [ "$TORCHVISION_MATCH_BY_DATE_DEFAULT" = "true" ]; then
        TV_EXTRA_ARGS+=(--match-by-date)
    fi
    echo ">>> install_torchvision.bash -y --$TORCHVISION_MODE --no-audio ${TV_EXTRA_ARGS[*]}"
    bash "$INSTALL_TORCHVISION" -y "--$TORCHVISION_MODE" --no-audio "${TV_EXTRA_ARGS[@]}"
fi

if [ "$SKIP_TRITON" = false ]; then
    echo ">>> install_triton.bash -y (pin from \$PYTORCH_ROOT/.ci/docker/triton_version.txt if no arg)"
    PYTORCH_ROOT="$PYTORCH_ROOT" bash "$INSTALL_TRITON" -y
else
    echo ">>> skipping install_triton (--skip-triton)"
fi

# git bisect run: 0=good, 1–124 bad (≠125), 125=skip. Crashes often exit 128+N and abort bisect unless normalized.
FINAL_EXIT=0
KERNEL_RAW=0
if [ "$DO_KERNEL" = true ]; then
    KC="${KERNEL_CHECK:-$DEFAULT_KERNEL}"
    if [ ! -f "$KC" ]; then
        echo "FATAL: kernel check script not found: $KC"
        exit 1
    fi
    echo ">>> python3 $KC"
    python3 "$KC" || KERNEL_RAW=$?
    if [ "$KERNEL_RAW" -eq 0 ]; then
        FINAL_EXIT=0
    elif [ "$KERNEL_RAW" -eq 125 ]; then
        FINAL_EXIT=125
    else
        # bad mix (1), segfault, abort, OOM, etc. → tell bisect "bad"
        echo ">>> bisect_kernel_check raw exit: $KERNEL_RAW → bisect bad (1)" >&2
        FINAL_EXIT=1
    fi
fi

if [ "$POST_CLEAN" = true ]; then
    echo ">>> clean_torch.bash --just-clean -y (post-run)"
    bash "$CLEAN_TORCH" --just-clean -y || FINAL_EXIT=125
fi

echo ">>> bisect_torch_step: done."
if [ "$DO_KERNEL" = true ]; then
    echo ">>> bisect_kernel_check exit: raw=$KERNEL_RAW bisect_status=$FINAL_EXIT (0=good, 1=bad, 125=skip)"
fi
exit "$FINAL_EXIT"

