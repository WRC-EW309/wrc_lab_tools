#!/bin/bash
# Setup script for student accounts

VENV_PATH="${1:-$HOME/.surfer/surfer_env}"
ACTIVATE_SCRIPT="$VENV_PATH/bin/activate"

echo "Setting up auto-update for virtual environment: $VENV_PATH"

# Add the check to activation script
if ! grep -q "check_and_update.sh" "$ACTIVATE_SCRIPT" 2>/dev/null; then
    cat >> "$ACTIVATE_SCRIPT" << 'EOF'

# Auto-update wrc_lab_tools
if [ -f "/home/wrc/wrc_lab_tools/scripts/check_and_update.sh" ]; then
    bash /home/wrc/wrc_lab_tools/scripts/check_and_update.sh
fi
EOF
    echo "✅ Auto-update hook added to virtual environment"
else
    echo "✅ Auto-update hook already exists"
fi

echo "Done! The environment will now check for updates on activation."
