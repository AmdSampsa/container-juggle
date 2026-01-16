#!/bin/bash
set -e

# Configuration
container_name="${1:-$container_name}"  # Takes container name as argument or uses default

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "Error: Container '$container_name' is not running!"
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}"
    exit 1
fi

# Get host user's UID and GID
HOST_UID=$(id -u)
HOST_GID=$(id -g)

echo "Container: $container_name"
echo "Setting ownership to $HOST_UID:$HOST_GID"
echo "----------------------------------------"

# Fix permissions
docker exec "$container_name" chown -R "$HOST_UID:$HOST_GID" /root/shared /root/sharedump

echo "✅ Permissions fixed!"
echo ""
echo "Verification:"
docker exec "$container_name" ls -ld /root/shared /root/sharedump

echo ""
echo "Test from host with:"
echo "  touch $HOME/shared/test-file.txt"
