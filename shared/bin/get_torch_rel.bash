#!/bin/bash
if [ -z "$1" ]; then
    echo "Error: release tag missing"
    exit 1
fi
if [ -z "$2" ]; then
    source="ROCm"
else
    source=$2
fi

echo
echo Getting pytorch release $1 WARNING: from $source
#echo
#read -p "press any key to continue.."
echo
# cd $HOME
git clone --shallow-since="2 years ago" -b release/$1 git@github.com:$source/pytorch.git $HOME/pytorch-$1${2:+-$2}
cd $HOME/pytorch-$1${2:+-$2}
git branch my-branch
git checkout my-branch
# git clone --shallow-since="4 weeks ago" -b release/$1 git@github.com:pytorch/pytorch.git $HOME/pytorch-$1
# NOTE: you can always git fetch --unshallow
echo
#cd pytorch
#echo "Status:"
#git remote -v
#echo
