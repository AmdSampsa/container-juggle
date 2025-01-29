#!/usr/bin/env bash
target_container=${1:-$container_name}
echo
echo TARGET CONTAINER: $target_container
echo

# Check if container exists and is running
if ! docker container inspect "$target_container" >/dev/null 2>&1; then
    echo "Container $target_container does not exist"
    exit 1
fi

if [ "$(docker container inspect -f '{{.State.Running}}' "$target_container")" != "true" ]; then
    echo "Container $target_container is not running"
    exit 1
fi

echo "Finding active shell sessions in container $target_container..."

# Get process list and filter for shells, excluding grep itself and the ps command
processes=$(docker exec "$target_container" ps aux | grep -E "(bash|sh|zsh)" | grep -v grep | grep -v "ps aux")

if [ -z "$processes" ]; then
    echo "No shell sessions found"
    exit 0
fi

echo "Found the following sessions:"
echo "$processes"
echo

# Extract PIDs and kill them
echo "Killing sessions..."
while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $2}')
    command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}')
    if [ -n "$pid" ] && [ "$pid" -ne 1 ]; then  # Avoid killing PID 1
        echo "Killing PID $pid ($command)"
        docker exec "$target_container" kill -9 "$pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✓ Killed PID $pid"
        else
            echo "✗ Failed to kill PID $pid"
        fi
    fi
done <<< "$processes"

# Verify all processes are gone
remaining=$(docker exec "$target_container" ps aux | grep -E "(bash|sh|zsh)" | grep -v grep | grep -v "ps aux")
if [ -n "$remaining" ]; then
    echo
    echo "Warning: Some sessions might still be running:"
    echo "$remaining"
    exit 1
else
    echo
    echo "All shell sessions successfully terminated"
fi