#!/bin/bash
## quick-test an image and a single unit tests as defined by a context bash file
source ~/mirror/context/$1.bash
if [ -z "$test_comm" ]; then
    echo "Error: the extra env var test_comm is not set"
    exit 1
fi
if [ -z "$container_name" ]; then
    echo "Error: container_name is not set"
    exit 1
fi
start.bash
docker exec "$container_name" /bin/sh -c "$test_comm > /root/sharedump/testout.txt" 
echo
echo "remember to run stop.bash and maybe also delete.bash .. or not"
echo
