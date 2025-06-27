#!/bin/bash
## if you know the branch name (from github web UI) use this
# Check if all arguments are provided
if [ $# -ne 1 ]; then
    echo "please provide branch name"
    exit 1
fi
git remote set-branches origin '*'
# git fetch --shallow-since="2 years ago" origin $1
git fetch origin $1
echo
echo please do 
echo git checkout $1
echo
## NOTE: another possibility would be to use:
## git fetch origin release/2.7:release/2.7
