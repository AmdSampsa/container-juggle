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
do_rsync --exclude "**/.*" $HOME/mirror/* $username@$hostname:mirror/ & \
do_rsync --exclude "**/.*" $HOME/shared/* $username@$hostname:shared/ & \
do_rsync --exclude "**/.*" --exclude="**/.ipynb_checkpoints/" --include="*.py" --include="*.ipynb" --include="*/" --exclude="*" $HOME/shared/notebook/ $username@$hostname:shared/notebook/ & \
do_rsync --exclude "**/.*" --exclude="**/.ipynb_checkpoints/" --include="*.py" --include="*.ipynb" --include="*/" --exclude="*" $HOME/shared/script/ $username@$hostname:shared/script/ & \
# NOTE: not syncing SAVED dirs
do_rsync --exclude "**/.*" --exclude "SAVED" --include="*.py" "${include_txt[@]}" $HOME/shared/tests/ $username@$hostname:shared/tests/ & \
do_rsync --exclude "**/.*" $HOME/shared/bin/* $username@$hostname:shared/bin/ & \
do_rsync $HOME/shared/secret/ $username@$hostname:shared/secret/ & \
do_rsync --include="*.json" --exclude="*"  $HOME/shared/ $username@$hostname:shared/  & \
do_rsync --exclude "**/__pycache__" --exclude "**/.*" $HOME/shared/pythonenv/* $username@$hostname:shared/pythonenv/ &
