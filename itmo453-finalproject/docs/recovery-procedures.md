# Recovery Procedures

## Backup design

A cron job installed by my bootstrap script runs scripts/backup.sh every night at three in the morning. It archives all four of my persistent volumes, Grafana, Prometheus, Loki, and Uptime Kuma, into timestamped tarballs under ~/backups and deletes anything older than seven days. All of my configuration is code in my GitHub repository, so recovering configuration is a git clone rather than a file restore.

I copy my latest backups off the server weekly so a total server loss is survivable:

```bash
scp ubuntu@147.224.167.107:~/backups/*.tar.gz ./offsite-backups/
```

## Scenario one, a container crashes

Every service I run has `restart: unless-stopped`, so Docker restarts crashed containers automatically. If a container is unhealthy but running, I restart it directly:

```bash
docker compose ps
docker compose restart grafana
docker compose logs --tail 50 grafana
```

## Scenario two, data volume loss or corruption

I restore all volumes from the most recent nightly backup. My script stops the stack, recreates each volume from its tarball, and starts everything again:

```bash
ls ~/backups
./scripts/restore.sh 20260712-030000
```

My expected recovery time is under five minutes. Prometheus and Loki lose at most the hours since the last backup, which I consider acceptable for observability data specifically.

**This procedure is not just written, I actually tested it.** I ran `scripts/backup.sh` manually to create a fresh tarball, then deliberately destroyed my live Grafana volume with `docker compose stop grafana`, `docker compose rm -f grafana`, and `docker volume rm itmo453_grafana-data`, confirming with `docker volume ls` that the volume was genuinely gone before attempting any recovery. I then ran `./scripts/restore.sh` with the backup's timestamp, which brought the full stack down and back up, and all eight containers returned to a running state within seconds. Logging into Grafana afterward confirmed every dashboard and datasource I had configured was still present, meaning the restore recovered real state rather than just starting a fresh, empty instance. The one cosmetic issue I hit was a warning that the recreated volume "already exists but was not created by Docker Compose," which did not affect the outcome and is simply a side effect of the restore script creating the volume manually before Compose starts.

## Scenario three, total server loss

1. Create a new instance in OCI (A1.Flex or A2.Flex, whichever has capacity) and update both my DuckDNS records to the new public IP.
2. Clone my repository and run scripts/bootstrap.sh, then log out and back in.
3. Copy my .env values back in and reissue the certificate with the certbot command from my README, checking for the Oracle default iptables REJECT rule described in docs/security-controls.md if certbot fails to validate.
4. Copy my offsite backup tarballs into ~/backups and run scripts/restore.sh with their timestamp.
5. Run docker compose up -d and confirm every monitor in Uptime Kuma returns green.

My expected recovery time here is under one hour, dominated by instance creation and DNS propagation, plus however long it takes to rediscover the iptables issue if I hit it again on a fresh instance.

## Failure and recovery demonstration for my presentation

This sequence shows detection and recovery live in under five minutes.

1. Show the Kuma status page green and the Grafana dashboard live.
2. Run `docker compose stop grafana` on the server.
3. Reload the main site to show the proxy returning a bad gateway, then show Kuma flipping to red.
4. Run `docker compose start grafana`, reload the site, and show Kuma returning to green with the outage recorded in its history.
5. Optionally show the deeper recovery path exactly as I tested it: delete the live Grafana volume entirely, run `./scripts/restore.sh` with the latest backup timestamp, and log back into Grafana to prove my dashboards and datasources survived, the same test described in Scenario two above.
