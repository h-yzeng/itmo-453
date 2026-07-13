# Operational Maintenance Plan

## Cadence

| Frequency        | Task                                                 | Method                                                           |
| ---------------- | ---------------------------------------------------- | ---------------------------------------------------------------- |
| Continuous       | OS security patches                                  | unattended-upgrades, automatic                                   |
| Continuous       | Crash recovery                                       | Docker restart policies, automatic                               |
| Nightly          | Volume backups with seven day rotation               | cron and scripts/backup.sh, automatic                            |
| Every sixty days | TLS certificate renewal                              | certbot systemd timer with proxy stop and start hooks, automatic |
| Weekly           | Review Grafana dashboards and Kuma history for drift | manual, five minutes                                             |
| Weekly           | Copy latest backups off the server                   | manual scp, five minutes                                         |
| Monthly          | Update container images                              | manual, commands below                                           |
| Monthly          | Review Fail2Ban activity                             | sudo fail2ban-client status sshd                                 |
| Quarterly        | Rotate my Grafana admin password and SSH deploy key  | manual                                                           |

## Monthly image updates

```bash
cd ~/itmo-453/itmo453-finalproject
docker compose pull
docker compose up -d
docker image prune -f
```

I pin version tags in my docker-compose.yml through a commit rather than using latest, so every running version is traceable to my git history and a bad update can be rolled back with git revert and a push, which redeploys automatically through my GitHub Actions workflow.

## Capacity checks

My Node Exporter Full dashboard shows disk and memory headroom. Prometheus retention is fifteen days and Loki retention is seven days, which keeps observability data well under my boot volume size. If disk usage passes seventy percent, I would lower retention or expand the block volume in OCI.

## Configuration changes that require a forced recreate

Compose only automatically recreates a container when its image or build context changes. Files I mount as volumes, such as `nginx/templates/default.conf.template`, are not part of the image, so editing one and running a plain `docker compose up -d` does nothing, the container keeps running with whatever config it loaded at its last startup. I hit this directly after updating my nginx template to route my new landing page and Grafana's subpath: `app` and `grafana` picked up their changes because their images rebuilt, but `proxy` kept running for another sixteen hours on its old config until I forced it:

```bash
docker compose up -d --force-recreate proxy
```

Any future change to a file under `nginx/templates/`, `monitoring/`, or `fail2ban/` needs the same treatment for the affected service, since none of those are baked into an image either.

## Deployment procedure

All my changes flow through git. I push to main and my GitHub Actions workflow connects over SSH, pulls, rebuilds, and restarts only what changed, then runs an external health check against my live domain. I do not edit files by hand directly on the server, since doing so once during troubleshooting caused my server's git history to diverge from GitHub's and blocked a later automated pull, a mistake I corrected with `git fetch` and `git reset --hard origin/main`. My repository is the single source of truth going forward.
