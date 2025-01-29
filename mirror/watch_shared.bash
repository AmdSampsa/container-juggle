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

# Initial ownership setup
for dir in "${WATCH_DIRS[@]}"; do
    sudo chown -R $username "$dir"
done

# Watch directories from array
inotifywait -m -r -e modify,create,delete,move "${WATCH_DIRS[@]}" |
while read path action file; do
    sudo chown -R $username "$path"
    echo "$(date): Change detected in $path$file. Ownership updated."
done
