#!/bin/bash

echo "🧩 Plex LXC SMB Share Auto-Mount Setup"

# Step 1: Gather info
read -p "Enter SMB server IP or hostname (e.g., 192.168.0.240): " SMB_HOST
read -p "Enter share name (e.g., plex): " SMB_SHARE
read -p "Enter LXC container ID (e.g., 150): " LXC_ID
read -p "Enter SMB username: " SMB_USER
read -p "Enter SMB password (will be shown): " SMB_PASS

# Step 2: Paths
MOUNT_DIR="/mnt/pve/unas-${SMB_SHARE// /-}-media"
CRED_FILE="/root/.smbcredentials-${SMB_SHARE// /-}"
LXC_CONF="/etc/pve/lxc/${LXC_ID}.conf"

# Step 3: Create credentials file
echo "Creating SMB credentials file at $CRED_FILE..."
echo -e "username=${SMB_USER}\npassword=${SMB_PASS}" > "$CRED_FILE"
chmod 600 "$CRED_FILE"

# Step 4: Create mount point and mount
echo "Creating mount point at $MOUNT_DIR..."
mkdir -p "$MOUNT_DIR"

echo "Mounting SMB share..."
mount -t cifs "//${SMB_HOST}/${SMB_SHARE}" "$MOUNT_DIR" \
  -o credentials="$CRED_FILE",vers=3.0,uid=999,gid=990

if [ $? -ne 0 ]; then
  echo "❌ Mount failed. Check credentials, share path, or network."
  exit 1
fi

echo "✅ Share mounted successfully."

# Step 5: Add to /etc/fstab
FSTAB_LINE="//${SMB_HOST}/${SMB_SHARE} ${MOUNT_DIR} cifs credentials=${CRED_FILE},vers=3.0,uid=999,gid=990,x-systemd.automount 0 0"
if ! grep -Fxq "$FSTAB_LINE" /etc/fstab; then
  echo "Adding mount to /etc/fstab..."
  echo "$FSTAB_LINE" >> /etc/fstab
else
  echo "Mount already exists in /etc/fstab."
fi

# Step 6: Add bind mount to LXC config
MP_LINE="mp0: $MOUNT_DIR,mp=/mnt/media"
if ! grep -Fxq "$MP_LINE" "$LXC_CONF"; then
  echo "Adding mount to $LXC_CONF..."
  echo "$MP_LINE" >> "$LXC_CONF"
else
  echo "LXC config already contains mount."
fi

# Final Step: Done
echo "✅ All done!"
echo "You can restart your LXC now: pct restart $LXC_ID"
echo "Your Plex container will have access to: /mnt/media"
