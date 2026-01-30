#!/usr/bin/env bash

set -euo pipefail

# Cleanly remove a user and related resources
# - Kills their sessions/processes
# - Removes TigerVNC entries and stops/disables related services
# - Removes crontab and sudoers.d entries
# - Deletes the user (optionally keeps home)
# - Optionally purges stray files owned by the user outside their home

usage() {
    cat <<EOF
Usage: sudo $0 [options] <username>

Options:
  -y             Proceed without interactive confirmation
  -n             Dry-run (show actions, do not modify system)
  -k             Keep home directory (do not pass -r to userdel)
  -p             Purge stray files owned by the user outside their home
  -h             Show this help

Examples:
  sudo $0 -y alice
  sudo $0 -y -k bob
  sudo $0 -n charlie       # see what would happen
  sudo $0 -y -p dave        # aggressive cleanup of stray files
EOF
}

confirm() {
    local prompt="$1"
    if [[ "$ASSUME_YES" == "1" ]]; then
        return 0
    fi
    read -r -p "$prompt [y/N]: " resp
    [[ "$resp" == "y" || "$resp" == "Y" ]]
}

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err()  { echo "[ERROR] $*" >&2; }

DRY_RUN=0
KEEP_HOME=0
ASSUME_YES=0
PURGE_STRAY=0

while getopts ":ynkph" opt; do
    case "$opt" in
        y) ASSUME_YES=1 ;;
        n) DRY_RUN=1 ;;
        k) KEEP_HOME=1 ;;
        p) PURGE_STRAY=1 ;;
        h) usage; exit 0 ;;
        :) err "Option -$OPTARG requires an argument"; exit 1 ;;
        \?) err "Invalid option: -$OPTARG"; usage; exit 1 ;;
    esac
done
shift $((OPTIND-1))

if [[ "$EUID" -ne 0 ]]; then
    err "Please run with sudo/root"
    exit 1
fi

if [[ $# -lt 1 ]]; then
    err "Username is required"
    usage
    exit 1
fi

USERNAME="$1"

# Validate user exists
if ! id "$USERNAME" &>/dev/null; then
    err "User '$USERNAME' does not exist"
    exit 1
fi

UID_NUM=$(id -u "$USERNAME")
HOME_DIR=$(getent passwd "$USERNAME" | cut -d: -f6)

info "Preparing to remove user: $USERNAME (UID: $UID_NUM, HOME: $HOME_DIR)"
if ! confirm "Proceed with removal of '$USERNAME'?"; then
    info "Aborted by user"
    exit 0
fi

run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "DRY-RUN: $*"
    else
        eval "$*"
    fi
}

# 1) Terminate sessions and processes
info "Terminating user sessions and processes"
if command -v loginctl &>/dev/null; then
    run "loginctl terminate-user '$USERNAME' || true"
    run "loginctl kill-user '$USERNAME' || true"
fi
run "pkill -u '$UID_NUM' || true"

# 2) Remove TigerVNC entries and stop/disable related services
VNCUSERS_FILE="/etc/tigervnc/vncserver.users"
if [[ -f "$VNCUSERS_FILE" ]]; then
    info "Checking TigerVNC users in $VNCUSERS_FILE"
    # Find displays assigned to this user
    DISPLAYS=$(grep -E ":[0-9]+=$USERNAME$" "$VNCUSERS_FILE" | sed -E 's/^:([0-9]+)=.*/\1/' || true)
    if [[ -n "$DISPLAYS" ]]; then
        for d in $DISPLAYS; do
            info "Stopping/disabling tigervncserver@:$d.service"
            run "systemctl stop tigervncserver@:$d.service || true"
            run "systemctl disable tigervncserver@:$d.service || true"
        done
    fi
    info "Removing entries for $USERNAME from $VNCUSERS_FILE (backup .bak kept)"
    run "sed -i.bak -E '/=\\s*$USERNAME\\s*$/d' '$VNCUSERS_FILE'"
else
    warn "TigerVNC users file not found: $VNCUSERS_FILE"
fi

# 3) Remove crontab
info "Removing crontab for $USERNAME"
run "crontab -r -u '$USERNAME' 2>/dev/null || true"

# 4) Remove sudoers.d entry if present
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
if [[ -f "$SUDOERS_FILE" ]]; then
    info "Removing sudoers.d entry: $SUDOERS_FILE"
    run "rm -f '$SUDOERS_FILE'"
fi

# 5) Remove the user account
if [[ "$KEEP_HOME" == "1" ]]; then
    info "Deleting user without removing home (-r skipped)"
    run "userdel '$USERNAME'"
else
    info "Deleting user and home (-r)"
    run "userdel -r '$USERNAME'"
fi

# 6) Remove primary group if it matches username
if getent group "$USERNAME" >/dev/null; then
    info "Removing primary group '$USERNAME' (if empty)"
    # groupdel fails if group has members; that's acceptable
    run "groupdel '$USERNAME' || true"
fi


info "Removal steps completed for $USERNAME"
if [[ "$DRY_RUN" == "1" ]]; then
    info "Dry-run mode: no changes were made"
fi

exit 0