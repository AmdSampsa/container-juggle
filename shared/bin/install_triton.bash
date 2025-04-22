#!/bin/bash
# cd /tmp/
if [ -z "$1" ]; then
    echo
    echo "Error: release tag or commit missing"
    echo "Input argument, either just the release tag, i.e.:"
    echo "   3.2.x"
    echo "or define commit with:"
    echo "   --commit HASH"
    echo "or TOT with:"
    echo "   --head"
    exit 1
fi
# git clone https://github.com/triton-lang/triton
if [ ! -d "$HOME/triton" ]; then
    echo
    #echo "cloning, but only since 4 weeks - use git fetch --unshallow to fix that"
    # echo
    # git clone --shallow-since="4 weeks ago" https://github.com/triton-lang/triton "$HOME/triton"
    git clone https://github.com/triton-lang/triton "$HOME/triton"
fi
cd $HOME/triton

if [ "$1" = "--head" ]; then
    git checkout main
    git pull
    echo
    echo TOT
    echo
    git reset --hard HEAD
elif [ "$1" = "--commit" ]; then
    if [ -n "$2" ]; then
        HASH="$2"
        echo "commit: $HASH"
    else
        echo "Error: No hash provided after --commit"
        exit 1
    fi
    git checkout $HASH
else
    git checkout main
    git pull
    git checkout release/$1
    git pull
    if [ $? -ne 0 ]; then
        echo "Command failed"
        echo "NOTE: release tags are for example: 3.2.x (not 3.2.0 etc.)"
        exit 1
    fi
fi
cd $HOME/triton/python
pip uninstall -y triton && pip uninstall -y pytorch-triton-rocm && rm -rf ~/.triton
pip install .
#cd triton/python # uh.. would need source to this to work
#echo "NOTE: your compatible triton version can be found in pytorch/.ci/docker/triton_version.txt" 
#echo "now do:"
#echo "cd triton/python"
#echo "git checkout commit-id"
#echo "or you probably want:"
#echo "git checkout release/3.1.x"
#echo "..or just the main (aka tip of triton)"
#echo "after that (NOTE: you are in triton/python/, not in the triton/ directory):"
#echo "pip install ."
#echo
