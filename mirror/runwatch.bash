#!/bin/bash
ssh -p$sshport $username@$hostname 'bash -l -c "source ~/mirror/context/'${contextname}'.bash && ~/mirror/watch_shared.bash"'
