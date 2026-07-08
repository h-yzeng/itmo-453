# Monitoring, Logging, and Operational Visibility

A full observability stack built with Prometheus, Node Exporter, cAdvisor, Grafana, Loki, Promtail, and Uptime Kuma. This extends an earlier Prometheus and Grafana project into a complete monitoring, logging, and alerting platform. Clone the repository and bring it up with one command to get host metrics, container metrics, logs, dashboards, and alerts.

## Architecture

Eight containers run together, organized into three layers.

The data source layer includes Node Exporter for host metrics, cAdvisor for container metrics, an SSH target container that generates authentication traffic, and the login system built into Grafana, which produces a log line whenever a login attempt fails. Uptime Kuma sits outside this layer and checks Prometheus, Grafana, and cAdvisor directly over HTTP.

The collection layer includes Prometheus, which scrapes Node Exporter and cAdvisor every 15 seconds, and Promtail, which tails the standard output of every container and forwards each log line to Loki.

Grafana forms the visualization and alerting layer. It queries both Prometheus and Loki, renders three dashboards, and evaluates four alert rules every minute.

## Running the Stack

Make sure Docker and the Docker Compose plugin are installed. Then run the command below from the repository root.

```bash
docker compose up -d
```

After the containers start, open the services in a browser.

| Service       | Port | Notes                                                    |
| ------------- | ---- | -------------------------------------------------------- |
| Grafana       | 3000 | Default user name admin, default password admin          |
| Prometheus    | 9090 |                                                          |
| cAdvisor      | 8081 | Mapped to 8081 on the host to avoid local port conflicts |
| Uptime Kuma   | 3001 | Requires creating an admin account on first visit        |
| Node Exporter | 9100 |                                                          |
| Loki          | 3100 | Queried through Grafana, not usually opened directly     |
| SSH target    | 2222 | User name labuser, password labuser                      |

Every datasource, dashboard, and alert rule loads automatically through provisioning, so nothing needs to be configured by hand after startup.

Grafana alert rule and datasource provisioning is read once at container start and does not hot reload. After changing any file under `grafana/provisioning/alerting`, run `docker compose restart grafana` to apply it. Dashboard JSON files under `dashboards/` do hot reload and require no restart.

Brute force login protection is disabled in this stack through the `GF_SECURITY_DISABLE_BRUTE_FORCE_LOGIN_PROTECTION` environment variable, since the Failed Login Attempts alert is demonstrated by intentionally failing logins and a lockout would interrupt that test.

## Dashboards

Three dashboards are provisioned.

The Infrastructure Overview dashboard reports processor load, memory usage, root filesystem usage, network throughput, and Node Exporter target status in its top rows, and adds a row of container level panels showing the number of containers running, per container processor usage, and per container memory usage.

The Security Events dashboard reports the number of failed Grafana login attempts in the last five minutes, a chart of failed attempts over time, a reference panel showing the alert threshold, and a live log panel showing each individual failed attempt as it is recorded.

The Availability dashboard reports the current up or down state of every Prometheus scrape target, a combined chart of target availability over time, and an overall uptime percentage for the selected window. Uptime Kuma is intentionally kept separate from this dashboard and should be reviewed at its own interface for HTTP level uptime history.

## Metrics and Logs Collected

Processor utilization, memory usage, disk usage, and network throughput come from Node Exporter. Container status, per container processor usage, and per container memory usage come from cAdvisor, scoped to the containers in this stack by name. Service uptime is measured two ways, through the Prometheus up metric and independently through Uptime Kuma. Login attempts are measured by counting log lines from the authentication system built into Grafana whenever a submitted password does not match the stored credential.

## Alerting

Four alert rules are provisioned into Grafana and evaluate every minute.

The High CPU Usage rule fires when processor utilization stays above 80 percent for at least one minute. The Low Disk Space rule fires when free space on the monitored filesystem falls below 15 percent. The Node Exporter Down rule fires immediately when the node scrape target stops responding. The Failed Login Attempts rule fires when more than 5 failed Grafana logins are recorded within a five minute window.

The Failed Login Attempts query excludes any log line containing `lokiPath=`, since Grafana logs its own outgoing Loki queries to the same container output that Promtail collects, and the query text otherwise matches its own log line and inflates the count.

## Demonstrating Alerts

The processor alert is the easiest to trigger. Generate load on the host with the command below and watch the rule enter the firing state within about two minutes.

```bash
yes > /dev/null &
yes > /dev/null &
```

Stop the load afterward.

```bash
kill %1 %2
```

To demonstrate the availability alert, stop the Node Exporter container and watch the target alert fire.

```bash
docker compose stop node-exporter
```

Start it again to clear the alert.

```bash
docker compose start node-exporter
```

To demonstrate the Failed Login Attempts alert, open Grafana at `http://localhost:3000`, log out, and fail a login more than 5 times with an incorrect password. Watch the Security Events dashboard and the alert rule move to the firing state within about one minute, then return to normal after a correct login or after five minutes of no further failures.

## Operational Analysis

Processor, memory, disk, and availability remain the four signals that matter most for a single host, and container status and login attempts extend that same reasoning to the container layer and the security layer. A high processor trend with stable memory usually points to a busy workload rather than a fault. Rising memory that does not fall back can indicate a leak. Falling free disk space is the slowest moving but most damaging signal because a full disk stops writes and can crash services. Failed login attempts are the equivalent slow signal for account security, since a handful of failures may be a typo but a sustained run of them points to an automated attempt against the login form.

Alert thresholds are chosen to warn before failure rather than after. A processor threshold of 80 percent and a disk threshold of 15 percent both leave room to react. The availability alert needs no threshold to tune because a target is either present or absent. The failed login threshold of five attempts in five minutes is loose enough to tolerate a genuine typo but tight enough to catch a short automated burst.

A full operational analysis report covering monitoring limitations, false positives and false negatives, security visibility, and long term maintenance strategy is included separately in the project documentation.

## Repository Layout

```bash
monitoring-metrics/
  docker-compose.yml
  prometheus/
    prometheus.yml
  loki/
    loki-config.yml
  promtail/
    promtail-config.yml
  grafana/
    provisioning/
      datasources/
        prometheus.yml
        loki.yml
      dashboards/
        dashboards.yml
      alerting/
        rules.yml
  dashboards/
    node-overview.json
    security-events.json
    availability.json
  README.md
```
