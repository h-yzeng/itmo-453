#!/bin/bash
# 07-backup-dirs.sh
# Creates a standard backup directory structure with correct ownership
# and permissions. Designed to be idempotent for repeated runs.

set -euo pipefail

LOG_FILE="/var/log/lab2-automation/backup-dirs.log"
mkdir -p "$(dirname "$LOG_FILE")"

BACKUP_ROOT="/backups"
SUBDIRS=("web" "database" "config")

mkdir -p "$BACKUP_ROOT"
chmod 750 "$BACKUP_ROOT"

for sub in "${SUBDIRS[@]}"; do
  target="${BACKUP_ROOT}/${sub}"
  if [ -d "$target" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $target already exists, skipping" | tee -a "$LOG_FILE"
  else
    mkdir -p "$target"
    chmod 750 "$target"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Created $target" | tee -a "$LOG_FILE"
  fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') Backup directory setup complete" | tee -a "$LOG_FILE"
