#!/bin/bash

do_rsync() {
    rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --max-size=1M "$@"
}

include_txt=(
    --include="*/" 
    --include="*.txt" 
    --include="*.bash" 
    --include="*.sh" 
    --include="*.csv" 
    --include="*.json" 
    --include="*.md" 
    --exclude="*"
)

## use at CLIENT
do_rsync --exclude "**/.*" $HOME/mirror/* $username@$hostname:mirror/
## Shared - only specific directories tests/ -> no recursion to subdirs
do_rsync --exclude "**/.*" \
    --include="bin/" \
    --include="bin/**" \
    --include="pythonenv/" \
    --include="pythonenv/*" \
    --include="tests/" \
        --include="tests/*" \
    --include="tests/*/*" \
    --exclude="tests/*/*/" \
    --exclude="*" \
    $HOME/shared/ $username@$hostname:shared/
