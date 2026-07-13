# Operational Maintenance Plan

## Cadence

| Frequency | Task | Method |
| --- | --- | --- |
| Continuous | OS security patches | unattended-upgrades, automatic |
| Continuous | Crash recovery | Docker restart policies, automatic |
| Nightly | Volume backups with seven day rotation | cron and scripts/backup.sh, automatic |
| Every sixty days | TLS certificate renewal | certbot systemd timer with proxy stop and start hooks, automatic |
| Weekly | Review Grafana dashboards and Kuma history for drift | manual, five minutes |
| Weekly | Copy latest backups off the server | manual scp, five minutes |
| Monthly | Update container images | manual, commands below |
| Monthly | Review Fail2Ban activity | sudo fail2ban-client status sshd |
| Quarterly | Rotate the Grafana admin password and SSH deploy key | manual |

## Monthly image updates

```
cd ~/itmo453-final
docker compose pull
docker compose up -d
docker image prune -f
```

Pin new version tags in docker-compose.yml through a commit rather than using latest, so every running version is traceable to git history and a bad update can be rolled back with git revert and a push, which redeploys automatically.

## Capacity checks

The Node Exporter Full dashboard shows disk and memory headroom. Prometheus retention is fifteen days and Loki retention is seven days, which keeps observability data well under the boot volume size. If disk usage passes seventy percent, lower retention or expand the block volume in OCI.

## Deployment procedure

All changes flow through git. Push to main and the GitHub Actions workflow connects over SSH, pulls, rebuilds, and restarts only what changed, then runs an external health check against the live domain. Nothing is edited by hand on the server, so the repository is always the source of truth.
