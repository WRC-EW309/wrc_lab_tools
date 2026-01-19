#!/bin/bash
# Script to update wrc_lab_tools in all student virtual environments
# Run this from the wrc account after changing pyproject.toml

# Define student accounts and their venv paths
# Modify this array based on your setup
STUDENT_ENVS=(
    "/home/team1/.surfer/surfer_env"
    "/home/team2/.surfer/surfer_env"
)

# Or auto-discover all .surfer/surfer_env directories
# STUDENT_ENVS=($(find /home/*/. -maxdepth 2 -path "*/.surfer/surfer_env" -type d 2>/dev/null))

echo "🔄 Updating wrc_lab_tools in all student environments..."
echo ""

SUCCESS=0
FAILED=0

for VENV_PATH in "${STUDENT_ENVS[@]}"; do
    if [ -d "$VENV_PATH" ]; then
        STUDENT=$(echo $VENV_PATH | cut -d'/' -f3)
        echo "Updating for $STUDENT..."
        
        # Run pip install as the student user
        sudo -u $STUDENT $VENV_PATH/bin/pip install -q -e /home/wrc/wrc_lab_tools
        
        if [ $? -eq 0 ]; then
            echo "  ✅ Success: $STUDENT"
            ((SUCCESS++))
        else
            echo "  ❌ Failed: $STUDENT"
            ((FAILED++))
        fi
    else
        echo "⚠️  Skipping: $VENV_PATH (not found)"
    fi
    echo ""
done

echo "═══════════════════════════════"
echo "Summary: $SUCCESS successful, $FAILED failed"
echo "═══════════════════════════════"
