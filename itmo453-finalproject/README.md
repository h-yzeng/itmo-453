# ITMO-453 Final Project, Production Deployment

For my final project, I deployed a publicly accessible, TLS secured, monitored, and automatically deployed observability platform on an Oracle Cloud Always Free instance. I chose to make the monitoring stack itself the deployed service rather than bolting on a separate front end. Grafana sits behind a login at my main domain, and Uptime Kuma's public status page is visible with no login at my status subdomain.

Dashboards: [https://henryzg.duckdns.org](https://henryzg.duckdns.org)
Status page: [https://henryzg-status.duckdns.org/status/default](https://henryzg-status.duckdns.org/status/default)

## Repository layout

```bash
itmo453-finalproject/
  docker-compose.yml            full stack definition
  .env.example                  environment template, copy to .env
  .github/workflows/deploy.yml  automated deployment on push to main
  nginx/templates/               reverse proxy config with TLS termination
  monitoring/                    Prometheus, Loki, Promtail, Grafana provisioning
  fail2ban/                      intrusion prevention jails
  scripts/                       bootstrap.sh, backup.sh, restore.sh
  docs/                          documentation portfolio
```

## 1. Creating the server

I created a Compute instance in the OCI console using the Canonical Ubuntu 24.04 image (the standard image, not Minimal). I originally tried the Ampere `VM.Standard.A1.Flex` shape, but Oracle's free ARM tier reported "out of host capacity" across all three availability domains in the Chicago region. I ended up switching to `VM.Standard.A2.Flex`, a second, separate Always Free Ampere shape that draws from an independent capacity pool, and that succeeded on the first try. Either shape works identically for this stack; I set 2 OCPUs and 12 GB of memory.

For networking, I found that the quick-create VCN option inside the instance creation flow produced a subnet whose public IPv4 toggle refused to enable, no matter what I tried. The fix was to back out and use the dedicated **Networking → Virtual Cloud Networks → Start VCN Wizard → "Create VCN with Internet Connectivity"** instead, which correctly set up the VCN, public and private subnets, internet gateway, NAT gateway, and route tables all linked together. After that, I went back into instance creation, selected that VCN and its public subnet, and the public IPv4 toggle worked without issue.

I downloaded both the generated private and public SSH keys immediately, since Oracle does not show the private key again after that screen. I then opened the instance subnet's Security List and added two ingress rules for source 0.0.0.0/0: TCP port 80 and TCP port 443. Port 22 was already open by default. Finally, I noted the instance's public IP for the next step.

## 2. Pointing DNS at it

I signed up at duckdns.org and created two subdomains, `henryzg` and `henryzg-status`, then pointed both at my instance's public IP.

## 3. Provisioning and deploying

I connected over SSH and cloned my repo:

```bash
ssh -i /path/to/my/private-key ubuntu@PUBLIC_IP
git clone https://github.com/h-yzeng/itmo-453.git
cd itmo-453/itmo453-finalproject
./scripts/bootstrap.sh
```

The bootstrap script installs Docker, ufw, fail2ban, and certbot, hardens SSH, and sets up my nightly backup cron job. I hit two real gaps in my own script on this fresh Ubuntu 24.04 image:

- `ufw` was not preinstalled and my package list missed it, I saw `sudo: ufw: command not found`, so I ran `sudo apt-get install -y ufw` and re-ran bootstrap.sh, which safely skipped everything already completed.
- `netfilter-persistent` was also not preinstalled, so I removed that line with `sed -i '/netfilter-persistent reload/d' scripts/bootstrap.sh` and re-ran the script.

After bootstrap finished, I logged out and back in so my docker group membership would take effect:

```bash
exit
ssh -i /path/to/my/private-key ubuntu@PUBLIC_IP
cd itmo-453/itmo453-finalproject
```

I configured my environment:

```bash
cp .env.example .env
nano .env
```

I set `DOMAIN` and `STATUS_DOMAIN` to my real DuckDNS subdomains, a genuinely strong `GRAFANA_ADMIN_PASSWORD`, and later added SMTP variables so Grafana could send alert emails through my Gmail account, since this server is publicly reachable and email is the only place I can be notified of a real problem.

I got the TLS certificate before starting the stack, since certbot needs port 80 free:

```bash
sudo certbot certonly --standalone -d henryzg.duckdns.org -d henryzg-status.duckdns.org --agree-tos -m thyzeng@gmail.com --no-eff-email
```

This is where I hit my biggest issue. Certbot kept failing to validate even though my Security List, route table, and UFW rules all looked correct. After a long troubleshooting session, I found a leftover Oracle default `iptables` rule that predates UFW's own chain and silently rejects all traffic ahead of it:

```bash
sudo iptables -L INPUT -n --line-numbers -v
```

I found a `REJECT` rule with protocol `all`, source and destination `0.0.0.0/0`, sitting at a low rule number with a nonzero packet count, meaning it was actively catching real traffic. I removed it and made the fix permanent:

```bash
sudo iptables -D INPUT <rule-number>
sudo apt-get install -y iptables-persistent
```

I confirmed saving current rules when prompted so the fix would persist across reboots, then retried certbot successfully.

I brought the stack up:

```bash
docker compose up -d
docker compose ps
```

All 8 containers, proxy, grafana, prometheus, loki, promtail, node-exporter, cadvisor, uptime-kuma, came up running.

## 4. Verifying everything works

1. `https://henryzg.duckdns.org` redirects HTTP to HTTPS and shows the Grafana login screen.
2. I logged into Grafana with my `.env` credentials and confirmed both the Prometheus and Loki datasources show as connected.
3. I imported dashboard `1860` (Node Exporter Full), which worked fully out of the box against my stack.
4. I was not able to get dashboard `14282` (Docker Container Monitoring) working. My cAdvisor container cannot resolve per-container read-write layer IDs against Docker 29.6.1's containerd image store, a genuine version incompatibility rather than a misconfiguration on my part, I confirmed this by trying two different cAdvisor versions and hitting the identical failure both times. My host-level CPU, memory, disk, and network metrics from Node Exporter Full are unaffected and fully cover my monitoring requirement. I explain the full diagnostic process in `docs/monitoring-setup.md`.
5. `https://henryzg-status.duckdns.org` loads Uptime Kuma with no login required. I created two HTTPS monitors, one for my main domain and one for my status domain itself, each on a 60 second interval, and both show 100% uptime.
6. `sudo fail2ban-client status` shows both my `sshd` and `nginx-botsearch` jails active, and I can already see real attackers being banned in my logs.
7. I built four Grafana alert rules for CPU, memory, disk, and instance availability, all delivering to my email through an SMTP contact point, and I did not just trust the configuration. I deliberately generated real memory pressure on the server with `stress-ng`, watched the alert move from Normal to Pending to Firing in Grafana's own state history, and received a real email describing the exact threshold breach, confirmed in `docs/monitoring-setup.md`.
8. I also tested my backup and restore process directly rather than only writing it down, deliberately deleting my live Grafana data volume and confirming it came back fully intact after running `scripts/restore.sh`, described in `docs/recovery-procedures.md`.

## 5. Enabling automated deployment

In my GitHub repository settings, I added four Actions secrets under Settings → Secrets and variables → Actions:

| Secret   | Value                                                                   |
| -------- | ----------------------------------------------------------------------- |
| SSH_HOST | my instance's public IP                                                 |
| SSH_USER | ubuntu                                                                  |
| SSH_KEY  | the full contents of my private key file, including the BEGIN/END lines |
| DOMAIN   | henryzg.duckdns.org                                                     |

Every push I make to main now deploys automatically over SSH and finishes with an external health check against my live site. My first real deployment run through this pipeline hit one failure worth noting: my workflow file initially lived one folder too deep inside my monorepo for GitHub Actions to discover it at all, and no run appeared until I moved `.github/workflows/deploy.yml` to the repository root.

## Documentation portfolio

| Document                    | Contents                                                                    |
| --------------------------- | --------------------------------------------------------------------------- |
| docs/architecture.md        | Architecture diagram and component roles                                    |
| README.md                   | Deployment instructions, this file                                          |
| docs/security-controls.md   | Layered security design                                                     |
| docs/monitoring-setup.md    | Metrics, logs, uptime, tested alerting, and the cAdvisor limitation         |
| docs/recovery-procedures.md | Backups, three failure scenarios, a verified restore test, live demo script |
| docs/maintenance-plan.md    | Ongoing operational cadence                                                 |
