#!/bin/bash
## use at CLIENT
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr $username@$hostname:mirror/* $HOME/mirror/ & \
# rsync -uv $username@$hostname:shared/* $HOME/shared/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --include="*.py" --exclude "**/torch_compile_debug/" --exclude "**/.*" --exclude "**/res_cache/" --exclude="**/.ipynb_checkpoints/" --exclude="**/__pycache__" --include="*.ipynb" --include="*/" --exclude="*" $username@$hostname:shared/notebook/ $HOME/shared/notebook/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --include="*.py" --exclude "**/torch_compile_debug/" --exclude "**/.*" --exclude "**/res_cache/" --exclude="**/.ipynb_checkpoints/" --exclude="**/__pycache__" --include="*.ipynb" --include="*/" --exclude="*" $username@$hostname:shared/script/ $HOME/shared/script/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --include="*.py" --exclude "**/torch_compile_debug/" --exclude "**/.*" --exclude "**/res_cache/" --exclude="**/__pycache__"  --include="*/" --include "*.txt" --include "*.bash" --include "*.csv" --include "*.json" --include "*.md" --exclude="*"  $username@$hostname:shared/tests/ $HOME/shared/tests/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --include="*.json" --exclude="*"  $username@$hostname:shared/ $HOME/shared/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uv --exclude "**/.*" $username@$hostname:shared/bin/* $HOME/shared/bin/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --exclude "**/.*" $username@$hostname:shared/env/* $HOME/shared/env/ & \
rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --exclude "**/__pycache__" --exclude "**/.*" $username@$hostname:shared/pythonenv/* $HOME/shared/pythonenv/ &
