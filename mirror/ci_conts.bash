#!/bin/bash

# Define the output file
output_file=~/shared/ci-containers.txt

echo $HOSTNAME > $output_file
date >> $output_file

# Ensure the output directory exists
mkdir -p "$(dirname "$output_file")"

# Clear the output file if it already exists
# > "$output_file"

# Get all images starting with "ci-"
images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^ci-")

# Loop through each image
while IFS= read -r image; do
    echo "Image: $image" >> "$output_file"
    
    # Get containers using this image
    containers=$(docker ps -a --filter ancestor="$image" --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
        echo "  No containers using this image" >> "$output_file"
    else
        echo "  Containers:" >> "$output_file"
        echo "$containers" | sed 's/^/    /' >> "$output_file"
    fi
    echo >> "$output_file"
done <<< "$images"

echo "Output has been written to $output_file"
echo
cat $output_file
