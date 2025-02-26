#!/bin/bash

# zipdir.sh - Script to zip a directory preserving only the last directory in the path
# Usage: ./zipdir.sh /path/to/directory/to/zip

# Check if zip is installed, install it if not
if ! command -v zip &> /dev/null; then
    echo "zip is not installed. Attempting to install it..."
    
    # Check which package manager is available
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y zip
    elif command -v yum &> /dev/null; then
        sudo yum install -y zip
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y zip
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y zip
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm zip
    elif command -v brew &> /dev/null; then
        brew install zip
    else
        echo "Error: Could not install zip. Please install it manually."
        exit 1
    fi
    
    # Check if installation was successful
    if ! command -v zip &> /dev/null; then
        echo "Error: Failed to install zip. Please install it manually."
        exit 1
    else
        echo "zip successfully installed."
    fi
fi

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 /path/to/directory/to/zip"
    echo "Example: $0 /home/user/projects/myproject"
    exit 1
fi

# Get the full path to the directory
FULL_PATH=$(realpath "$1")

# Check if the directory exists
if [ ! -d "$FULL_PATH" ]; then
    echo "Error: Directory '$1' does not exist or is not a directory"
    exit 1
fi

# Get the directory name (last component of the path)
DIR_NAME=$(basename "$FULL_PATH")

# Determine the parent directory
PARENT_DIR=$(dirname "$FULL_PATH")

# Set the output zip file name to the directory name
OUTPUT_ZIP="$DIR_NAME.zip"

# Get the current directory to return to it later
CURRENT_DIR=$(pwd)

# Navigate to the parent directory
cd "$PARENT_DIR" || { echo "Failed to change to directory $PARENT_DIR"; exit 1; }

# Create the zip file
echo "Creating zip archive '$OUTPUT_ZIP' from directory '$DIR_NAME'..."
zip -r "$CURRENT_DIR/$OUTPUT_ZIP" "$DIR_NAME"

# Return to the original directory
cd "$CURRENT_DIR" || { echo "Failed to return to directory $CURRENT_DIR"; exit 1; }

echo "Done! Archive created at: $OUTPUT_ZIP"
