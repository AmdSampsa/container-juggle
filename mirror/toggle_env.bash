#!/bin/bash
## the docker container loads shitload of environmental variables
## as per shared/bin/contenv.bash
## if you want a "cleaner" container with no interfering env variables
## you can use this script to modify ~/.bashrc inside the container and
## toggle the sourcing of shared/bin/contenv.bash on/off
## of course, run this on the host, outside the container
##
if [ "$1" != "-on" ] && [ "$1" != "-off" ]; then
    echo "Usage: $0 [-on|-off]"
    exit 1
fi

line="source \/root\/shared\/bin\/contenv.bash"

if [ "$1" = "-on" ]; then
    docker exec $container_name sed -i "s/^#*${line}/${line}/" /root/.bashrc
else
    docker exec $container_name sed -i "s/^#*${line}/#${line}/" /root/.bashrc
fi
