#!/bin/bash
rsync -e "ssh -p $sshport" --info=progress2 -uvr $1 "$username@$hostname:$1"
