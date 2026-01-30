#!/bin/bash

# Configuration - CUSTOMIZE THESE
LOCAL_DIR="/home/wrc/main_workspace/oak_models"
REMOTE_HOST="wrc@192.168.2.1"
REMOTE_DIR="/home/wrc/surfer_workspace/oak_models"
RSYNC_OPTIONS="-avz --delete"  # Archive, verbose, compress, delete files on remote not in local
SSH_KEY="/home/wrc/.ssh/id_ed25519"  # Path to your SSH private key
LOG_FILE="/var/log/oak_models_sync.log"

# Function to perform sync
perform_sync() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Change detected. Starting rsync..." >> "$LOG_FILE"
    
    # Build rsync command with optional SSH key
    if [ -n "$SSH_KEY" ]; then
        rsync $RSYNC_OPTIONS -e "ssh -i $SSH_KEY" "$LOCAL_DIR/" "$REMOTE_HOST:$REMOTE_DIR/"
    else
        rsync $RSYNC_OPTIONS "$LOCAL_DIR/" "$REMOTE_HOST:$REMOTE_DIR/"
    fi
    
    if [ $? -eq 0 ]; then
        echo "[$timestamp] Rsync completed successfully" >> "$LOG_FILE"
    else
        echo "[$timestamp] Rsync failed with exit code $?" >> "$LOG_FILE"
    fi
}

# Check if inotifywait is installed
if ! command -v inotifywait &> /dev/null; then
    echo "Error: inotifywait not found. Install it with:"
    echo "  sudo apt install inotify-tools  (Debian/Ubuntu)"
    echo "  sudo yum install inotify-tools   (CentOS/RHEL)"
    exit 1
fi

# Check if rsync is installed
if ! command -v rsync &> /dev/null; then
    echo "Error: rsync not found. Install it with: sudo apt install rsync"
    exit 1
fi

# Verify local directory exists
if [ ! -d "$LOCAL_DIR" ]; then
    echo "Error: Local directory does not exist: $LOCAL_DIR"
    exit 1
fi

# Create log file
touch "$LOG_FILE" 2>/dev/null || {
    LOG_FILE="/tmp/oak_models_sync.log"
    touch "$LOG_FILE"
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitoring started for $LOCAL_DIR" >> "$LOG_FILE"
echo "Monitoring $LOCAL_DIR for changes..."
echo "Syncing to: $REMOTE_HOST:$REMOTE_DIR"
echo "Log file: $LOG_FILE"

# Perform initial sync
perform_sync

# Monitor directory for changes (file modifications, creations, deletions)
inotifywait -m -r \
    -e modify,create,delete,moved_to,moved_from \
    --exclude '(\.git|\.tmp|__pycache__|\.pytest_cache)' \
    "$LOCAL_DIR" |
while read -r path action file; do
    # Debounce: wait a bit for multiple rapid changes to settle
    sleep 2
    perform_sync
done
