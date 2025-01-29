#!/bin/bash
echo
echo Getting latest pytorch main from YOUR repo $gituser
echo
#read -p "press any key to continue.."
# echo
# cd $HOME
# git clone git@github.com:$gituser/pytorch.git $HOME/pytorch-me
git clone --shallow-since="4 weeks ago" git@github.com:$gituser/pytorch.git $HOME/pytorch-me
# NOTE: you can always git fetch --unshallow
echo
#cd pytorch
#echo "Status:"
#git remote -v
#echo
