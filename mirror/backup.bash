#!/bin/bash

echo "YOU NEED TO EDIT THIS FILE" # TODO TODO EDIT
exit 2 # TODO TODO EDIT

# Hardcoded source directories to backup
BACKUP_DIRS=( # TODO TODO EDIT
    "YOUR-HOME-DIR/mirror"
    "YOUR-HOME-DIR/shared"
    "YOUR-HOME-DIR/issues"
    # Add more directories as needed
)

# Hardcoded target directory for backups
TARGET_DIR="/mnt/c/Users/YOU/Maybe Some OneDrive directory with god'damn spaces" # TODO TODO EDIT

# Maximum file size (in 1K blocks)
# 1G = 1 * 1024 * 1024 = 1048576
MAX_FILE_SIZE=1048576

# Create backup directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Get current timestamp for logging
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="${TARGET_DIR}/backup_log.txt"

# Start logging
echo "----------------------------------------" >> "$LOG_FILE"
echo "Backup started at $TIMESTAMP" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Loop through each directory
for dir in "${BACKUP_DIRS[@]}"; do
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "Warning: Directory $dir does not exist. Skipping." | tee -a "$LOG_FILE"
        continue
    fi

    # Get the base directory name for the zip file
    dir_name=$(basename "$dir")
    zip_name="${dir_name}.zip"
    full_zip_path="${TARGET_DIR}/${zip_name}"

    # Zip the directory
    echo "Zipping $dir to $zip_name, excluding compressed archives" | tee -a "$LOG_FILE"
    cd "$(dirname "$dir")" && \
    find "$(basename "$dir")" \
        -type f \
        ! -name "*.tar.gz" \
        ! -name "*.zip" \
        ! -name "*.7z" \
        ! -name "*.rar" \
        -size -"$MAX_FILE_SIZE"k \
        | zip "$full_zip_path" -@

    # Check zip exit status
    ZIP_STATUS=$?
    if [ $ZIP_STATUS -eq 0 ]; then
        echo "Successfully zipped $dir" | tee -a "$LOG_FILE"
    elif [ $ZIP_STATUS -eq 12 ]; then
        echo "No files matched the criteria for $dir" | tee -a "$LOG_FILE"
    else
        echo "Error: Failed to zip $dir (exit status $ZIP_STATUS)" | tee -a "$LOG_FILE"
    fi
done

# End logging
echo "----------------------------------------" >> "$LOG_FILE"
echo "Backup completed at $(date +"%Y-%m-%d %H:%M:%S")" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

echo "Backup process finished. Check log at $LOG_FILE"