#!/bin/bash
if [ -z "$1" ]; then
    echo "Error: release tag missing"
    exit 1
fi
echo
echo Getting pytorch release $1
#echo
#read -p "press any key to continue.."
echo
# cd $HOME
git clone --depth 1 -b release/$1 git@github.com:pytorch/pytorch.git $HOME/pytorch-$1
# git clone --shallow-since="4 weeks ago" -b release/$1 git@github.com:pytorch/pytorch.git $HOME/pytorch-$1
# NOTE: you can always git fetch --unshallow
echo
#cd pytorch
#echo "Status:"
#git remote -v
#echo
