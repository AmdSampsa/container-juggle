#!/bin/bash
## use at CLIENT
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --exclude "**/.*" $HOME/mirror/* $username@$hostname:mirror/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uv  --exclude "**/.*" $HOME/shared/* $username@$hostname:shared/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --exclude "**/.*" --exclude="**/.ipynb_checkpoints/" --include="*.py" --include="*.ipynb" --include="*/" --exclude="*" $HOME/shared/notebook/ $username@$hostname:shared/notebook/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --exclude "**/.*" --exclude="**/.ipynb_checkpoints/" --include="*.py" --include="*.ipynb" --include="*/" --exclude="*" $HOME/shared/script/ $username@$hostname:shared/script/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --exclude "**/.*" --include="*.py" --include "*.txt" --include "*.csv" --include "*.json" --include "*.md" --include "*.bash" --include "*.sh" --include="*/" --exclude="*" $HOME/shared/tests/ $username@$hostname:shared/tests/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uv  --exclude "**/.*" $HOME/shared/bin/* $username@$hostname:shared/bin/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --exclude "**/.*" $HOME/shared/env/* $username@$hostname:shared/env/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --include="*.json" --exclude="*"  $HOME/shared/ $username@$hostname:shared/  & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --exclude "**/__pycache__" --exclude "**/.*" $HOME/shared/pythonenv/* $username@$hostname:shared/pythonenv/ &
