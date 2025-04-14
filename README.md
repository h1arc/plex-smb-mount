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

## Usage

```bash
git clone https://github.com/yourusername/plex-smb-mount.git
cd plex-smb-mount
sudo bash plex-smb-mount.sh

---

## Do note this script is mostly for self usage so it could very well not work elsewhere.

