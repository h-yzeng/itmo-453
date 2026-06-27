#!/bin/bash
# 02-install-packages.sh
# Installs the baseline package set needed for the lab environment.
# Packages are listed in an array so the list can be extended easily.

set -euo pipefail

LOG_FILE="/var/log/lab2-automation/install-packages.log"
mkdir -p "$(dirname "$LOG_FILE")"

PACKAGES=(
  nginx
  ufw
  fail2ban
  curl
  git
  docker.io
  ansible
)

echo "$(date '+%Y-%m-%d %H:%M:%S') Installing packages: ${PACKAGES[*]}" | tee -a "$LOG_FILE"

apt-get update -y >> "$LOG_FILE" 2>&1

for pkg in "${PACKAGES[@]}"; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $pkg already installed, skipping" | tee -a "$LOG_FILE"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') Installing $pkg" | tee -a "$LOG_FILE"
    apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1
  fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') Package installation complete" | tee -a "$LOG_FILE"
