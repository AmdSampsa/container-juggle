#!/bin/bash
# If argument is provided, save it and use it
if [ ! -z "$1" ]; then
    echo "$1" > ~/.pulldir
    dir="$1"
else
    # Try to recover from ~/.pulldir if no argument
    if [ -f ~/.pulldir ]; then
        dir=$(cat ~/.pulldir)
    else
        echo "Error: No directory specified and none saved in ~/.pulldir"
        exit 1
    fi
fi
# Perform the rsync with the directory (either from argument or saved file)
rm -rf $HOME/$dir
rsync -e "ssh -p $sshport" --info=progress2 -uvr "$username@$hostname:$dir/" "$HOME/$dir/"
