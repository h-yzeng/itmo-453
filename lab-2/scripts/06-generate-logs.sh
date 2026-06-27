#!/bin/bash
# 06-generate-logs.sh
# Collects key system status information into a single timestamped log file.
# Intended to run on a schedule via cron to produce ongoing maintenance records.

set -euo pipefail

LOG_DIR="/var/log/lab2-automation"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="${LOG_DIR}/maintenance-${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

{
  echo "Maintenance log generated $(date '+%Y-%m-%d %H:%M:%S')"
  echo "---- Disk usage ----"
  df -h
  echo "---- Memory usage ----"
  free -h
  echo "---- Active services ----"
  systemctl list-units --type=service --state=running --no-pager
  echo "---- Last 20 auth log entries ----"
  tail -n 20 /var/log/auth.log 2>/dev/null || echo "auth.log not available"
} > "$LOG_FILE"

echo "Log written to $LOG_FILE"

# Keep only the 30 most recent maintenance logs to control disk usage
find "$LOG_DIR" -name "maintenance-*.log" -type f | sort | head -n -30 | xargs -r rm -f
