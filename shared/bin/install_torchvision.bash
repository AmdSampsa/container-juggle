#!/bin/bash
#
# TorchVision & TorchAudio installation (interactive or non-interactive).
# Non-interactive: use --github or --pypi (see --help).

set -euo pipefail

LOG_FILE="${TORCHVISION_LOG_FILE:-$HOME/torchvision_torchaudio_install.log}"

usage() {
    echo "usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Interactive: choose GitHub source build vs PyPI wheels (TorchVision + TorchAudio)."
    echo
    echo "Non-interactive (for bisect / automation):"
    echo "  -y, --yes              Required with --github or --pypi (skip menus)"
    echo "  --github               Build torchvision from github.com/pytorch/vision (auto-maps from torch version)."
    echo "  --pypi                 Install torchvision (+ torchaudio unless --no-audio) from PyTorch nightly index."
    echo "  --no-audio             Do not touch torchaudio: PyPI omits it; verify skips import (avoids crashes)."
    echo "  --with-torchaudio      With --github, also clone and build torchaudio (slow; default: vision only)."
    echo "  --github-ref REF       Checkout REF (branch/tag) for torchvision. Env: TORCHVISION_GIT_REF"
    echo "  --audio-ref REF        Checkout REF (branch/tag) for torchaudio. Env: TORCHAUDIO_GIT_REF"
    echo "  --match-by-date        Prefer nearest tag with date >= PYTORCH_ROOT HEAD; fallback to nearest older tag."
    echo "  --vision-dir DIR       Clone/build directory (default: \$HOME/torchvision)"
    echo "  --audio-dir DIR        torchaudio clone dir (default: \$HOME/torchaudio)"
    echo "  -h, --help             Show this help"
    echo
    echo "Logs append to: $LOG_FILE"
}

NON_INTERACTIVE=false
MODE=""
WITH_TORCHAUDIO=false
NO_TORCHAUDIO=false
VISION_DIR="${TORCHVISION_DIR:-$HOME/torchvision}"
AUDIO_DIR="${TORCHAUDIO_DIR:-$HOME/torchaudio}"
# Optional: branch/tag for --github (e.g. main for custom PyTorch git SHAs)
TORCHVISION_GIT_REF="${TORCHVISION_GIT_REF:-}"
TORCHAUDIO_GIT_REF="${TORCHAUDIO_GIT_REF:-}"
PYTORCH_ROOT="${PYTORCH_ROOT:-$HOME/pytorch}"
MATCH_BY_DATE="${TORCHVISION_MATCH_BY_DATE:-false}"
PYTORCH_COMMIT_TS=""

to_bool() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

get_pytorch_commit_ts() {
    if [ -n "$PYTORCH_COMMIT_TS" ]; then
        echo "$PYTORCH_COMMIT_TS"
        return 0
    fi
    if [ -d "$PYTORCH_ROOT/.git" ]; then
        PYTORCH_COMMIT_TS="$(git -C "$PYTORCH_ROOT" log -1 --format=%ct 2>/dev/null || true)"
    fi
    echo "$PYTORCH_COMMIT_TS"
}

closest_tag_by_date() {
    local target_ts="$1"
    local tag_regex="$2"
    local best_after_tag=""
    local best_after_diff=""
    local best_before_tag=""
    local best_before_diff=""
    local tag=""
    local tag_ts=""
    local diff=0

    while IFS= read -r tag; do
        [ -z "$tag" ] && continue
        tag_ts="$(git log -1 --format=%ct "${tag}^{commit}" 2>/dev/null || true)"
        [ -z "$tag_ts" ] && continue
        if [ "$tag_ts" -ge "$target_ts" ]; then
            diff=$((tag_ts - target_ts))
            if [ -z "$best_after_diff" ] || [ "$diff" -lt "$best_after_diff" ]; then
                best_after_diff="$diff"
                best_after_tag="$tag"
            fi
        else
            diff=$((target_ts - tag_ts))
            if [ -z "$best_before_diff" ] || [ "$diff" -lt "$best_before_diff" ]; then
                best_before_diff="$diff"
                best_before_tag="$tag"
            fi
        fi
    done < <(git tag | grep -E "$tag_regex" || true)

    if [ -n "$best_after_tag" ]; then
        echo "$best_after_tag"
        return 0
    fi
    [ -n "$best_before_tag" ] && echo "$best_before_tag"
}

# Map stable PyTorch 2.x.y -> torchvision 0.(x+15).y
# Examples: 2.4.1 -> 0.19.1, 2.5.0 -> 0.20.0, 2.10.0 -> 0.25.0
map_vision_from_torch_version() {
    local torch_ver="$1"
    local major minor patch
    if [[ "$torch_ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"
        if [ "$major" -eq 2 ]; then
            echo "0.$((minor + 15)).${patch}"
            return 0
        fi
    fi
    return 1
}

resolve_vision_ref() {
    local torch_ver="$1"
    local mapped=""
    local exact_tag=""
    local series_tag=""
    local latest_tag=""
    local mapped_minor=""
    local torch_ts=""
    local date_tag=""

    if to_bool "$MATCH_BY_DATE"; then
        torch_ts="$(get_pytorch_commit_ts)"
        if [ -n "$torch_ts" ]; then
            date_tag="$(closest_tag_by_date "$torch_ts" '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
            if [ -n "$date_tag" ]; then
                echo "$date_tag"
                return 0
            fi
        fi
    fi

    if mapped="$(map_vision_from_torch_version "$torch_ver")"; then
        exact_tag="v${mapped}"
        if git rev-parse -q --verify "refs/tags/${exact_tag}" >/dev/null; then
            echo "$exact_tag"
            return 0
        fi

        # If exact patch is missing, pick latest patch in the mapped minor series.
        mapped_minor="$(echo "$mapped" | sed -E 's/^0\.([0-9]+)\..*/\1/')"
        series_tag=$(git tag | grep -E "^v0\.${mapped_minor}\.[0-9]+$" | sort -V | tail -1 || true)
        if [ -n "$series_tag" ]; then
            echo "$series_tag"
            return 0
        fi
    fi

    # Fallback: latest stable release tag
    latest_tag=$(git tag | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true)
    if [ -n "$latest_tag" ]; then
        echo "$latest_tag"
        return 0
    fi

    return 1
}

resolve_audio_ref() {
    local torch_ver="$1"
    local major minor patch
    local exact_tag=""
    local series_tag=""
    local latest_tag=""
    local torch_ts=""
    local date_tag=""

    if to_bool "$MATCH_BY_DATE"; then
        torch_ts="$(get_pytorch_commit_ts)"
        if [ -n "$torch_ts" ]; then
            date_tag="$(closest_tag_by_date "$torch_ts" '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
            if [ -n "$date_tag" ]; then
                echo "$date_tag"
                return 0
            fi
        fi
    fi

    if [[ "$torch_ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"

        exact_tag="v${major}.${minor}.${patch}"
        if git rev-parse -q --verify "refs/tags/${exact_tag}" >/dev/null; then
            echo "$exact_tag"
            return 0
        fi

        # If exact patch is missing, pick latest patch in same major.minor.
        series_tag=$(git tag | grep -E "^v${major}\\.${minor}\\.[0-9]+$" | sort -V | tail -1 || true)
        if [ -n "$series_tag" ]; then
            echo "$series_tag"
            return 0
        fi
    fi

    # For dev/nightly torch builds, prefer torchaudio main over an arbitrary release tag.
    if echo "$torch_ver" | grep -qE 'a[0-9]|git|dev'; then
        echo "main"
        return 0
    fi

    latest_tag=$(git tag | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true)
    if [ -n "$latest_tag" ]; then
        echo "$latest_tag"
        return 0
    fi

    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) NON_INTERACTIVE=true; shift ;;
        --github) MODE="github"; shift ;;
        --pypi) MODE="pypi"; shift ;;
        --with-torchaudio) WITH_TORCHAUDIO=true; shift ;;
        --no-audio) NO_TORCHAUDIO=true; shift ;;
        --vision-dir)
            VISION_DIR="$2"
            shift 2
            ;;
        --audio-dir)
            AUDIO_DIR="$2"
            shift 2
            ;;
        --github-ref)
            TORCHVISION_GIT_REF="$2"
            shift 2
            ;;
        --audio-ref)
            TORCHAUDIO_GIT_REF="$2"
            shift 2
            ;;
        --match-by-date)
            MATCH_BY_DATE=true
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if [ -n "$MODE" ]; then
    if [ "$NON_INTERACTIVE" != true ]; then
        echo "FATAL: --github or --pypi requires -y / --yes" >&2
        exit 2
    fi
fi

install_vision_github() {
    echo "=========================================="
    echo "  TorchVision (GitHub, non-interactive)"
    echo "=========================================="

    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== TorchVision GitHub $(date) ===" >> "$LOG_FILE"

    if [ ! -d "$VISION_DIR/.git" ]; then
        echo "Cloning torchvision -> $VISION_DIR"
        git clone https://github.com/pytorch/vision.git "$VISION_DIR" 2>&1 | tee -a "$LOG_FILE"
    fi

    cd "$VISION_DIR"
    git fetch --all --tags 2>&1 | tee -a "$LOG_FILE"

    TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__.split('+')[0])")
    echo "PyTorch version (base): $TORCH_VERSION"
    if to_bool "$MATCH_BY_DATE"; then
        PYTORCH_COMMIT_TS="$(get_pytorch_commit_ts)"
        if [ -n "$PYTORCH_COMMIT_TS" ]; then
            echo "Date-based tag match enabled (PyTorch HEAD timestamp: $PYTORCH_COMMIT_TS)"
        else
            echo "Date-based tag match requested, but no git checkout found at PYTORCH_ROOT=$PYTORCH_ROOT; falling back to version-based mapping."
        fi
    fi

    if [ -n "$TORCHVISION_GIT_REF" ]; then
        echo "Using explicit torchvision ref: $TORCHVISION_GIT_REF (--github-ref or TORCHVISION_GIT_REF)"
        git checkout "$TORCHVISION_GIT_REF" 2>&1 | tee -a "$LOG_FILE"
    else
        MATCHING_TAG="$(resolve_vision_ref "$TORCH_VERSION" || true)"
        if [ -n "$MATCHING_TAG" ]; then
            echo "Resolved torchvision ref from torch $TORCH_VERSION -> $MATCHING_TAG"
            git checkout "$MATCHING_TAG" 2>&1 | tee -a "$LOG_FILE"
        else
            echo "Could not resolve a torchvision release tag from torch $TORCH_VERSION; falling back to main."
            git checkout main 2>&1 | tee -a "$LOG_FILE"
            git pull --ff-only 2>&1 | tee -a "$LOG_FILE" || true
        fi
    fi

    # Clean previous build artifacts so _C is always rebuilt against the current torch ABI.
    rm -rf build dist ./*.egg-info torchvision.egg-info 2>/dev/null || true
    python3 - <<'PY' 2>/dev/null || true
import glob, os
for so in glob.glob("torchvision/*.so"):
    try:
        os.remove(so)
    except OSError:
        pass
PY

    pip uninstall -y torchvision 2>/dev/null || true
    echo "pip install torchvision (from source, force clean rebuild)..."
    pip install -v --force-reinstall --no-cache-dir --no-deps . --no-build-isolation --progress-bar off 2>&1 | tee -a "$LOG_FILE"
}

install_audio_github() {
    echo "=========================================="
    echo "  TorchAudio (GitHub, non-interactive)"
    echo "=========================================="
    echo "=== TorchAudio GitHub $(date) ===" >> "$LOG_FILE"

    if [ ! -d "$AUDIO_DIR/.git" ]; then
        echo "Cloning torchaudio -> $AUDIO_DIR"
        git clone https://github.com/pytorch/audio.git "$AUDIO_DIR" 2>&1 | tee -a "$LOG_FILE"
    fi

    cd "$AUDIO_DIR"
    git fetch --all --tags 2>&1 | tee -a "$LOG_FILE"

    TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__.split('+')[0])")
    if to_bool "$MATCH_BY_DATE"; then
        PYTORCH_COMMIT_TS="$(get_pytorch_commit_ts)"
    fi
    if [ -n "$TORCHAUDIO_GIT_REF" ]; then
        MATCHING_TAG="$TORCHAUDIO_GIT_REF"
        echo "Using explicit torchaudio ref: $MATCHING_TAG (--audio-ref or TORCHAUDIO_GIT_REF)"
    else
        MATCHING_TAG="$(resolve_audio_ref "$TORCH_VERSION" || true)"
        if [ -z "$MATCHING_TAG" ]; then
            echo "FATAL: could not resolve torchaudio ref from torch $TORCH_VERSION" >&2
            return 1
        fi
        echo "Resolved torchaudio ref from torch $TORCH_VERSION -> $MATCHING_TAG"
    fi
    git checkout "$MATCHING_TAG" 2>&1 | tee -a "$LOG_FILE"
    if [ "$MATCHING_TAG" = "main" ]; then
        git pull --ff-only 2>&1 | tee -a "$LOG_FILE" || true
    fi
    git submodule update --init --recursive 2>&1 | tee -a "$LOG_FILE"

    # Clean previous torchaudio build artifacts so extension modules are rebuilt
    # against the current torch ABI.
    rm -rf build dist ./*.egg-info torchaudio.egg-info 2>/dev/null || true
    python3 - <<'PY' 2>/dev/null || true
import glob, os
for so in glob.glob("torchaudio/**/*.so", recursive=True):
    try:
        os.remove(so)
    except OSError:
        pass
PY

    pip uninstall -y torchaudio 2>/dev/null || true
    echo "pip install torchaudio (from source, force clean rebuild)..."
    pip install -v --force-reinstall --no-cache-dir --no-deps . --no-build-isolation --progress-bar off 2>&1 | tee -a "$LOG_FILE"
}

install_pypi_wheels() {
    echo "=========================================="
    echo "  TorchVision / TorchAudio (PyPI nightly, non-interactive)"
    echo "=========================================="
    echo "=== PyPI nightly $(date) ===" >> "$LOG_FILE"

    pip uninstall -y torchvision 2>/dev/null || true
    if [ "$NO_TORCHAUDIO" != true ]; then
        pip uninstall -y torchaudio 2>/dev/null || true
    fi

    PKGS="torchvision"
    if [ "$NO_TORCHAUDIO" != true ]; then
        PKGS="torchvision torchaudio"
    fi

    if command -v nvidia-smi &> /dev/null; then
        cuda_version=$(nvidia-smi | grep "CUDA Version" | sed -n 's/.*CUDA Version: \([0-9]*\.[0-9]*\).*/\1/p' || true)
        cuda_url_version="cu$(echo "$cuda_version" | sed 's/\.//')"
        echo "NVIDIA: using index nightly/$cuda_url_version (packages: $PKGS)"
        pip3 install --no-deps --pre $PKGS --index-url "https://download.pytorch.org/whl/nightly/$cuda_url_version" 2>&1 | tee -a "$LOG_FILE"
    elif [ -d "/opt/rocm" ]; then
        rocm_full_version=$(readlink -f /opt/rocm | sed 's/.*rocm-//')
        rocm_short_version=$(echo "$rocm_full_version" | sed -E 's/([0-9]+\.[0-9]+).*/\1/')
        rocm_url_version="rocm${rocm_short_version}"
        echo "ROCm: using index nightly/$rocm_url_version (packages: $PKGS)"
        pip3 install --no-deps --pre $PKGS --index-url "https://download.pytorch.org/whl/nightly/$rocm_url_version" 2>&1 | tee -a "$LOG_FILE"
    else
        echo "No NVIDIA/ROCm detected; CPU nightly index"
        pip3 install --no-deps --pre $PKGS --index-url https://download.pytorch.org/whl/nightly/cpu 2>&1 | tee -a "$LOG_FILE"
    fi
}

verify_imports() {
    echo
    echo "=========================================="
    echo "  Verifying Installation"
    echo "=========================================="
    # Run from /tmp so we do not import the local ./torchvision/ tree from the git clone CWD.
    # From inside $VISION_DIR, "import torchvision" can shadow site-packages and crash (mixed .so + source).
    ( cd /tmp && python3 -c "import torch; print('  torch:', torch.__version__)" ) || echo "  torch: FAILED"
    ( cd /tmp && python3 -c "
import warnings
warnings.filterwarnings('ignore')
try:
    import torchvision
    print('  torchvision:', torchvision.__version__)
except BaseException as e:
    print('  torchvision: FAILED (verify only):', repr(e))
    raise SystemExit(0)
" )
    if [ "$NO_TORCHAUDIO" = true ]; then
        echo "  torchaudio: skipped (--no-audio)"
    else
        ( cd /tmp && python3 -c "
try:
    import torchaudio
    print('  torchaudio:', torchaudio.__version__)
except BaseException as e:
    print('  torchaudio: not installed or failed:', repr(e))
" ) || true
    fi
    echo "=========================================="
    echo "Log file: $LOG_FILE"
}

# ------------------------------------------------------------
# Non-interactive entry
# ------------------------------------------------------------
if [ -n "$MODE" ]; then
    case "$MODE" in
        github)
            install_vision_github
            if [ "$WITH_TORCHAUDIO" = true ]; then
                install_audio_github
            fi
            verify_imports
            exit 0
            ;;
        pypi)
            install_pypi_wheels
            verify_imports
            exit 0
            ;;
    esac
fi

# ------------------------------------------------------------
# Interactive (original behaviour)
# ------------------------------------------------------------
echo "=========================================="
echo "  TorchVision & TorchAudio Installation"
echo "=========================================="
echo
echo "Log file: $LOG_FILE"
echo
echo "1) Install from GitHub (build from source)"
echo "   - Use this if you have a custom PyTorch build"
echo "2) Install from PyPI (pre-built wheel)"
echo "   - Use this for standard PyTorch installations"
echo
read -p "Select installation method (1 or 2): " choice

echo "=== TorchVision & TorchAudio Installation ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

case $choice in
    1)
        echo
        echo "=========================================="
        echo "  Building from Source"
        echo "=========================================="
        echo
        echo "This will compile against your current PyTorch:"
        python3 -c "import torch; print(f'  PyTorch: {torch.__version__}')"
        python3 -c "import torch; print(f'  Location: {torch.__file__}')"
        echo
        
        echo "----------------------------------------"
        echo "  Step 1/2: TorchVision"
        echo "----------------------------------------"
        
        VISION_DIR="$HOME/torchvision"
        
        if [ -d "$VISION_DIR" ]; then
            echo "Existing torchvision directory found."
            read -p "Remove and re-clone? (y/n): " reclone_vision
            if [ "$reclone_vision" = "y" ] || [ "$reclone_vision" = "Y" ]; then
                rm -rf "$VISION_DIR"
            fi
        fi
        
        if [ ! -d "$VISION_DIR" ]; then
            echo "Cloning torchvision..."
            git clone https://github.com/pytorch/vision.git "$VISION_DIR" 2>&1 | tee -a "$LOG_FILE"
        fi
        
        cd "$VISION_DIR" || exit 1
        
        echo "Fetching tags and branches..."
        git fetch --all --tags 2>&1 | tee -a "$LOG_FILE"
        
        TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__.split('+')[0])")
        echo "PyTorch version: $TORCH_VERSION"
        
        MATCHING_TAG="$(resolve_vision_ref "$TORCH_VERSION" || true)"
        if [ -z "$MATCHING_TAG" ]; then
            echo "Could not resolve a release tag from torch $TORCH_VERSION; using main."
            MATCHING_TAG="main"
        fi
        
        echo "Using torchvision tag: $MATCHING_TAG"
        git checkout "$MATCHING_TAG" 2>&1 | tee -a "$LOG_FILE"
        
        echo "Uninstalling existing torchvision..."
        pip uninstall -y torchvision 2>&1 | tee -a "$LOG_FILE"
        
        echo "Building torchvision from source..."
        echo "Build started: $(date)" >> "$LOG_FILE"
        pip install --no-deps . --no-build-isolation --progress-bar off 2>&1 | tee -a "$LOG_FILE"
        VISION_STATUS=${PIPESTATUS[0]}
        
        if [ $VISION_STATUS -eq 0 ]; then
            echo "✓ TorchVision built successfully!"
        else
            echo "✗ TorchVision build failed!"
            echo "Check log: $LOG_FILE"
        fi
        
        echo
        echo "----------------------------------------"
        echo "  Step 2/2: TorchAudio"
        echo "----------------------------------------"
        
        AUDIO_DIR="$HOME/torchaudio"
        
        if [ -d "$AUDIO_DIR" ]; then
            echo "Existing torchaudio directory found."
            read -p "Remove and re-clone? (y/n): " reclone_audio
            if [ "$reclone_audio" = "y" ] || [ "$reclone_audio" = "Y" ]; then
                rm -rf "$AUDIO_DIR"
            fi
        fi
        
        if [ ! -d "$AUDIO_DIR" ]; then
            echo "Cloning torchaudio..."
            git clone https://github.com/pytorch/audio.git "$AUDIO_DIR" 2>&1 | tee -a "$LOG_FILE"
        fi
        
        cd "$AUDIO_DIR" || exit 1
        
        echo "Fetching tags and branches..."
        git fetch --all --tags 2>&1 | tee -a "$LOG_FILE"
        
        TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__.split('+')[0])")
        echo "PyTorch version: $TORCH_VERSION"
        
        MATCHING_TAG="$(resolve_audio_ref "$TORCH_VERSION" || true)"
        if [ -z "$MATCHING_TAG" ]; then
            echo "Could not resolve torchaudio tag from torch $TORCH_VERSION; using main."
            MATCHING_TAG="main"
        fi
        
        echo "Using torchaudio tag: $MATCHING_TAG"
        git checkout "$MATCHING_TAG" 2>&1 | tee -a "$LOG_FILE"
        
        echo "Initializing submodules..."
        git submodule update --init --recursive 2>&1 | tee -a "$LOG_FILE"
        
        echo "Uninstalling existing torchaudio..."
        pip uninstall -y torchaudio 2>&1 | tee -a "$LOG_FILE"
        
        echo "Building torchaudio from source..."
        echo "Build started: $(date)" >> "$LOG_FILE"
        python setup.py install 2>&1 | tee -a "$LOG_FILE"
        AUDIO_STATUS=${PIPESTATUS[0]}
        
        if [ $AUDIO_STATUS -eq 0 ]; then
            echo "✓ TorchAudio built successfully!"
        else
            echo "✗ TorchAudio build failed!"
            echo "Check log: $LOG_FILE"
        fi
        
        echo
        echo "=========================================="
        echo "  Build Summary"
        echo "=========================================="
        [ $VISION_STATUS -eq 0 ] && echo "  TorchVision: ✓ SUCCESS" || echo "  TorchVision: ✗ FAILED"
        [ $AUDIO_STATUS -eq 0 ] && echo "  TorchAudio:  ✓ SUCCESS" || echo "  TorchAudio:  ✗ FAILED"
        echo "=========================================="
        ;;
        
    2)
        echo
        echo "Installing from PyPI (pre-built wheels)..."
        echo
        
        if command -v nvidia-smi &> /dev/null; then
            echo "Detected NVIDIA GPU system"
            
            cuda_version=$(nvidia-smi | grep "CUDA Version" | sed -n 's/.*CUDA Version: \([0-9]*\.[0-9]*\).*/\1/p')
            echo "Detected CUDA version: $cuda_version"
            
            cuda_url_version="cu$(echo $cuda_version | sed 's/\.//')"
            echo "Using CUDA URL version: $cuda_url_version"
            echo
            
            pip3 install --no-deps --pre torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/$cuda_url_version 2>&1 | tee -a "$LOG_FILE"
            
        elif [ -d "/opt/rocm" ]; then
            echo "Detected AMD ROCm system"
            
            rocm_full_version=$(readlink -f /opt/rocm | sed 's/.*rocm-//')
            echo "Detected ROCm version: $rocm_full_version"
            
            rocm_short_version=$(echo "$rocm_full_version" | sed -E 's/([0-9]+\.[0-9]+).*/\1/')
            rocm_url_version="rocm${rocm_short_version}"
            
            echo "Using ROCm URL version: $rocm_url_version"
            echo
            
            pip3 install --no-deps --pre torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/$rocm_url_version 2>&1 | tee -a "$LOG_FILE"
            
        else
            echo "WARNING: Could not detect GPU type (neither NVIDIA nor AMD ROCm found)"
            echo "Falling back to CPU-only installation..."
            echo
            pip3 install --no-deps --pre torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cpu 2>&1 | tee -a "$LOG_FILE"
        fi
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

verify_imports

