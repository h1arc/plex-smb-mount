#!/usr/bin/env bash

# one liner as root (or via sudo)
# bash <(wget -qO- https://raw.githubusercontent.com/h1arc/plex-smb-mount/main/plex-smb-mount.sh)

# Exit on error, unset var or pipe failure
set -euo pipefail

# LOG: prints timestamped messages
LOG() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

# cleanup: remove credentials file on exit if it exists
cleanup() {
    [[ -n "${CREDENTIALS_FILE:-}" && -f "$CREDENTIALS_FILE" ]] && rm -f "$CREDENTIALS_FILE"
}
trap cleanup EXIT

# --- CONFIGURATION ---
SHARE="//192.168.5.10/plex"            # SMB share path
MOUNT_POINT="/mnt/plex-media"          # Local mount directory
SMB_VERSION="3.0"                      # SMB protocol version
CONTAINER_MOUNT_PATH="/mnt/plex-media" # Path inside Plex LXC

# prompt_credentials: ask user for SMB creds and container ID
prompt_credentials() {
    read -p "Enter SMB username: " SMB_USER
    read -p "Enter SMB password: " SMB_PASS # unmasked per preference
    echo
    read -p "Enter Plex container ID: " CONTAINER_ID
}

# detect_ids: get plex user UID/GID from LXC container
detect_ids() {
    LOG "[1/6] Detecting Plex UID/GID..."
    PUID=$(pct exec "$CONTAINER_ID" -- id -u plex)
    PGID=$(pct exec "$CONTAINER_ID" -- id -g plex)
    LOG "Detected PUID=$PUID PGID=$PGID"
}

# write_credentials: store creds in a secure temp file
write_credentials() {
    LOG "[2/6] Writing credentials..."
    CREDENTIALS_FILE=$(mktemp)
    chmod 600 "$CREDENTIALS_FILE"
    cat >"$CREDENTIALS_FILE" <<EOF
username=$SMB_USER
password=$SMB_PASS
EOF
}

# prepare_mountpoint: ensure the mount directory exists
prepare_mountpoint() {
    LOG "[3/6] Ensuring mount point $MOUNT_POINT exists..."
    mkdir -p "$MOUNT_POINT"
}

# update_fstab: add or replace the CIFS entry in /etc/fstab
update_fstab() {
    LOG "[4/6] Updating /etc/fstab..."
    local opts="credentials=$CREDENTIALS_FILE,uid=$PUID,gid=$PGID,vers=$SMB_VERSION,nofail,x-systemd.automount,_netdev"
    local line="$SHARE $MOUNT_POINT cifs $opts 0 0"
    # remove any existing entry for this mount point
    grep -qF "$MOUNT_POINT" /etc/fstab &&
        sed -i "\|$MOUNT_POINT|d" /etc/fstab
    echo "$line" >>/etc/fstab
}

# activate_automount: reload systemd and start the automount unit
activate_automount() {
    LOG "[5/6] Reloading systemd & starting automount..."
    systemctl daemon-reload
    local unit=$(systemd-escape -p --suffix=automount "$MOUNT_POINT")
    systemctl start "$unit"
}

# configure_container: bind-mount host directory into LXC and reboot
configure_container() {
    LOG "[6/6] Configuring LXC container bind mount..."
-   pct set "$CONTAINER_ID" \
-       -mp0 host_path="$MOUNT_POINT",mp="$CONTAINER_MOUNT_PATH"
+   pct set "$CONTAINER_ID" \
+       -mp0 "$MOUNT_POINT,mp=$CONTAINER_MOUNT_PATH"
    LOG "Rebooting container..."
    pct reboot "$CONTAINER_ID"
}

# main: orchestrates all steps
main() {
    LOG "=== Starting Plex SMB share setup ==="
    prompt_credentials
    detect_ids
    write_credentials
    prepare_mountpoint
    update_fstab
    activate_automount
    configure_container
    LOG "✅ Setup complete."
}

main "$@"
