#!/bin/bash
set -euo pipefail

DEST="/mnt/data_1tb/backups"
STAMP=$(date +%Y%m%d-%H%M)
KEEP=7

mkdir -p "$DEST"

echo "[*] Stopping containers..."
docker stop plex deluge homepage >/dev/null 2>&1 || true

echo "[*] Archiving configs..."
sudo tar czf "$DEST/homelab-$STAMP.tar.gz" -C /home/george homelab homepage plex --exclude='homelab/.git' 2>/dev/null || true

echo "[*] Archiving portainer data..."
sudo tar czf "$DEST/portainer-$STAMP.tar.gz" -C /var/lib/docker/volumes portainer_data 2>/dev/null || true

echo "[*] Restarting containers..."
docker start plex deluge homepage >/dev/null 2>&1 || true

echo "[*] Pruning old backups..."
ls -1t "$DEST"/homelab-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r sudo rm --
ls -1t "$DEST"/portainer-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r sudo rm --

sudo chown -R george:george "$DEST"
echo "[OK] Backup complete:"
ls -lh "$DEST"
