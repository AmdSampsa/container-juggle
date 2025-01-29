#!/bin/bash
## use at SERVER
target_container=${1:-$container_name}
echo
echo TARGET CONTAINER: $target_container
echo
docker container stop $target_container

