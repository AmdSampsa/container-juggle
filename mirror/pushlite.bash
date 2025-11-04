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
do_rsync --exclude "**/.*" $HOME/shared/* $username@$hostname:shared/
