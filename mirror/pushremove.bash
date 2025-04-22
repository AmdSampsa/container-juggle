#!/bin/bash
echo
echo PUSHREMOVE
echo
echo PORT:$sshport USERNAME:$username HOSTNAME:$hostname
echo
## use at CLIENT
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" --delete --exclude "**/.git" -uvr $HOME/mirror/ $username@$hostname:mirror/ & \
# rsync --delete -uv $HOME/shared/* $username@$hostname:shared/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" --delete -uvr --exclude "**/.*" --exclude "**/.git" --include="*.py" --include="*.ipynb" --include="*/" --exclude="*" $HOME/shared/notebook/ $username@$hostname:shared/notebook/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" --delete -uvr --exclude "**/.*" --exclude "**/.git"--include="*.py" --include="*.ipynb" --include="*/" --exclude="*" $HOME/shared/script/ $username@$hostname:shared/script/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" --delete -uvr --exclude "**/.*" --include="*.py" --include "*.txt" --include "*.csv" --include "*.json" --include "*.md" --include "*.bash" --include "*.sh" --include="*/" --exclude="*" $HOME/shared/tests/ $username@$hostname:shared/tests/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" --delete -uvr --exclude "**/.*" --exclude "**/.git" $HOME/shared/bin/ $username@$hostname:shared/bin/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" --delete -uvr --exclude "**/.*" --exclude "**/.git" $HOME/shared/env/ $username@$hostname:shared/env/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" --delete -uvr --exclude "**/.*" --exclude "**/.git" $HOME/shared/pythonenv/* $username@$hostname:shared/pythonenv/ &
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no -o BatchMode=yes" --delete -uvr --include="*.json" --exclude="*"  $HOME/shared/ $username@$hostname:shared/
