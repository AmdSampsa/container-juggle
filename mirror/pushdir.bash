#!/bin/bash
# Try to get directory either from argument or saved file
if [ ! -z "$1" ]; then
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

# Verify dir is not empty before dangerous operations
if [ -z "$dir" ]; then
    echo "Error: Directory path is empty"
    exit 1
fi

# Perform the remote cleanup and rsync with quotes for safety
ssh -p "$sshport" "$username@$hostname" "rm -rf \"$dir\""
rsync -e "ssh -p $sshport" -uvr "$HOME/$dir/" "$username@$hostname:$dir/"
