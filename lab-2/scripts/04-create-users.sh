#!/bin/bash
# 04-create-users.sh
# Creates a set of standard users with home directories and SSH key folders.
# Safe to run multiple times since each user is checked before creation.

set -euo pipefail

LOG_FILE="/var/log/lab2-automation/create-users.log"
mkdir -p "$(dirname "$LOG_FILE")"

USERS=(
  "deployer"
  "monitor"
)

for user in "${USERS[@]}"; do
  if id "$user" >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') User $user already exists, skipping" | tee -a "$LOG_FILE"
  else
    useradd -m -s /bin/bash "$user"
    mkdir -p "/home/$user/.ssh"
    chmod 700 "/home/$user/.ssh"
    chown "$user:$user" "/home/$user/.ssh"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Created user $user" | tee -a "$LOG_FILE"
  fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') User creation complete" | tee -a "$LOG_FILE"
