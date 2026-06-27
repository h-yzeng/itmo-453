#!/bin/bash
# 01-update-system.sh
# Updates package lists and upgrades all installed packages.
# Logs all output to /var/log/lab2-automation/update-system.log

set -euo pipefail

LOG_DIR="/var/log/lab2-automation"
LOG_FILE="${LOG_DIR}/update-system.log"

mkdir -p "$LOG_DIR"

echo "$(date '+%Y-%m-%d %H:%M:%S') Starting system update" | tee -a "$LOG_FILE"

apt-get update -y >> "$LOG_FILE" 2>&1
apt-get upgrade -y >> "$LOG_FILE" 2>&1
apt-get autoremove -y >> "$LOG_FILE" 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') System update complete" | tee -a "$LOG_FILE"
