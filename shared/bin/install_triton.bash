#!/bin/bash
# cd /tmp/
if [ -z "$1" ]; then
    echo "Error: release tag missing"
    exit 1
fi
# git clone https://github.com/triton-lang/triton
if [ ! -d "$HOME/triton" ]; then
    git clone --depth 1 --no-single-branch https://github.com/triton-lang/triton "$HOME/triton"
fi
cd $HOME/triton
git checkout release/$1
if [ $? -ne 0 ]; then
    echo "Command failed"
    echo "NOTE: release tags are for example: 3.2.x (not 3.2.0 etc.)"
    exit 1
fi
cd $HOME/triton/python
pip uninstall -y triton && pip uninstall -y pytorch-triton_rocm
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
