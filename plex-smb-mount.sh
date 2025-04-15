#!/bin/bash

# Main function to gather info, set up the SMB share, and configure LXC
function gather_info() {
  echo "🧩 Plex LXC SMB Share Auto-Mount Setup"
  # Prompt the user for SMB connection details
  read -p "Enter SMB server IP or hostname (e.g., 192.168.0.240): " SMB_HOST
  read -p "Enter share name (e.g., plex): " SMB_SHARE
  read -p "Enter LXC container ID (e.g., 150): " LXC_ID
  read -p "Enter SMB username: " SMB_USER
  read -p "Enter SMB password (will be shown): " SMB_PASS

  # Ask for UID/GID or use defaults
  read -p "Enter desired UID (default 999): " userUID
  UID=${userUID:-999}
  read -p "Enter desired GID (default 990): " userGID
  GID=${userGID:-990}

  # Global variables for paths and config
  MOUNT_DIR="/mnt/pve/unas-${SMB_SHARE// /-}-media"
  CRED_FILE="/root/.smbcredentials-${SMB_SHARE// /-}"
  LXC_CONF="/etc/pve/lxc/${LXC_ID}.conf"

  # Line to add to /etc/fstab so the share can be mounted automatically
  FSTAB_LINE="//${SMB_HOST}/${SMB_SHARE} ${MOUNT_DIR} cifs credentials=${CRED_FILE},vers=3.0,uid=$UID,gid=$GID,x-systemd.automount 0 0"
  # Line to add to LXC config so it can see the mounted directory
  MP_LINE="mp0: $MOUNT_DIR,mp=/mnt/media"
}

# Function to mount the SMB share using collected variables
function mount_share() {
  echo "Mounting SMB share..."
  mount -t cifs "//${SMB_HOST}/${SMB_SHARE}" "$MOUNT_DIR" \
    -o credentials="$CRED_FILE",vers=3.0,uid=$UID,gid=$GID
  if [ $? -ne 0 ]; then
    echo "❌ Mount failed. Check credentials, share path, or network."
    exit 1
  fi
  echo "✅ Share mounted successfully."
}

# Function to create a credentials file with user and password
function create_credentials_file() {
  echo "Creating SMB credentials file at $CRED_FILE..."
  echo -e "username=${SMB_USER}\npassword=${SMB_PASS}" >"$CRED_FILE"
  chmod 600 "$CRED_FILE" # Restrict file permissions for security
}

# Function to create the local mount directory
function create_mount_point() {
  echo "Creating mount point at $MOUNT_DIR..."
  mkdir -p "$MOUNT_DIR"
}

# Duplicate function named 'mount_share' - note it uses hardcoded UID/GID = 999/990
function mount_share() {
  echo "Mounting SMB share..."
  mount -t cifs "//${SMB_HOST}/${SMB_SHARE}" "$MOUNT_DIR" \
    -o credentials="$CRED_FILE",vers=3.0,uid=999,gid=990
  if [ $? -ne 0 ]; then
    echo "❌ Mount failed. Check credentials, share path, or network."
    exit 1
  fi
  echo "✅ Share mounted successfully."
}

# Function to add the SMB mount entry to /etc/fstab for auto-mounting
function add_to_fstab() {
  if ! grep -Fxq "$FSTAB_LINE" /etc/fstab; then
    echo "Adding mount to /etc/fstab..."
    echo "$FSTAB_LINE" >>/etc/fstab
  else
    echo "Mount already exists in /etc/fstab."
  fi
}

# Function to add a bind mount entry to the specified LXC config
function add_bind_mount() {
  if ! grep -Fxq "$MP_LINE" "$LXC_CONF"; then
    echo "Adding mount to $LXC_CONF..."
    echo "$MP_LINE" >>"$LXC_CONF"
  else
    echo "LXC config already contains mount."
  fi
}

# Main orchestrating function: calls each step in sequence
function main() {
  gather_info
  create_credentials_file
  create_mount_point
  mount_share
  add_to_fstab
  add_bind_mount
  echo "✅ All done!"
  # Inform user about next steps
  echo "You can restart your LXC now: pct restart $LXC_ID"
  echo "Your Plex container will have access to: /mnt/media"
}

# Execute the main function
main
