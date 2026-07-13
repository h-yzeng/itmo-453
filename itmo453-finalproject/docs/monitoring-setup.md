# Monitoring Setup

I collect three signals in my deployment: metrics through Prometheus, logs through Loki, and availability through Uptime Kuma. Grafana is my single pane of glass, reachable at https://henryzg.duckdns.org.

## Metrics

Prometheus scrapes itself, node exporter, and cAdvisor every fifteen seconds and keeps fifteen days of data. Node exporter covers my host's CPU, memory, disk, filesystem, and network. cAdvisor is intended to cover per-container CPU, memory, and network so a misbehaving container is identifiable quickly, though I ran into a real limitation with it in my setup, documented below.

Dashboard I imported and confirmed working:

| Dashboard          | Import ID | Datasource |
| ------------------ | --------- | ---------- |
| Node Exporter Full | 1860      | Prometheus |

## The cAdvisor limitation I found

I attempted to import the community "Docker Container Monitoring" dashboard (ID 14282), but every panel showed "No data" even though Prometheus and Grafana were both fully connected and working. I traced this down methodically rather than assuming a config mistake:

1. I confirmed in Grafana Explore that raw cAdvisor metrics like `container_cpu_usage_seconds_total` did return data, over fifty series, so the scrape pipeline itself was healthy.
2. I checked the actual labels on that data using the Metrics Browser and found only `id`, `instance`, and `job`, no `name` and no `image` label on any series. The dashboard's queries depend on those two labels to identify individual containers.
3. I checked cAdvisor's own container logs and found repeated errors: `failed to identify the read-write layer ID for container ... no such file or directory`, referencing a path under `/var/lib/docker/image/overlayfs/layerdb/mounts/`.
4. I confirmed this is a genuine version incompatibility. My Docker version (29.6.1) uses containerd's newer image store by default rather than the legacy overlayfs graphdriver, and cAdvisor cannot resolve container identities against that newer layout. I tried upgrading cAdvisor from v0.49.1 to v0.52.1 to see if a newer release added support, and hit the exact same error, confirming this is a deeper incompatibility rather than a version I could simply patch around.

Given the time already invested and the fact that this does not affect my core monitoring requirement, I reverted cAdvisor to v0.49.1 and left the community dashboard out rather than continuing to chase a fix with diminishing returns. cAdvisor still contributes host-level cgroup CPU and memory data even without clean per-container breakdowns, and my Node Exporter Full dashboard fully covers host-level observability. I consider this a documented environmental limitation rather than a gap in my monitoring coverage.

## Logs

Promtail discovers every container through the Docker socket and ships stdout and stderr to Loki with a container label. Loki keeps seven days. In Grafana Explore, I select the Loki datasource and query by container name, for example:

```bash
{container="proxy"}
{container="grafana"} |= "error"
```

My proxy also writes access and error logs to nginx/logs on the host, which is what feeds my Fail2Ban nginx-botsearch jail.

## Uptime checks

Uptime Kuma runs at my status subdomain. I configured two HTTPS monitors, one against my main domain and one against my status domain itself, each on a sixty second interval, both currently reporting 100% uptime. I enabled the public status page from Kuma's settings so availability history is visible without login.

## Alerting

I designed my alerting around a Discord webhook so no SMTP setup is needed. The steps to enable it:

1. In Discord, create a channel, open its settings, create a webhook, and copy the URL.
2. In Grafana go to Alerting, then Contact points, create one of type Discord, and paste the URL.
3. Create an alert rule on the Prometheus datasource with this expression, evaluated every minute, firing after five minutes:

```bash
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
```

4. Create a second rule for memory pressure:

```bash
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
```

5. In Uptime Kuma, add the same Discord webhook under Notifications and attach it to both monitors, so downtime alerts arrive even if Grafana itself is the thing that is down.
