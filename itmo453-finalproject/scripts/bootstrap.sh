#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y fail2ban unattended-upgrades curl git zip

# Oracle images ship iptables REJECT rules that block everything except SSH
if [ -f /etc/iptables/rules.v4 ]; then
  sudo sed -i '/REJECT/d' /etc/iptables/rules.v4
  sudo netfilter-persistent reload
fi

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo usermod -aG docker "$USER"

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
MaxAuthTries 3
X11Forwarding no
EOF
sudo systemctl restart ssh

mkdir -p "$REPO_DIR/nginx/logs" "$HOME/backups"
touch "$REPO_DIR/nginx/logs/access.log"

sudo cp "$REPO_DIR/fail2ban/jail.local" /etc/fail2ban/jail.local
sudo sed -i "s|/home/ubuntu/itmo453-final|$REPO_DIR|" /etc/fail2ban/jail.local
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

sudo snap install core 2>/dev/null || true
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Renewal briefly stops the proxy so certbot can bind port 80
sudo mkdir -p /etc/letsencrypt/renewal-hooks/pre /etc/letsencrypt/renewal-hooks/post
sudo tee /etc/letsencrypt/renewal-hooks/pre/stop-proxy.sh >/dev/null <<EOF
#!/usr/bin/env bash
cd $REPO_DIR && docker compose stop proxy
EOF
sudo tee /etc/letsencrypt/renewal-hooks/post/start-proxy.sh >/dev/null <<EOF
#!/usr/bin/env bash
cd $REPO_DIR && docker compose start proxy
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/pre/stop-proxy.sh /etc/letsencrypt/renewal-hooks/post/start-proxy.sh

( crontab -l 2>/dev/null | grep -v backup.sh ; echo "0 3 * * * $REPO_DIR/scripts/backup.sh >> $HOME/backups/backup.log 2>&1" ) | crontab -

echo "Bootstrap complete. Log out and back in so the docker group membership applies."
