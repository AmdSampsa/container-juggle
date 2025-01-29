#!/bin/bash
## run at the remote host
## starts a new tmux session and initializes context variables therein
tmux new-session -s "${contextname}-${RANDOM}" "source ~/mirror/context/${contextname}.bash && $SHELL"
## other tmux commands:
## tmux kill-server
## tmux kill-session -t session_name
