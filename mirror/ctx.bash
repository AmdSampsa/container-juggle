#!/bin/bash
echo "CONTEXT "$contextname
echo "============================"
variables=(
    "username"
    "container_name"
    "image_id"
    # "PATH"
    "hostname"
    "sshport"
    "hostnick"
    "PRINCIPAL_DIR"
)
for var in "${variables[@]}"; do
    if [ -n "${!var}" ]; then
        echo "$var = ${!var}"
    else
        echo "$var is not set"
    fi
done

command -v docker >/dev/null 2>&1 || exit 0
echo
docker ps -a --filter "name=^/${container_name}$" --format "{{.Names}},{{.Status}}" | awk -F',' '{print $1 " container exists, status: " $2; exit} END {if (NR==0) print "Container does not exist"}'
echo image was created:
docker inspect -f '{{.Created}}' ${image_id} | cut -d'T' -f1
echo
echo All containers using $image_id
echo
docker ps -a --filter ancestor=$image_id
echo
echo Already active sessions in container $container_name
echo "NOTE: they are probably your VSCode remote session daemons, notebook servers, etc."
echo "NOTE: you can kill them by running 'killses.bash' or better with 'stop.bash && start.bash'"
docker exec $container_name ps aux | grep -E "(bash|sh|zsh)" | cut -c1-80
