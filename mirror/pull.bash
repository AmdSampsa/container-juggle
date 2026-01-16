#!/bin/bash

do_rsync() {
    rsync -e "ssh -p $sshport -o StrictHostKeyChecking=no" -uvr --max-size=1M "$@"
}

exclude_artefacts=(
    --include="*.py" 
    --exclude "**/torch_compile_debug/" 
    --exclude "**/.*" 
    --exclude "**/res_cache/" 
    --exclude="**/.ipynb_checkpoints/" 
    --exclude="**/__pycache__" 
    --exclude="SAVED*/"
    --exclude="hwfail/"
    --exclude="fail/"
    --exclude="rerun/"
    --exclude="uncategorized/"
    --exclude="success/"
    --include="*.ipynb" 
    --include="*/" 
    --include="*.png"
)

include_txt=(
    --include="*/" 
    --include="*.txt" 
    --include="*.bash" 
    --include="*.sh" 
    --include="*.csv" 
    --include="*.json" 
    --include="*.md" 
)

## use at CLIENT
do_rsync --exclude "context/" $username@$hostname:mirror/* $HOME/mirror/ & \
do_rsync --exclude "**/.*" $username@$hostname:shared/bin/* $HOME/shared/bin/ & \
do_rsync "${exclude_artefacts[@]}" --exclude="*" $username@$hostname:shared/notebook/ $HOME/shared/notebook/ & \
do_rsync "${exclude_artefacts[@]}" --exclude="*" $username@$hostname:shared/script/ $HOME/shared/script/ & \
do_rsync "${exclude_artefacts[@]}" "${include_txt[@]}" --exclude="*" $username@$hostname:shared/tests/ $HOME/shared/tests/ & \
do_rsync --include="*.json" --exclude="*"  $username@$hostname:shared/ $HOME/shared/ & \
do_rsync --exclude "**/__pycache__" --exclude "**/.*" $username@$hostname:shared/pythonenv/* $HOME/shared/pythonenv/ &
