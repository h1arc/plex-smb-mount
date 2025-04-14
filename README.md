# Plex LXV SMB Mount on Proxmox

📦 A simple Bash script to securely mount an SMB share for a Plex LXC container on Proxmox.  
✅ Supports persistent mounts, secure credential handling, and automatic LXC config updates.

---

## Features

- Mounts SMB shares securely using `.smbcredentials`
- Persists mounts via `/etc/fstab`
- Automatically adds bind mount to the specified LXC container config
- Optimized for Plex setups using `/mnt/media`

---

## Requirements

- Proxmox host (Debian/Ubuntu-based)
- SMB/CIFS support (`cifs-utils` installed)
- LXC container running Ubuntu/Debian
- Plex running inside the LXC

---

## 🚀 Quick Usage (One-Liner)

Run this on your Proxmox host:

```bash
wget -O - https://raw.githubusercontent.com/h1arc/plex-smb-mount/main/plex-smb-mount.sh | sudo bash

```

---

## Do note this script is mostly for self usage so it could very well not work elsewhere.

