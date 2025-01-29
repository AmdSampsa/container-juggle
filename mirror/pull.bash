#!/bin/bash
## use at CLIENT
rsync -e "ssh -p $sshport" -uvr $username@$hostname:mirror/* $HOME/mirror/ & \
# rsync -uv $username@$hostname:shared/* $HOME/shared/ & \
rsync -e "ssh -p $sshport" -uvr --include="*.py" --exclude "**/torch_compile_debug/" --exclude "**/.*" --exclude "**/res_cache/" --exclude="**/.ipynb_checkpoints/" --include="*.ipynb" --include="*/" --exclude="*" $username@$hostname:shared/notebook/ $HOME/shared/notebook/ & \
rsync -e "ssh -p $sshport" -uvr --include="*.py" --exclude "**/torch_compile_debug/" --exclude "**/.*" --exclude "**/res_cache/" --exclude="**/.ipynb_checkpoints/" --include="*.ipynb" --include="*/" --exclude="*" $username@$hostname:shared/script/ $HOME/shared/script/ & \
rsync -e "ssh -p $sshport" -uvr --include="*.py" --exclude "**/torch_compile_debug/" --exclude "**/.*" --exclude "**/res_cache/" --include="*/" --include "*.txt" --include "*.json" --include "*.md" --exclude="*"  $username@$hostname:shared/tests/ $HOME/shared/tests/ & \
rsync -e "ssh -p $sshport" -uv --exclude "**/.*" $username@$hostname:shared/bin/* $HOME/shared/bin/ & \
rsync -e "ssh -p $sshport" -uvr --exclude "**/.*" $username@$hostname:shared/env/* $HOME/shared/env/ & \
rsync -e "ssh -p $sshport" -uvr --exclude "**/__pycache__" --exclude "**/.*" $username@$hostname:shared/pythonenv/* $HOME/shared/pythonenv/ &
