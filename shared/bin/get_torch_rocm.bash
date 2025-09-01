#!/bin/bash
#if [ -z "$1" ]; then
#    echo "Error: release tag missing"
#    exit 1
#fi
echo
echo Getting pytorch rocm
#echo
#read -p "press any key to continue.."
echo
# cd $HOME
#
# git clone --depth 1 git@github.com:pytorch/pytorch.git $HOME/pytorch-main
# git clone --shallow-since="4 weeks ago" git@github.com:pytorch/pytorch.git $HOME/pytorch-main
# git clone --shallow-since="2 years ago" git@github.com:ROCm/pytorch.git $HOME/pytorch-rocm
## usually we go to some custom branch so shallow clones are a problem..
git clone git@github.com:ROCm/pytorch.git $HOME/pytorch-rocm
#cd $HOME/pytorch-rocm
#git fetch --all --tags
# NOTE: if shallow clones gives problems you can always:
# git fetch --unshallow && git fetch --all
echo
#cd pytorch
#echo "Status:"
#git remote -v
#echo
## TIP:
## to get a certain PR
## git fetch upstream pull/151368/head:rocm64
## that creates local branch "rocm64"
##
## go to a certain release
## git fetch origin release/2.7:release/2.7
## git checkout release/2.7
