#!/bin/bash
#if [ -z "$1" ]; then
#    echo "Error: release tag missing"
#    exit 1
#fi
echo
echo Getting pytorch main
#echo
#read -p "press any key to continue.."
echo
# cd $HOME
#
# git clone --depth 1 git@github.com:pytorch/pytorch.git $HOME/pytorch-main
# git clone --shallow-since="2 years ago" git@github.com:pytorch/pytorch.git $HOME/pytorch-main
git clone git@github.com:pytorch/pytorch.git $HOME/pytorch-main
# NOTE: you can always git fetch --unshallow
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
