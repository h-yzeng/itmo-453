# Monitoring Setup

Three signals are collected. Metrics through Prometheus, logs through Loki, and availability through Uptime Kuma. Grafana is the single pane of glass at https://DOMAIN/grafana.

## Metrics

Prometheus scrapes itself, node exporter, and cAdvisor every fifteen seconds and keeps fifteen days of data. Node exporter covers host CPU, memory, disk, filesystem, and network. cAdvisor covers per container CPU, memory, and network so a misbehaving container is identifiable in seconds.

Recommended dashboards to import in Grafana after first login.

| Dashboard | Import ID | Datasource |
| --- | --- | --- |
| Node Exporter Full | 1860 | Prometheus |
| Docker Container Monitoring | 14282 | Prometheus |

## Logs

Promtail discovers every container through the Docker socket and ships stdout and stderr to Loki with a container label. Loki keeps seven days. In Grafana Explore, select the Loki datasource and query by container name.

```
{container="proxy"}
{container="app"} |= "error"
```

The proxy also writes access and error logs to nginx/logs on the host, which is what feeds the Fail2Ban nginx jail.

## Uptime checks

Uptime Kuma runs at the status subdomain. Configure two monitors after first launch, an HTTPS monitor against the public site URL and an HTTPS monitor against the Grafana URL, each on a sixty second interval. Enable the public status page from the Kuma settings so availability history is visible without login.

## Alerting

Alerting uses a Discord webhook so no SMTP setup is needed.

1. In Discord, create a channel, open its settings, create a webhook, and copy the URL.
2. In Grafana go to Alerting, then Contact points, create one of type Discord, and paste the URL.
3. Create an alert rule on the Prometheus datasource with this expression, evaluated every minute, firing after five minutes.

```
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
```

4. Create a second rule for memory pressure.

```
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
```

5. In Uptime Kuma, add the same Discord webhook under Notifications and attach it to both monitors, so downtime alerts arrive even if Grafana itself is the thing that is down.
