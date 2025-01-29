#!/bin/bash
## if you know the branch name (from github web UI) use this
git remote set-branches origin '*'
git fetch --shallow-since="4 weeks ago" origin $1
echo
echo please do 
echo git checkout $1
echo
