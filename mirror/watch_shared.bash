#!/bin/bash
#DIRECTORY_TO_WATCH="$HOME/shared"
#sudo chown -R $username "$DIRECTORY_TO_WATCH"
#inotifywait -m -r -e modify,create,delete,move "$DIRECTORY_TO_WATCH" |
#while read path action file; do
#    sudo chown -R $username "$DIRECTORY_TO_WATCH"
#    echo "$(date): Change detected in $path$file. Ownership updated."
#done
#
# Array version
WATCH_DIRS=(
    "$HOME/shared"
    "$HOME/sharedump"
)

echo ">"$username

# Initial ownership setup
for dir in "${WATCH_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        sudo chown -R $username "$dir"
        echo "Initial ownership set for $dir"
    else
        echo "Directory $dir does not exist"
    fi
done

# Watch directories from array
inotifywait -m -r -e modify,create,delete,move,moved_to,moved_from,attrib,isdir "${WATCH_DIRS[@]}" |
while read path action file; do
    sudo chown -R $username "$path"
    echo "$(date): Change detected in $path$file. Ownership updated."
done

return 0

## the script below seems to go into some weirdo recursion

# Watch directories from array with expanded event monitoring
inotifywait -m -r \
    -e modify,create,delete,move,moved_to,moved_from,attrib,isdir \
    "${WATCH_DIRS[@]}" |
while read path action file; do
    # Get the full path
    full_path="${path}${file}"
    
    # Handle both files and directories
    if [[ -d "$full_path" ]]; then
        # If it's a new directory, set ownership recursively
        sudo chown -R $username "$full_path"
        echo "$(date): Directory change detected in $full_path. Recursive ownership updated."
    else
        # For files, update the file and its parent directory
        sudo chown $username "$path"
        sudo chown $username "$full_path"
        echo "$(date): File change detected: $full_path. Ownership updated."
    fi
    
    # Additional safety check for parent directories
    parent_dir=$(dirname "$full_path")
    if [[ "$parent_dir" != "$path" ]]; then
        sudo chown $username "$parent_dir"
    fi
done