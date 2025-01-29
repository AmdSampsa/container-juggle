#!/bin/bash
## use at REMOTE HOST
## login to server
## pick up the current context from the local environment & set it in the remote host for the session
# Check if there's an unattached tmux session starting with contextname
if tmux ls 2>/dev/null | grep "^${contextname}-" | grep -v "(attached)" | grep -q .; then
    # Get the first matching unattached session name
    session_name=$(tmux ls 2>/dev/null | grep "^${contextname}-" | grep -v "(attached)" | head -n1 | cut -d: -f1)
    echo "found "$session_name
    tmux attach -t ${session_name}
else
    echo "Error: No unattached tmux session found for context ${contextname}"
    echo
    echo "tmux sessions:"
    tmux ls
    exit 1
fi
