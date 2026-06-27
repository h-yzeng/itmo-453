#!/bin/bash
# 05-configure-firewall.sh
# Configures UFW with a deny-by-default policy and opens only required ports.

set -euo pipefail

LOG_FILE="/var/log/lab2-automation/configure-firewall.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "$(date '+%Y-%m-%d %H:%M:%S') Configuring firewall" | tee -a "$LOG_FILE"

ufw default deny incoming >> "$LOG_FILE" 2>&1
ufw default allow outgoing >> "$LOG_FILE" 2>&1

ufw allow 22/tcp comment "SSH" >> "$LOG_FILE" 2>&1
ufw allow 80/tcp comment "HTTP" >> "$LOG_FILE" 2>&1
ufw allow 443/tcp comment "HTTPS" >> "$LOG_FILE" 2>&1

ufw --force enable >> "$LOG_FILE" 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') Firewall configuration complete" | tee -a "$LOG_FILE"
ufw status verbose | tee -a "$LOG_FILE"
