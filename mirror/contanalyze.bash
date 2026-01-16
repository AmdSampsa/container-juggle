#!/bin/bash

OUTPUT_FILE=$HOME/shared/containers.txt
SEND_WALL=false
SEND_MAIL=false
DROP_WARNING=false
TOP_N=3        # Number of top users to mention (if no limit set)
GB_LIMIT=""    # GB threshold - users above this get warned

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --wall)
            SEND_WALL=true
            shift
            ;;
        --mail)
            SEND_MAIL=true
            shift
            ;;
        --warn)
            DROP_WARNING=true
            shift
            ;;
        --notify-all)
            SEND_WALL=true
            SEND_MAIL=true
            DROP_WARNING=true
            shift
            ;;
        --limit)
            GB_LIMIT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "  --wall         Send wall message to logged-in users"
            echo "  --mail         Send email to top disk users"
            echo "  --warn         Drop warning file in home dirs + add .bashrc hook"
            echo "  --notify-all   Do all of the above"
            echo "  --limit N      Warn users using more than N GB (default: top $TOP_N users)"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Function to convert size string (e.g., 150G, 2.5T, 500M) to GB
size_to_gb() {
    local size="$1"
    local num=$(echo "$size" | sed 's/[^0-9.]//g')
    local unit=$(echo "$size" | sed 's/[0-9.]//g')
    case "$unit" in
        T) echo "$num * 1024" | bc ;;
        G) echo "$num" ;;
        M) echo "$num / 1024" | bc ;;
        K) echo "0" ;;
        *) echo "0" ;;
    esac
}

echo "writing to file "$OUTPUT_FILE

echo $HOSTNAME > $OUTPUT_FILE
date >> $OUTPUT_FILE

echo "DISK USAGE" >> $OUTPUT_FILE
echo "DOCKER:" >> $OUTPUT_FILE
docker info | grep "Root Dir" | awk '{print $NF}' | xargs df -h >> $OUTPUT_FILE
echo "HOME DIRS:" >> $OUTPUT_FILE
df -h /home >> $OUTPUT_FILE
echo "HOME DIR ANALYSIS:" >> $OUTPUT_FILE
if sudo -n true 2>/dev/null; then
    # We have passwordless sudo - sort by size descending, show only GB+ users
    TOP_USERS=$(cd /home && sudo du -sh * | sort -hr | awk '$1 ~ /[0-9]+G/ {print}')
    echo "$TOP_USERS" >> "$OUTPUT_FILE"
else
    # No sudo, use regular du - sort by size descending
    TOP_USERS=$(cd /home && du -h --max-depth=1 | sort -hr)
    echo "$TOP_USERS" >> "$OUTPUT_FILE"
fi

# Get users list for notifications (either by limit or top N)
if [ -n "$GB_LIMIT" ]; then
    # Filter users above the GB limit
    TOP_LIST=""
    while read -r size username; do
        [ -z "$size" ] && continue
        gb=$(size_to_gb "$size")
        if [ -n "$gb" ] && (( $(echo "$gb >= $GB_LIMIT" | bc -l) )); then
            TOP_LIST+="$size"$'\t'"$username"$'\n'
        fi
    done <<< "$TOP_USERS"
    TOP_LIST=$(echo -e "$TOP_LIST" | sed '/^$/d')
    LIMIT_MSG="users above ${GB_LIMIT}GB"
else
    TOP_LIST=$(echo "$TOP_USERS" | head -n $TOP_N)
    LIMIT_MSG="top $TOP_N disk space users"
fi

# Compose the warning message
WARNING_MSG="🚨 DISK SPACE ALERT on $HOSTNAME 🚨

Disk space warning ($LIMIT_MSG) in /home:
$TOP_LIST

Please consider cleaning up:
- Run 'docker image prune' or 'docker image prune -a'
- Remove unused files, logs, and caches
- Check for large .pt model files

Thank you for helping keep the system healthy!"

# Show summary of users to be notified
if ($SEND_WALL || $SEND_MAIL || $DROP_WARNING) && [ -n "$TOP_LIST" ]; then
    echo ""
    echo "=== Users to be notified ($LIMIT_MSG) ==="
    echo "$TOP_LIST" | while read -r size username; do
        [ -n "$username" ] && echo "  - $username ($size)"
    done
    echo ""
fi

# Send wall message to logged-in users if --wall flag is set
if $SEND_WALL && [ -n "$TOP_LIST" ]; then
    echo "$WARNING_MSG" | wall
    echo "✓ Wall message sent to logged-in users."
fi

# Send mail to top users if --mail flag is set
if $SEND_MAIL && [ -n "$TOP_LIST" ]; then
    echo "$TOP_LIST" | while read -r size username; do
        if [ -n "$username" ]; then
            echo "$WARNING_MSG" | mail -s "Disk Space Alert on $HOSTNAME" "$username" 2>/dev/null && \
                echo "✓ Mail sent to $username" || \
                echo "✗ Failed to send mail to $username (mail not configured?)"
        fi
    done
fi

# Drop warning file in user home dirs if --warn flag is set
# Also adds a line to .bashrc to cat the warning on login
BASHRC_MARKER="# DISK_SPACE_WARNING_HOOK"
BASHRC_LINE='[ -f ~/DISK_SPACE_WARNING.txt ] && cat ~/DISK_SPACE_WARNING.txt'

if $DROP_WARNING && [ -n "$TOP_LIST" ]; then
    # Get sudo access - prompt for password if needed
    if ! sudo -v 2>/dev/null; then
        echo "✗ --warn requires sudo access to write to other users' home directories"
    else
        echo "$TOP_LIST" | while read -r size username; do
            if [ -n "$username" ] && [ -d "/home/$username" ]; then
                WARNING_FILE="/home/$username/DISK_SPACE_WARNING.txt"
                BASHRC_FILE="/home/$username/.bashrc"
                
                # Create/update warning file using sudo tee
                WARNING_CONTENT="$WARNING_MSG

Your usage: $size

This warning was generated on $(date).
Delete this file after cleaning up."
                
                if echo "$WARNING_CONTENT" | sudo -n tee "$WARNING_FILE" > /dev/null 2>&1; then
                    # Set ownership to the user
                    sudo -n chown "$username:$username" "$WARNING_FILE" 2>/dev/null
                    echo "✓ Warning file dropped in /home/$username/"
                    
                    # Add hook to .bashrc if not already present
                    if [ -f "$BASHRC_FILE" ] && ! grep -q "$BASHRC_MARKER" "$BASHRC_FILE" 2>/dev/null; then
                        echo "" | sudo -n tee -a "$BASHRC_FILE" > /dev/null 2>&1
                        echo "$BASHRC_MARKER" | sudo -n tee -a "$BASHRC_FILE" > /dev/null 2>&1
                        echo "$BASHRC_LINE" | sudo -n tee -a "$BASHRC_FILE" > /dev/null 2>&1 && \
                            echo "✓ Added warning hook to $BASHRC_FILE"
                    fi
                else
                    echo "✗ Could not write to /home/$username/"
                fi
            fi
        done
    fi
fi

echo " " >> $OUTPUT_FILE
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
