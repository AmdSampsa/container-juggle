#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 number_of_tries command [args...]"
    exit 1
fi

max_tries=$1
shift  # Remove first argument, leaving just the command and its args

count=0
while [ $count -lt $max_tries ]; do
    echo "Try $(($count + 1)) of $max_tries"
    "$@"  # Execute the command with all its arguments
    ((count++))
    [ $count -lt $max_tries ] && sleep 1  # Sleep only if not the last iteration
done
