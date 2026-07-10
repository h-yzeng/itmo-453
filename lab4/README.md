# Lab 4 - Production Readiness, Security Hardening, and Resilience

Eight-container stack, hardened from first boot. Nginx is the only web
entry point and terminates TLS. Fail2Ban protects the SSH service. A
backup container runs nightly volume backups with a restore path.

```
nginx (TLS, 127.0.0.1:443 and :8444)   fail2ban (shares ssh-target netns)
grafana (behind nginx, /grafana)       ssh-target (127.0.0.1:2222)
uptime-kuma (behind nginx, :8444)      backup (cron, nightly 02:00)
prometheus + node-exporter (internal-only network)
```

## Bring-up

From the project root in PowerShell:

```powershell
# 1. Generate the self-signed cert (Git Bash: sh scripts/gen-certs.sh)
docker run --rm -v "${PWD}/nginx/certs:/certs" alpine/openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes -keyout /certs/server.key -out /certs/server.crt -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# 2. Start the stack
docker compose up -d

# 3. Confirm all eight containers are Up
docker compose ps
```

Credentials live in `.env` (gitignored). Rotate them before submission
screenshots if you want your own values.

## Verify

1. https://localhost redirects to Grafana. Accept the self-signed cert
   warning, log in with the `.env` credentials.
2. https://localhost:8444 loads Uptime Kuma. Create the admin account on
   first visit, then add a monitor or two (this becomes the restore-demo
   evidence later).
3. Fail2Ban is watching the SSH log:
   ```
   docker compose exec fail2ban fail2ban-client status sshd-lab
   ```
   Should list the jail with the file `/ssh-config/logs/openssh/current`.
   If that file path does not exist yet, check the actual location with
   `docker compose exec ssh-target ls /config/logs/openssh` and tell me.
4. Prometheus is internal-only by design. Check targets from inside:
   ```
   docker compose exec prometheus wget -qO- http://localhost:9090/api/v1/targets
   ```

## Quick Fail2Ban smoke test

Fail three SSH logins with a wrong password, then check status:

```powershell
ssh -p 2222 -o StrictHostKeyChecking=no labuser@localhost   # wrong password x3
docker compose exec fail2ban fail2ban-client status sshd-lab
```

Banned IP will be the Docker gateway (how Docker Desktop NATs localhost).
Unban with:

```
docker compose exec fail2ban fail2ban-client set sshd-lab unbanip <ip>
```

## Manual backup and restore

```powershell
# Backup now (cron also runs nightly at 02:00)
docker compose exec backup sh /scripts/backup.sh

# Restore: stop apps, restore by timestamp, start apps
docker compose stop grafana prometheus uptime-kuma ssh-target
docker compose exec backup sh /scripts/restore.sh <timestamp>
docker compose start grafana prometheus uptime-kuma ssh-target
```

Archives land in `./backups` as `<volume>-<timestamp>.tar.gz`, retention
keeps the last seven per volume.
