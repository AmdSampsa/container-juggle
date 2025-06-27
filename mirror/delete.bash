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
#docker container stop $target_container
## Remove the container
#docker container rm $target_container

# Function to confirm actions with the user
confirm_action() {
    local prompt="$1"
    read -p "$prompt (y/n): " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Step 1: Try normal stop and remove
echo "STAGE 1: Attempting normal container operations"
echo "-------------------------------------------"

# Stop the container
echo "Stopping container $target_container..."
if ! docker container stop $target_container; then
    echo "WARNING: Failed to stop container $target_container"
    echo "The container might already be stopped or it's in an unresponsive state."
else
    echo "Container stopped successfully."
fi

# Remove the container
echo "Removing container $target_container..."
if ! docker container rm $target_container; then
    echo "WARNING: Failed to remove container $target_container"
    
    # Ask user if they want to force remove
    if confirm_action "Do you want to force remove the container?"; then
        echo "Attempting to force remove container..."
        if docker container rm -f $target_container; then
            echo "Container force removed successfully."
        else
            echo "ERROR: Failed to force remove container with docker rm -f."
            echo "Moving to advanced techniques..."
            
            # Step 2: Try using Docker's low-level API
            echo
            echo "STAGE 2: Attempting advanced container removal"
            echo "-------------------------------------------"
            
            if confirm_action "Do you want to try direct PID-based container removal?"; then
                # Get the container PID
                CONTAINER_PID=$(docker inspect --format '{{.State.Pid}}' $target_container 2>/dev/null)
                
                if [ -z "$CONTAINER_PID" ] || [ "$CONTAINER_PID" -eq 0 ]; then
                    echo "Could not get valid PID for container. Moving to process search method."
                else
                    echo "Container PID: $CONTAINER_PID"
                    echo "Attempting to kill container process..."
                    
                    if confirm_action "Proceed with killing container process?"; then
                        sudo kill -9 $CONTAINER_PID
                        echo "Killed process $CONTAINER_PID. Waiting 5 seconds before trying removal again..."
                        sleep 5
                        docker rm -f $target_container
                        
                        if [ $? -eq 0 ]; then
                            echo "SUCCESS: Container removed after killing main process."
                            exit 0
                        fi
                    fi
                fi
                
                # Get container ID for process matching
                CONTAINER_ID=$(docker inspect --format '{{.Id}}' $target_container 2>/dev/null || echo "unknown")
                SHORT_ID=${CONTAINER_ID:0:12}
                
                echo "Searching for processes related to container $target_container (ID: $SHORT_ID)..."
                PROCS=$(sudo ps aux | grep -E "$target_container|$SHORT_ID" | grep -v grep)
                
                if [ -z "$PROCS" ]; then
                    echo "No processes found related to this container."
                else
                    echo "Found these related processes:"
                    echo "$PROCS"
                    
                    if confirm_action "Do you want to kill these processes?"; then
                        # Extract PIDs and kill them
                        PIDS=$(echo "$PROCS" | awk '{print $2}')
                        echo "Killing PIDs: $PIDS"
                        for pid in $PIDS; do
                            sudo kill -9 $pid
                            echo "Killed process $pid"
                        done
                        
                        echo "Waiting 5 seconds before trying removal again..."
                        sleep 5
                        docker rm -f $target_container
                        
                        if [ $? -eq 0 ]; then
                            echo "SUCCESS: Container removed after killing related processes."
                            exit 0
                        else
                            echo "WARNING: Container still could not be removed."
                        fi
                    fi
                fi
                
                # Try looking for containerd-shim processes
                echo "Searching for containerd-shim processes related to container..."
                if confirm_action "Do you want to search for and kill containerd-shim processes?"; then
                    for pid in $(sudo pgrep -f "containerd-shim.*$SHORT_ID"); do
                        echo "Found containerd-shim process $pid"
                        if confirm_action "Kill process $pid?"; then
                            sudo kill -9 $pid
                            echo "Killed process $pid"
                        fi
                    done
                    
                    echo "Waiting 5 seconds before trying removal again..."
                    sleep 5
                    docker rm -f $target_container
                    
                    if [ $? -eq 0 ]; then
                        echo "SUCCESS: Container removed after killing containerd-shim processes."
                        exit 0
                    else
                        echo "WARNING: Container still could not be removed."
                        echo "You may need to restart the Docker daemon (impacts ALL containers)."
                    fi
                fi
            fi
        fi
    else
        echo "Container was not removed."
    fi
else
    echo "Container removed successfully."
fi
