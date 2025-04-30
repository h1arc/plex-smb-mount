#!/bin/bash

# one liner as root (or via sudo)
# bash <(wget -qO- https://raw.githubusercontent.com/h1arc/plex-smb-mount/main/plex-smb-mount.sh)

# --- CONFIGURATION ---
SHARE="//192.168.5.10/plex"
MOUNT_POINT="/mnt/plex-media"
CREDENTIALS_FILE="/root/.smbcredentials"
CONTAINER_MOUNT_PATH="/mnt/plex-media"
SMB_VERSION="3.0"

echo "=== Starting Plex SMB share setup ==="

# --- 0. Prompt for credentials and container ID ---
read -p "Enter SMB username: " SMB_USER
read -p "Enter SMB password (visible): " SMB_PASS
read -p "Enter Plex Media Server container ID (e.g., 150): " CONTAINER_ID

# --- 1. Get Plex UID and GID from container ---
echo "[1/6] Detecting Plex UID and GID from container $CONTAINER_ID..."
PUID=$(pct exec "$CONTAINER_ID" -- id -u plex)
PGID=$(pct exec "$CONTAINER_ID" -- id -g plex)
echo "ℹ️ Using PUID=$PUID and PGID=$PGID"

# --- 2. Create or overwrite credentials file ---
echo "[2/6] Writing credentials to $CREDENTIALS_FILE..."
cat <<EOF > "$CREDENTIALS_FILE"
username=$SMB_USER
password=$SMB_PASS
EOF
chmod 600 "$CREDENTIALS_FILE"
echo "✅ Credentials file written."

# --- 3. Create mount point ---
echo "[3/6] Checking mount point at $MOUNT_POINT..."
if [ -d "$MOUNT_POINT" ]; then
    echo "ℹ️ Mount point already exists."
else
    echo "📁 Creating mount point directory..."
    mkdir -p "$MOUNT_POINT"
fi

# --- 4. Replace or add fstab entry ---
echo "[4/6] Updating /etc/fstab..."
# Remove existing entry for this mount point
sed -i "\|$MOUNT_POINT|d" /etc/fstab

# Add new entry
FSTAB_LINE="$SHARE $MOUNT_POINT cifs credentials=$CREDENTIALS_FILE,uid=$PUID,gid=$PGID,vers=$SMB_VERSION,nofail,x-systemd.automount,_netdev 0 0"
echo "$FSTAB_LINE" >> /etc/fstab
echo "✅ fstab updated with new entry."

# --- 5. Reload systemd and start automount ---
echo "[5/6] Reloading systemd and activating automount..."
systemctl daemon-reload

UNIT_NAME=$(systemd-escape -p --suffix=automount "$MOUNT_POINT")
systemctl start "$UNIT_NAME"
echo "✅ Automount unit $UNIT_NAME started."

# --- 6. Update LXC container config with bind mount ---
echo "[6/6] Configuring container $CONTAINER_ID bind mount..."
LXC_CONF="/etc/pve/lxc/$CONTAINER_ID.conf"
# Remove any existing mount line using this host path
sed -i "\|$MOUNT_POINT|d" "$LXC_CONF"

# Add new bind mount
echo "mp0: $MOUNT_POINT,mp=$CONTAINER_MOUNT_PATH" >> "$LXC_CONF"
echo "✅ Container config updated."

# --- Reboot the container ---
echo "🔁 Rebooting container $CONTAINER_ID..."
pct reboot "$CONTAINER_ID"

echo "✅ Setup complete. SMB share will auto-mount and is available in container $CONTAINER_ID at $CONTAINER_MOUNT_PATH."
