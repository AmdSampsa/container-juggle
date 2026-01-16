#!/bin/bash

echo "USE image.bash INSTEAD!"
exit 1

if [ -z "$DOCKER_REG" ]; then
    echo "DOCKER_REG is not set"
    exit 1
fi
if [ -z "$DOCKER_USER" ]; then
    echo "DOCKER_USER is not set"
    exit 1
fi
if [ -z "$DOCKER_PASS" ]; then
    echo "DOCKER_PASS is not set"
    exit 1
fi
if [ -z "$container_name" ]; then
    echo "container_name is not set"
    exit 1
fi
echo 
echo pushing a docker container to $DOCKER_REG
echo before this, consider running
echo "(1) outside the container: toggle_env.bash:"
echo "-> to remove all extra env variables"
echo "(2) inside the container: remprivate.bash:"
echo "-> to remove your private ssh keys"
echo
echo
echo WARNING WARNING WARNING: DOUBLE-CHECK THAT THIS SCRIPT ACTUALLY PUSHES
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
echo "Choose image naming format:"
echo "  1) $DOCKER_REG:$1  (repo:tag format, e.g., rocm/pytorch-private:myimage)"
echo "  2) $DOCKER_REG/$DOCKER_USER/$1  (registry/user/image format, e.g., docker.io/myuser/myimage)"
read -p "Enter 1 or 2: " format_choice

case $format_choice in
    1)
        FULL_IMAGE="$DOCKER_REG:$1"
        ;;
    2)
        FULL_IMAGE="$DOCKER_REG/$DOCKER_USER/$1"
        ;;
    *)
        echo "Invalid choice, defaulting to format 1"
        FULL_IMAGE="$DOCKER_REG:$1"
        ;;
esac

echo
echo DOCKER COMMIT
echo
docker commit $container_name $1
echo
echo DOCKER TAG
echo
docker tag $1 $FULL_IMAGE
$push && docker push $FULL_IMAGE
echo
echo you can try this container with
echo
echo start_plain.bash $FULL_IMAGE container-name
echo enter.bash container-name
echo
