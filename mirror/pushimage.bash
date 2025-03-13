#!/bin/bash
if [ -z "$DOCKER_REG" ]; then
    echo "DOCKER_REG is not set"
fi
if [ -z "$DOCKER_USER" ]; then
    echo "DOCKER_USER is not set"
fi
if [ -z "$DOCKER_PASS" ]; then
    echo "DOCKER_PASS is not set"
fi
echo 
echo pushing a docker container to $DOCKER_REG
echo before this, consider running
echo "(1) outside the container: toggle_env.bash:"
echo "-> to remove all extra env variables"
echo "(2) inside the container: remprivate.bash:"
echo "-> to remove your private ssh keys"
echo
read -p "press enter to continue, CTRL-C to abort"
echo
if [ -z "$1" ]; then
    echo "Error: New image name required as first argument"
    exit 1
fi
push=true
[[ $2 == "--no-push" ]] && push=false
docker login -u $DOCKER_USER -p $DOCKER_PASS
echo
echo DOCKER COMMIT
echo
docker commit $container_name $1
echo
echo DOCKER TAG
echo
docker tag $1 $DOCKER_REG:$1
$push && docker push $DOCKER_REG:$1
echo
echo you can try this container with
echo
echo start_plain.bash $DOCKER_REG:$1 container-name
echo enter.bash container-name
echo
