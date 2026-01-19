#!/bin/bash
# Auto-update script for student virtual environments

TOML_FILE="/home/wrc/wrc_lab_tools/pyproject.toml"
MARKER_FILE="$VIRTUAL_ENV/.wrc_lab_tools_timestamp"

# Check if we're in a virtual environment
if [ -z "$VIRTUAL_ENV" ]; then
    exit 0
fi

# If marker doesn't exist or toml is newer, reinstall
if [ ! -f "$MARKER_FILE" ] || [ "$TOML_FILE" -nt "$MARKER_FILE" ]; then
    echo "🔄 Updating wrc_lab_tools..."
    pip install -q -e /home/wrc/wrc_lab_tools
    touch "$MARKER_FILE"
    echo "✅ wrc_lab_tools updated!"
fi
