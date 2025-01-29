#!/bin/bash
## use at SERVER
## NOTE: by default removes the container loade by the context into $container_name
## if a parameter is defined then use it as a name to remove some other container
## Use the first command-line argument if provided, otherwise use the default
target_container=${1:-$container_name}
echo
echo TARGET CONTAINER: $target_container
echo
## Stop the container
docker container stop $target_container
## Remove the container
docker container rm $target_container
