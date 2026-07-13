# Monitoring Setup

I collect three signals in my deployment: metrics through Prometheus, logs through Loki, and availability through Uptime Kuma. Grafana is my single pane of glass, reachable at [https://henryzg.duckdns.org](https://henryzg.duckdns.org).

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

I built alerting through Grafana's own alert rules rather than Uptime Kuma's notifications, using email as the delivery channel instead of a chat webhook, since email reaches me reliably regardless of which device I am using.

**Contact point.** I generated a Gmail app password for `thyzeng@gmail.com`, since Gmail blocks plain password SMTP logins, and added the SMTP host, user, app password, and from address as environment variables that Grafana reads on startup. In Grafana under Alerting, then Contact points, I created a contact point named `email-alerts` using the Email integration, pointed at my Outlook address, and confirmed it with Grafana's built in test button before relying on it.

**Alert rules.** I created four rules, all in a folder named `Infrastructure Alerts`, each built as a three part expression chain, a Prometheus query (A), a Reduce expression that collapses the time range to a single value using Last (B), and a Threshold expression that evaluates the actual condition (C), with C marked as the alert condition in every rule.

1. High CPU Usage: `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`, threshold above 85, evaluated every minute with a five minute pending period.
2. High Memory Usage: `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100`, threshold above 90, evaluated every minute with a five minute pending period.
3. Low Disk Space: `100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)`, threshold above 80, evaluated every five minutes with a ten minute pending period.
4. Instance Down: `up{job="node"}`, threshold below 1, evaluated every minute with a two minute pending period, since this is the rule that fires if Prometheus loses contact with node exporter entirely.

**Verifying the alerts actually fire.** Writing an alert rule and trusting it work is not the same as confirming it does, so I tested this deliberately rather than assuming the configuration was correct. I installed `stress-ng` directly on the host and ran `stress-ng --vm 1 --vm-bytes 10G --vm-keep --timeout 120s` after temporarily shortening the High Memory Usage rule's pending period to make the test faster. Grafana's own alert state history showed the rule transition from Normal to Pending to Firing as memory usage climbed to roughly 95 percent, and a real email arrived in my Outlook inbox describing the exact threshold breach, with the query values included in the message body. I then restored the pending period back to five minutes so the rule behaves correctly under real production conditions rather than firing on brief, ordinary usage spikes.

An earlier attempt at this same test produced a `DatasourceNoData` state instead of a real evaluation, which I initially mistook for a broken rule. Checking the alert rule's state history showed this had happened during a Grafana container restart performed minutes earlier to apply new SMTP environment variables, a brief window where Grafana had no live connection to Prometheus at all. Both affected rules returned to a normal, correctly evaluating state on their own once Grafana finished restarting, which I confirmed before running the real test described above.
