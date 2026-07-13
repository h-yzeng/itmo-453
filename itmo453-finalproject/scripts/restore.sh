#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: restore.sh <timestamp>"
  echo "Example: restore.sh 20260712-030000"
  exit 1
fi

STAMP="$1"
BACKUP_DIR="$HOME/backups"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VOLUMES="itmo453_grafana-data itmo453_prometheus-data itmo453_loki-data itmo453_kuma-data"

cd "$REPO_DIR"
docker compose down

for VOL in $VOLUMES; do
  FILE="$BACKUP_DIR/$VOL-$STAMP.tar.gz"
  if [ ! -f "$FILE" ]; then
    echo "Missing $FILE"
    exit 1
  fi
  docker volume create "$VOL" >/dev/null
  docker run --rm -v "$VOL":/dst -v "$BACKUP_DIR":/backup:ro alpine sh -c "find /dst -mindepth 1 -delete && tar xzf /backup/$VOL-$STAMP.tar.gz -C /dst"
done

docker compose up -d

echo "Restore complete"
