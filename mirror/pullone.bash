#!/bin/bash
rsync -e "ssh -p $sshport" --info=progress2 -uvr "$username@$hostname:$1" "$HOME/pulls/"
