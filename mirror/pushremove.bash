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
do_rsync --exclude "**/.*" --exclude "**/.git" $HOME/shared/* $username@$hostname:shared/ & \
do_rsync -uvr --exclude "**/.*" --exclude "**/.git" --include="*.py" --include="*.ipynb" --include="*/" --exclude="*" $HOME/shared/notebook/ $username@$hostname:shared/notebook/ & \
do_rsync -uvr --exclude "**/.*" --exclude "**/.git" --include="*.py" --include="*.ipynb" --include="*/" --exclude="*" $HOME/shared/script/ $username@$hostname:shared/script/ & \
# NOTE: not syncing "SAVED"
do_rsync -uvr --exclude "**/.*" --exclude "SAVED" --include="*.py"  "${include_txt[@]}" $HOME/shared/tests/ $username@$hostname:shared/tests/ & \
do_rsync -uvr --exclude "**/.*" --exclude "**/.git" $HOME/shared/bin/ $username@$hostname:shared/bin/ & \
do_rsync $HOME/shared/secret/ $username@$hostname:shared/secret/ & \
do_rsync -uvr --include="*.json" --exclude="*"  $HOME/shared/ $username@$hostname:shared/ & \
do_rsync -uvr --exclude "**/.*" --exclude "**/.git" $HOME/shared/pythonenv/* $username@$hostname:shared/pythonenv/ &
