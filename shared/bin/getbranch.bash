#!/bin/bash
## fetch someone else's branch
## usage: repo-name username
##
git remote add $2 https://github.com/$2/$1.git
git fetch $2
