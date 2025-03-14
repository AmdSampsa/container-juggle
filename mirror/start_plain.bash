#!/bin/bash
## use at SERVER
## start_plain.bash image-name container-name

image_id=$1
container_name=$2

# Check if the container exists
container_id=$(docker ps -aq -f name=^/${container_name}$)

if [ -n "$container_id" ]; then
    echo "Container $container_name exists."
    
    # Check if the container is running
    is_running=$(docker ps -q -f id=$container_id)
    
    if [ -n "$is_running" ]; then
        echo "Container $container_name is already running."
        echo "Please use enter.bash"
        exit 2
    else
        echo "Starting existing container $container_name."
        echo "It was created with this command:"
        echo
        cat $HOME/.docker_run
        echo
        docker start $container_id
    fi
else
    IMAGE_NAME=$image_id
    if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
        echo "Image $IMAGE_NAME already exists locally."
    else
        echo "Image $IMAGE_NAME does not exist locally. Attempting to pull..."
        echo $IMAGE_NAME >> $HOME/MY_IMAGES.txt
        if docker pull "$IMAGE_NAME"; then
            echo "Successfully pulled $IMAGE_NAME."
        else
            echo "Failed to pull $IMAGE_NAME. Please check the image name and your internet connection."
            exit 1
        fi
    fi
    # 
    if command -v nvidia-smi &> /dev/null || lspci | grep -i nvidia &> /dev/null; then
    # NVIDIA version
        echo 
        echo NVIDIA CONTAINER
        echo
        DOCKER_GPU_FLAGS="--gpus all"
    else
        # AMD version
        echo 
        echo ROCM CONTAINER
        echo
        DOCKER_GPU_FLAGS="--device=/dev/kfd --device=/dev/dri --group-add video"
    fi

    # NOTE: in the plain container, do this minimal test:
    # python -c "import torch, inspect; print(f'Torch is imported from: {inspect.getfile(torch)}')"
    #
    # Create the command string
    docker_cmd="docker run -d \
        --name $container_name \
        -p 9999:9999 \
        $DOCKER_GPU_FLAGS \
        --cap-add=SYS_PTRACE \
        --security-opt seccomp=unconfined \
        --shm-size=64G \
        --network=host \
        $image_id \
        tail -f /dev/null"

    # Save the command to .docker_run
    # echo "$docker_cmd" > $HOME/.docker_run

    # Execute the command
    echo STATING CONTAINER WITH
    echo
    echo $docker_cmd
    echo
    echo CONTAINER STARTED
    echo
    eval "$docker_cmd"
    echo
fi
