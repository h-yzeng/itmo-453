#!/usr/bin/env bash
# Name: Tenzor
# Date: 07/12/2026
# Course Number: ITMO-453
# Assignment: Final Project
# Description: Archives every persistent Docker volume and prunes backups older than seven days.

set -euo pipefail

BACKUP_DIR="$HOME/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
VOLUMES="itmo453_grafana-data itmo453_prometheus-data itmo453_loki-data itmo453_kuma-data"

mkdir -p "$BACKUP_DIR"

for VOL in $VOLUMES; do
  docker run --rm -v "$VOL":/src:ro -v "$BACKUP_DIR":/dst alpine tar czf "/dst/$VOL-$STAMP.tar.gz" -C /src .
done

find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup complete $STAMP"
