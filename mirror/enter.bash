#!/bin/bash
## use at SERVER
## NOTE: by default uses the container loaded by the context into $container_name
## if a parameter is defined then use it as a name of the container
## Use the first command-line argument if provided, otherwise use the default
target_container=${1:-$container_name}
echo
echo TARGET CONTAINER: $target_container
echo
echo LISTING CONTAINER MOUNTS:
docker inspect --format='{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{println}}{{end}}' $target_container
## important to see if other users are using the container:
echo NUMBER OF ALREADY ACTIVE SESSION IN THE CONTAINER:
docker exec $target_container ps aux | grep -E "(bash|sh|zsh)" | wc -l
echo
echo "NOTE: you can kill them by running 'killses.bash' or better with 'stop.bash && start.bash'"
echo
echo NOW ENTERING CONTAINER
echo
## interactive session in a running container
echo
echo "docker exec -u 0 -it "$target_container" bash"
echo
docker exec -u 0 -it $target_container bash

