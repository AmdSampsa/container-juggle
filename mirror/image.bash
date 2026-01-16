#!/bin/bash

usage() {
    echo "Usage: image.bash --export|--import [options]"
    echo
    echo "Export mode (container -> image -> compressed tar):"
    echo "  image.bash --export <container_name> <image_name> [output_file.tar.gz]"
    echo "  If output_file is omitted, defaults to <image_name>.tar.gz"
    echo "  Options:"
    echo "    --no-compress   Skip compression"
    echo "    --no-cleanup    Skip cleanup step (private keys, git config, empty mount dirs)"
    echo "    --skip-commit   Skip docker commit, use existing image (removes old tar.gz)"
    echo
    echo "Import mode (tar/tar.gz -> image):"
    echo "  image.bash --import <input_file>"
    echo "  Auto-detects compression format"
    echo
    exit 1
}

# Cleanup function to run inside temp container
run_cleanup() {
    local temp_container="$1"
    echo "Running cleanup commands in temp container..."
    
    # Remove SSH keys (shred for secure deletion)
    docker exec "$temp_container" bash -c '
        shred -u ~/.ssh/id_rsa 2>/dev/null || true
        shred -u ~/.ssh/id_rsa.pub 2>/dev/null || true
        shred -u ~/.ssh/authorized_keys 2>/dev/null || true
        shred -u ~/.ssh/known_hosts* 2>/dev/null || true
    '
    
    # Remove git config
    docker exec "$temp_container" bash -c 'rm -f ~/.gitconfig 2>/dev/null || true'
    
    # Remove empty mount point directories
    docker exec "$temp_container" bash -c 'rm -rf /root/shared /root/sharedump 2>/dev/null || true'
    
    echo "Cleanup done."
}

if [ -z "$1" ]; then
    usage
fi

case "$1" in
    --export)
        if [ -z "$2" ]; then
            echo "Error: container_name is required"
            usage
        fi
        if [ -z "$3" ]; then
            echo "Error: image_name is required"
            usage
        fi
        
        container_name="$2"
        image_name="$3"
        
        # Check for flags
        compress=true
        skip_commit=false
        do_cleanup=true
        output_file=""
        for arg in "${@:4}"; do
            if [ "$arg" == "--no-compress" ]; then
                compress=false
            elif [ "$arg" == "--skip-commit" ]; then
                skip_commit=true
            elif [ "$arg" == "--no-cleanup" ]; then
                do_cleanup=false
            else
                output_file="$arg"
            fi
        done
        
        # Set default output file based on compression
        if [ -z "$output_file" ]; then
            if $compress; then
                output_file="${image_name}.tar.gz"
            else
                output_file="${image_name}.tar"
            fi
        fi
        
        # Generate temp names
        temp_image="${image_name}-temp-$$"
        temp_container="cleanup-temp-$$"
        
        echo
        echo "=== Exporting container to tar file ==="
        echo "Container: $container_name"
        echo "Image name: $image_name"
        echo "Output file: $output_file"
        echo "Compression: $compress"
        echo "Cleanup: $do_cleanup"
        echo "Skip commit: $skip_commit"
        echo
        
        if $skip_commit; then
            # Check if image exists
            if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${image_name}"; then
                # Also check without tag (for :latest)
                if ! docker images --format '{{.Repository}}' | grep -q "^${image_name}$"; then
                    echo "Error: Image '$image_name' not found"
                    echo "Available images:"
                    docker images --format '{{.Repository}}:{{.Tag}}' | head -20
                    exit 1
                fi
            fi
            
            # Remove old tar file if exists
            if [ -f "$output_file" ]; then
                echo "Removing old file: $output_file"
                rm -f "$output_file"
                echo
            fi
            
            echo "Skipping commit, using existing image: $image_name"
            echo
        else
            # Check if container exists
            if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
                echo "Error: Container '$container_name' not found"
                echo "Available containers:"
                docker ps -a --format '{{.Names}}'
                exit 1
            fi
            
            # Warn if container is running
            if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
                echo "Warning: Container '$container_name' is running."
                echo "For best consistency, consider stopping it first: docker stop $container_name"
                echo
                read -p "Continue anyway? [y/N] " confirm
                [[ $confirm != [yY] ]] && exit 0
                echo
            fi
            
            if $do_cleanup; then
                # === CLEANUP FLOW: commit -> temp container -> cleanup -> commit final ===
                
                echo "Step 1: Committing container to intermediate image..."
                docker commit "$container_name" "$temp_image"
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to commit container"
                    exit 1
                fi
                echo "Done."
                echo
                
                echo "Step 2: Starting temp container for cleanup..."
                docker run -d --name "$temp_container" "$temp_image" tail -f /dev/null
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to start temp container"
                    docker rmi "$temp_image" 2>/dev/null
                    exit 1
                fi
                echo "Done."
                echo
                
                echo "Step 3: Running cleanup..."
                run_cleanup "$temp_container"
                echo
                
                echo "Step 4: Committing cleaned container to final image..."
                docker commit "$temp_container" "$image_name"
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to commit cleaned container"
                    docker rm -f "$temp_container" 2>/dev/null
                    docker rmi "$temp_image" 2>/dev/null
                    exit 1
                fi
                echo "Done."
                echo
                
                echo "Step 5: Cleaning up temp resources..."
                docker rm -f "$temp_container" 2>/dev/null
                docker rmi "$temp_image" 2>/dev/null
                echo "Done."
                echo
                
                # Show image size
                image_size=$(docker images --format "{{.Size}}" "$image_name" | head -1)
                echo "Final image size: $image_size"
                echo
                
                echo "Step 6: Saving image to tar file..."
            else
                # === NO CLEANUP: direct commit ===
                
                echo "Step 1: Committing container to image..."
                docker commit "$container_name" "$image_name"
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to commit container"
                    exit 1
                fi
                echo "Done."
                echo
                
                # Show image size
                image_size=$(docker images --format "{{.Size}}" "$image_name" | head -1)
                echo "Final image size: $image_size"
                echo
                
                echo "Step 2: Saving image to tar file..."
            fi
        fi
        
        if $skip_commit; then
            # Show image size
            image_size=$(docker images --format "{{.Size}}" "$image_name" | head -1)
            echo "Image size: $image_size"
            echo
            
            echo "Step 1: Saving image to tar file..."
        fi
        
        if $compress; then
            # Use pigz (parallel gzip) if available, otherwise gzip
            # -1 = fastest compression for large images
            if command -v pigz &> /dev/null; then
                compressor="pigz -1"
                echo "(with pigz -1 fast parallel compression)"
            else
                compressor="gzip -1"
                echo "(with gzip -1 fast compression)"
                echo "Tip: Install pigz for faster parallel compression"
            fi
            
            # Use pv for progress if available
            if command -v pv &> /dev/null; then
                docker save "$image_name" | pv | $compressor > "$output_file"
            else
                echo "Tip: Install pv for progress bar"
                docker save "$image_name" | $compressor > "$output_file"
            fi
        else
            docker save -o "$output_file" "$image_name"
        fi
        if [ $? -ne 0 ]; then
            echo "Error: Failed to save image to tar"
            exit 1
        fi
        echo "Done."
        echo
        
        # Show file size
        file_size=$(du -h "$output_file" | cut -f1)
        echo "=== Export complete ==="
        echo "Created: $output_file ($file_size)"
        echo
        echo "To import on another machine:"
        echo "  image.bash --import $output_file"
        echo
        ;;
        
    --import)
        if [ -z "$2" ]; then
            echo "Error: input file is required"
            usage
        fi
        
        input_file="$2"
        
        if [ ! -f "$input_file" ]; then
            echo "Error: File '$input_file' not found"
            exit 1
        fi
        
        echo
        echo "=== Importing image from tar file ==="
        echo "Input file: $input_file"
        
        # Auto-detect compression
        if file "$input_file" | grep -q "gzip"; then
            echo "Detected: gzip compressed"
            echo
            echo "Loading image..."
            # Use pv for progress if available
            if command -v pv &> /dev/null; then
                pv "$input_file" | gunzip | docker load
            else
                gunzip -c "$input_file" | docker load
            fi
        else
            echo "Detected: uncompressed tar"
            echo
            echo "Loading image..."
            if command -v pv &> /dev/null; then
                pv "$input_file" | docker load
            else
                docker load -i "$input_file"
            fi
        fi
        
        if [ $? -ne 0 ]; then
            echo "Error: Failed to load image"
            exit 1
        fi
        echo
        
        echo "=== Import complete ==="
        echo "You can now run the image with:"
        echo "  docker run -it <image_name> /bin/bash"
        echo
        echo "To see available images:"
        echo "  docker images"
        echo
        ;;
        
    *)
        echo "Error: Unknown option '$1'"
        usage
        ;;
esac
