#!/bin/bash
## use at CLIENT
## login to server
## pick up the current context from the local environment & set it in the remote host for the session
# Check if there's a tmux session starting with contextname
ssh -t -p$sshport $username@$hostname "bash --rcfile <(cat ~/mirror/context/${contextname}.bash ~/.bashrc) -c '~/mirror/tlogin_.bash'"
