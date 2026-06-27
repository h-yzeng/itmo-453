#!/bin/bash
# 03-configure-services.sh
# Enables and starts required services after package installation.
# Configures fail2ban with a basic SSH jail. Safe to run multiple times.

set -euo pipefail

LOG_FILE="/var/log/lab2-automation/configure-services.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

# Enable and start nginx
log "Configuring nginx"
systemctl enable nginx >> "$LOG_FILE" 2>&1
systemctl start nginx >> "$LOG_FILE" 2>&1
log "nginx enabled and running"

# Configure fail2ban with a basic SSH jail
JAIL_LOCAL="/etc/fail2ban/jail.local"
if [ ! -f "$JAIL_LOCAL" ]; then
  log "Writing fail2ban jail.local"
  cat > "$JAIL_LOCAL" <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
else
  log "fail2ban jail.local already exists, skipping"
fi

log "Configuring fail2ban"
systemctl enable fail2ban >> "$LOG_FILE" 2>&1
systemctl start fail2ban >> "$LOG_FILE" 2>&1
log "fail2ban enabled and running"

log "Service configuration complete"
