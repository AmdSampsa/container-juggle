#!/bin/bash

OUTPUT_FILE=$HOME/shared/containers.txt

echo "writing to file "$OUTPUT_FILE

echo $HOSTNAME > $OUTPUT_FILE
date >> $OUTPUT_FILE
df -h | grep "data" >> $OUTPUT_FILE
docker info | grep "Root Dir" >> $OUTPUT_FILE
echo "remember: consider 'docker image prune' or 'docker image prune -a'" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "IMAGES" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
docker image ls --format "{{.Size}}\t{{.Repository}}:{{.Tag}}\t{{.ID}}" | sort -h >> $OUTPUT_FILE

# Function to convert Unix timestamp to human-readable format
format_time() {
    date -d @$1 "+%Y-%m-%d %H:%M:%S"
}

# Function to calculate duration
calculate_duration() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    echo "${days}d ${hours}h ${minutes}m"
}

# Clear the file before writing
# > $OUTPUT_FILE

echo "CONTAINERS" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

echo "Running Containers:" >> $OUTPUT_FILE
echo "ID | Name | Created | Uptime" >> $OUTPUT_FILE
echo "------------------------------------" >> $OUTPUT_FILE
docker ps --format "{{.ID}}" | while read -r id; do
    name=$(docker inspect --format '{{.Name}}' "$id" | sed 's/\///')
    created=$(docker inspect --format '{{.Created}}' "$id")
    created_unix=$(date -d "$created" +%s)
    created_human=$(format_time $created_unix)
    uptime=$(docker inspect --format '{{.State.StartedAt}}' "$id")
    uptime_unix=$(date -d "$uptime" +%s)
    current_time=$(date +%s)
    uptime_seconds=$((current_time - uptime_unix))
    uptime_human=$(calculate_duration $uptime_seconds)
    echo "$id | $name | $created_human | $uptime_human" >> $OUTPUT_FILE
done

echo -e "\nStopped Containers:" >> $OUTPUT_FILE
echo "ID | Name | Created | Stopped At | Downtime" >> $OUTPUT_FILE
echo "------------------------------------" >> $OUTPUT_FILE
docker ps -a --format "{{.ID}}" | while read -r id; do
    status=$(docker inspect --format '{{.State.Status}}' "$id")
    if [ "$status" != "running" ]; then
        name=$(docker inspect --format '{{.Name}}' "$id" | sed 's/\///')
        created=$(docker inspect --format '{{.Created}}' "$id")
        created_unix=$(date -d "$created" +%s)
        created_human=$(format_time $created_unix)
        finished=$(docker inspect --format '{{.State.FinishedAt}}' "$id")
        finished_unix=$(date -d "$finished" +%s)
        finished_human=$(format_time $finished_unix)
        current_time=$(date +%s)
        downtime_seconds=$((current_time - finished_unix))
        downtime_human=$(calculate_duration $downtime_seconds)
        echo "$id | $name | $created_human | $finished_human | $downtime_human" >> $OUTPUT_FILE
    fi
done
