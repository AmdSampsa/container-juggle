#!/bin/bash
if [ -z "$1" ]; then
    echo "Error: New image name required as first argument"
    exit 1
fi
push=true
[[ $2 == "--no-push" ]] && push=false
docker login -u $DOCKER_USER -p $DOCKER_PASS
docker commit $container_name $1
docker tag $1 $DOCKER_REG:$1
$push && docker push $DOCKER_REG:$1
