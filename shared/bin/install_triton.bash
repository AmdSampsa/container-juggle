#!/bin/bash
# cd /tmp/

# Initialize variables
commit=""
tag=""
source="triton-lang"
di=""

# Parse command line arguments
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    
    case "$arg" in
        --commit=*)
            commit="${arg#*=}"  # Remove everything up to and including the = sign
            ;;
        --commit)
            if [ $((i+1)) -le $# ]; then
                i=$((i+1))
                commit="${!i}"
            else
                echo "Error: --commit requires a value"
                exit 1
            fi
            ;;
        --head)
            commit="head"
            ;;
        -*)
            echo "Error: Unknown option $arg"
            exit 1
            ;;
        *)
            # First non-option argument could be a tag or source
            if [ -z "$tag" ] && [ -z "$commit" ]; then
                # If we haven't seen a commit or tag yet, treat this as a tag
                tag="$arg"
            elif [ "$source" = "triton-lang" ]; then
                # If we have seen a tag or commit, and source is still default, update source
                source="$arg"
            else
                echo "Error: Too many arguments"
                exit 1
            fi
            ;;
    esac
    
    i=$((i+1))
done

# Check if we have a tag or commit
if [ -z "$tag" ] && [ -z "$commit" ]; then
    echo
    echo "Error: release tag or commit missing"
    echo "Input argument, either just the release tag, i.e.:"
    echo "   3.2.x"
    echo "or define commit with:"
    echo "   --commit HASH"
    echo "   --commit=HASH"
    echo "or TOT with:"
    echo "   --head"
    exit 1
fi

# Set the destination directory
if [ "$source" = "triton-lang" ]; then
    di="$HOME/triton"
else
    di="$HOME/triton-$source"
fi

# Clone repository if it doesn't exist
if [ ! -d "$di" ]; then
    echo
    git clone --shallow-since="3 months ago" "https://github.com/$source/triton" "$di"
    ## shallow clone not a good idea!  messes all up
    ## shallow cloning with branches and tags might work with this:
    ## -> ok now it works with the below fix
    #git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    #git fetch --all
    # git clone "https://github.com/$source/triton" "$di"
fi
cd "$di"

git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch --all

# Handle the different checkout options
if [ "$commit" = "head" ]; then
    git checkout main
    git pull
    echo
    echo "TOT"
    echo
    git reset --hard HEAD
elif [ -n "$commit" ]; then
    echo "Checking out commit: $commit"
    git checkout "$commit"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to checkout commit $commit"
        exit 1
    fi
elif [ -n "$tag" ]; then
    git checkout main
    git pull
    git checkout "release/$tag"
    git pull
    if [ $? -ne 0 ]; then
        echo "Command failed"
        echo "NOTE: release tags are for example: 3.2.x (not 3.2.0 etc.)"
        exit 1
    fi
fi

# Install the package
cd "$di/python"
pip uninstall -y triton && pip uninstall -y pytorch-triton-rocm && rm -rf ~/.triton
pip install .
