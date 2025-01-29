#!/bin/bash
echo
echo NOTE: THIS IS NOT FOR PRE-COMPILATION CLEANING
echo If you want to compile, run clean_torch.bash instead
echo
read -n 1 -p "Press any key to continue..." key
## run this to clean any trace of a previous install and compilation of pytorch
## you need to be in /tmp/pytorch or /var/lib/jenkins/pytorch
git reset --hard
git clean -fd
git submodule foreach --recursive 
# git reset --hard 
## stubborn kineto..
git submodule deinit -f third_party/kineto
git submodule update --init --recursive third_party/kineto
git submodule update --init --recursive third_party/composable_kernel
# Simply remove the directory if you don't need it
rm -rf third_party/x86-simd-sort/
# ok.. status should now show complete clean and synced with the desired branch
echo 
echo "GIT STATUS:"
git status
echo
