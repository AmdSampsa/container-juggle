#!/bin/bash

do_rsync() {
    rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" -uvr --delete --max-size=1M "$@"
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

echo
echo PUSHREMOVE
echo
echo PORT:$sshport USERNAME:$username HOSTNAME:$hostname
echo
## use at CLIENT
do_rsync --exclude "**/.*" --exclude "**/.git" $HOME/mirror/* $username@$hostname:mirror/ & \
do_rsync -uvr --exclude "**/.*" --exclude "**/.git" $HOME/shared/bin/ $username@$hostname:shared/bin/ &
