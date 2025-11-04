#!/bin/bash
rsync -e "ssh -p $sshport" -uvr "$username@$hostname:$1" "$HOME/pulls/"
