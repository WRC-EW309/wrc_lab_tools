#!/bin/bash
# Script to create a new user with surfer workspace access

if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

SURFER=false
TURRET=false

# Parse flags anywhere before positional args
while [ $# -gt 0 ]; do
    case "$1" in
        -s) SURFER=true; shift ;;
        -t) TURRET=true; shift ;;
        --) shift; break ;;
        -*) echo "Invalid option: $1"; echo "Usage: sudo $0 [-s] [-t] <username> [password]"; exit 1 ;;
        *) break ;;
    esac
done

if [ -z "$1" ]; then
    echo "Usage: sudo $0 [-s] [-t] <username> [password]"
    exit 1
fi

USERNAME=$1
PASSWORD=${2:-$USERNAME}
WORKSPACE_DIR="/home/$USERNAME/ew309_workspace"

echo "Creating user: $USERNAME"

# 1. Create user with home directory
useradd -m -s /bin/bash "$USERNAME"
if [ $? -ne 0 ]; then
    echo "Failed to create user"
    exit 1
fi

# 2. Set password (defaults to username)
echo "$USERNAME:$PASSWORD" | chpasswd
echo "✓ Password set"

# 3. Add to surfers group and other standard groups
usermod -aG surfers,video,audio,input,dialout,plugdev,netdev,docker "$USERNAME"
echo "✓ Added to groups: surfers, video, audio, input, dialout, plugdev, netdev, docker"

# 4. Copy standard config files
cp /home/wrc/.bashrc /home/$USERNAME/ 2>/dev/null

if [ "$SURFER" = true ]; then
    echo "setup surfer environment in .bashrc"
    echo "source /home/$USERNAME/.surfer/surfer_env/bin/activate" >> /home/$USERNAME/.bashrc 2>/dev/null || true

    # 5. Create fresh .surfer/surfer_env directory
    mkdir -p /home/$USERNAME/.surfer
    PYTHON_PATH=$(/home/wrc/.surfer/surfer_env/bin/python -c "import sys; print(sys.executable)" 2>/dev/null)
    if [ -n "$PYTHON_PATH" ]; then
        $PYTHON_PATH -m venv /home/$USERNAME/.surfer/surfer_env
        chown -R $USERNAME:$USERNAME /home/$USERNAME/.surfer
        echo "✓ Created fresh .surfer/surfer_env directory"
    fi
    
    if [ -d /home/$USERNAME/.surfer/surfer_env ]; then
        # Install shared wrc_lab_tools in editable mode
        if [ -d /home/wrc/wrc_lab_tools ]; then
            # Ensure library is readable and writable by surfers group
            chmod -R g+w /home/wrc/wrc_lab_tools
            rm -rf /home/wrc/wrc_lab_tools/*.egg-info /home/wrc/wrc_lab_tools/build 2>/dev/null
            echo "Installing wrc_lab_tools in editable mode for surfer environment..."
            if su - $USERNAME -c "/home/$USERNAME/.surfer/surfer_env/bin/pip install -e /home/wrc/wrc_lab_tools"; then
                echo "✓ Installed wrc_lab_tools in editable mode for surfer environment"
            else
                echo "⚠ Warning: Failed to install wrc_lab_tools, check permissions and library path"
            fi
        else
            echo "⚠ Warning: /home/wrc/wrc_lab_tools not found, skipping editable install"
        fi
    else
        echo "⚠ Warning: /home/wrc/.surfer/surfer_env not found, skipping"
    fi

fi

if [ "$TURRET" = true ]; then
    echo "setup turret environment in .bashrc"
    echo "source /home/$USERNAME/.turret/turret_env/bin/activate" >> /home/$USERNAME/.bashrc 2>/dev/null || true

    # 5. Create fresh .turret/turret_env directory
    mkdir -p /home/$USERNAME/.turret
    PYTHON_PATH=$(/home/wrc/.turret/turret_env/bin/python -c "import sys; print(sys.executable)" 2>/dev/null)
    if [ -n "$PYTHON_PATH" ]; then
        $PYTHON_PATH -m venv /home/$USERNAME/.turret/turret_env
        chown -R $USERNAME:$USERNAME /home/$USERNAME/.turret
        echo "✓ Created fresh .turret/turret_env directory"
    fi
    
    if [ -d /home/$USERNAME/.turret/turret_env ]; then
        # Install shared wrc_lab_tools in editable mode
        if [ -d /home/wrc/wrc_lab_tools ]; then
            # Ensure library is readable and writable by surfers group
            chmod -R g+w /home/wrc/wrc_lab_tools
            rm -rf /home/wrc/wrc_lab_tools/*.egg-info /home/wrc/wrc_lab_tools/build 2>/dev/null
            echo "Installing wrc_lab_tools in editable mode for turret environment..."
            if su - $USERNAME -c "/home/$USERNAME/.turret/turret_env/bin/pip install -e /home/wrc/wrc_lab_tools"; then
                echo "✓ Installed wrc_lab_tools in editable mode for turret environment"
            else
                echo "⚠ Warning: Failed to install wrc_lab_tools, check permissions and library path"
            fi
        else
            echo "⚠ Warning: /home/wrc/wrc_lab_tools not found, skipping editable install"
        fi
    else
        echo "⚠ Warning: /home/wrc/.turret/turret_env not found, skipping"
    fi
fi

cp /home/wrc/.bash_profile /home/$USERNAME/ 2>/dev/null || true
cp /home/wrc/.profile /home/$USERNAME/ 2>/dev/null || true
echo "✓ Copied shell config files"

# 4a. Copy .config directory
if [ -d /home/wrc/.config ]; then
    cp -r /home/wrc/.config /home/$USERNAME/
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
    echo "✓ Copied .config directory"
else
    echo "⚠ Warning: /home/wrc/.config not found, skipping"
fi

# 4b. Copy GTK configuration files
cp /home/wrc/.gtkrc-2.0 /home/$USERNAME/ 2>/dev/null && echo "✓ Copied .gtkrc-2.0" || true

# # 5. Copy .surfer/surfer_env directory
# if [ -d /home/wrc/.surfer/surfer_env ]; then
#     mkdir -p /home/$USERNAME/.surfer
#     cp -r /home/wrc/.surfer/surfer_env /home/$USERNAME/.surfer/
#     chown -R $USERNAME:$USERNAME /home/$USERNAME/.surfer
#     echo "✓ Copied .surfer/surfer_env directory"
# else
#     echo "⚠ Warning: /home/wrc/.surfer/surfer_env not found, skipping"
# fi

# 6. Create ew309_workspace directory
mkdir -p /home/$USERNAME/ew309_workspace
chown $USERNAME:$USERNAME /home/$USERNAME/ew309_workspace
echo "✓ Created ew309_workspace directory"

# 7. Create symlinks to wrc's data_logs, videos, and oak_models
ln -s /home/wrc/main_workspace/data_logs /home/$USERNAME/ew309_workspace/data_logs
ln -s /home/wrc/main_workspace/videos /home/$USERNAME/ew309_workspace/videos
ln -s /home/wrc/main_workspace/oak_models /home/$USERNAME/ew309_workspace/oak_models
echo "✓ Created symlinks for data_logs, videos, and oak_models"

# 8. Ensure ACLs are set for access
setfacl -m g:surfers:x /home/wrc
setfacl -m g:surfers:x /home/wrc/main_workspace
setfacl -R -m g:surfers:rwx /home/wrc/main_workspace/data_logs
setfacl -R -m g:surfers:rwx /home/wrc/main_workspace/videos
setfacl -R -m g:surfers:rwx /home/wrc/main_workspace/oak_models
setfacl -R -d -m g:surfers:rwx /home/wrc/main_workspace/data_logs
setfacl -R -d -m g:surfers:rwx /home/wrc/main_workspace/videos
setfacl -R -d -m g:surfers:rwx /home/wrc/main_workspace/oak_models
echo "✓ Set ACL permissions"

# 9. Ensure proper group ownership
chgrp -R surfers /home/wrc/main_workspace/data_logs
chgrp -R surfers /home/wrc/main_workspace/videos
chgrp -R surfers /home/wrc/main_workspace/oak_models
echo "✓ Set group ownership"

# 10. Add user to TigerVNC server users file
VNCUSERS_FILE="/etc/tigervnc/vncserver.users"
if [ -f "$VNCUSERS_FILE" ]; then
    # Find the next available display number
    NEXT_DISPLAY=$(grep -oP '(?<=:)\d+' "$VNCUSERS_FILE" | sort -n | tail -1)
    NEXT_DISPLAY=$((NEXT_DISPLAY + 1))
    
    # Add user to VNC users file
    echo ":$NEXT_DISPLAY=$USERNAME" >> "$VNCUSERS_FILE"
    echo "✓ Added $USERNAME to VNC server on display :$NEXT_DISPLAY"
    
    # Copy VNC xstartup file
    mkdir -p /home/$USERNAME/.vnc
    if [ -f /home/wrc/.vnc/xstartup ]; then
        cp /home/wrc/.vnc/xstartup /home/$USERNAME/.vnc/
        chmod +x /home/$USERNAME/.vnc/xstartup
        chown -R $USERNAME:$USERNAME /home/$USERNAME/.vnc
        echo "✓ Copied VNC xstartup configuration"

        # Set VNC password to match main login password
        VNC_PASSWORD="$PASSWORD"
        echo "$VNC_PASSWORD" | su - $USERNAME -c "tigervncpasswd -f" > /home/$USERNAME/.config/tigervnc/passwd 2>/dev/null
        chmod 600 /home/$USERNAME/.config/tigervnc/passwd
        chown $USERNAME:$USERNAME /home/$USERNAME/.config/tigervnc/passwd
        echo "✓ Set VNC password to match login password"
    
        # Start and enable VNC server for this user
        systemctl start tigervncserver@:$NEXT_DISPLAY.service
        systemctl enable tigervncserver@:$NEXT_DISPLAY.service
        echo "✓ Started and enabled VNC server on display :$NEXT_DISPLAY"
    fi
else
    echo "⚠ Warning: $VNCUSERS_FILE not found, skipping VNC setup"
fi

echo ""
echo "✅ User $USERNAME created successfully!"
echo ""
echo "User can now:"
echo "  - SSH in: ssh $USERNAME@raspberrypi.local"
if [ ! -z "$NEXT_DISPLAY" ]; then
    echo "  - VNC to display :$NEXT_DISPLAY (port 590$NEXT_DISPLAY) - VNC server is running"
    echo "  - Default VNC password equals the login password"
fi
echo "  - Access data_logs: ~/ew309_workspace/data_logs"
echo "  - Access videos: ~/ew309_workspace/videos"
echo "  - Access oak_models: ~/ew309_workspace/oak_models"
echo ""
echo "To test symlinks, login as $USERNAME and run:"
echo "  ls ~/ew309_workspace/data_logs"
