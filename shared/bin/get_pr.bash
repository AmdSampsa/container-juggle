#!/bin/bash
# Fetch the specific PR
git fetch origin pull/$1/head:pr-$1
# Check out the branch you just created
git checkout pr-$1
