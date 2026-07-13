# Recovery Procedures

## Backup design

A cron job installed by the bootstrap script runs scripts/backup.sh every night at three in the morning. It archives all four persistent volumes, Grafana, Prometheus, Loki, and Uptime Kuma, into timestamped tarballs under ~/backups and deletes anything older than seven days. All configuration is code in the GitHub repository, so config recovery is a git clone rather than a file restore.

Copy the latest backups off the server weekly so a total server loss is survivable.

```
scp ubuntu@SERVER_IP:~/backups/*.tar.gz ./offsite-backups/
```

## Scenario one, a container crashes

Every service has restart unless-stopped, so Docker restarts crashed containers automatically. If a container is unhealthy but running, restart it directly.

```
docker compose ps
docker compose restart app
docker compose logs --tail 50 app
```

## Scenario two, data volume loss or corruption

Restore all volumes from the most recent nightly backup. The script stops the stack, recreates each volume from its tarball, and starts everything again.

```
ls ~/backups
./scripts/restore.sh 20260712-030000
```

Expected recovery time is under five minutes. Prometheus and Loki lose at most the hours since the last backup, which is acceptable for observability data.

## Scenario three, total server loss

1. Create a new A1 instance in OCI and update both DuckDNS records to the new public IP.
2. Clone the repository and run scripts/bootstrap.sh, then log out and back in.
3. Copy .env values back in and reissue the certificate with the certbot command from the README.
4. Copy the offsite backup tarballs into ~/backups and run scripts/restore.sh with their timestamp.
5. Run docker compose up -d and confirm every monitor in Uptime Kuma returns green.

Expected recovery time is under one hour, dominated by instance creation and DNS propagation.

## Failure and recovery demonstration for the presentation

This sequence shows detection and recovery live in under five minutes.

1. Show the Kuma status page green and the Grafana dashboard live.
2. Run docker compose stop app on the server.
3. Reload the public site to show the proxy returning a bad gateway, then show Kuma flipping to red and the Discord notification arriving.
4. Run docker compose start app, reload the site, and show Kuma returning to green with the outage recorded in its history.
5. Optionally show the deeper path, docker compose down, docker volume rm itmo453_grafana-data, then ./scripts/restore.sh with the latest timestamp, and log back into Grafana to prove dashboards and users survived.
