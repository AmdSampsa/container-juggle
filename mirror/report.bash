#!/bin/bash
## report all running containers in all running contexes
for contextfile in ~/mirror/context/*.bash; do
    # Skip the excluded file (change excluded-file.bash to your excluded filename)
    if [[ "$contextfile" == *"_scaffold.bash" ]]; then
        continue
    fi
    # echo "Processing $contextfile..."
    # Source the context file and run the SSH check
    # Note: we need to create a subshell to avoid env vars polluting subsequent iterations
    (
        source "$contextfile" &>/dev/null
        echo "--------------CONTEXT: "$contextname" @ "$hostname
        echo "Image: "$image_id
        if ssh -q -p$sshport $username@$hostname "docker image inspect ${image_id} >/dev/null 2>&1"; then
            date_=$(ssh -q -p$sshport $username@$hostname "docker inspect -f '{{.Created}}' ${image_id} | cut -d'T' -f1")
            echo "Image created on: "$date_
            echo "Image DOWNLOADED"
        fi
        if ssh -q -p$sshport $username@$hostname "docker ps -a --quiet --filter name=${container_name} | grep -q ."; then
            echo "CONTAINER EXISTS"
        fi
        if ssh -q -p$sshport $username@$hostname "docker ps --quiet --filter name=${container_name} | grep -q ."; then
            echo "CONTAINER IS RUNNING"
        fi

    )
done
## TODO: check tmux sessions
