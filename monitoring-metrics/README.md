# Monitoring and Metrics Project

A self contained observability stack built with Prometheus, Node Exporter, and Grafana. Clone the repository and bring it up with one command to get host metrics, dashboards, and alerts.

## Architecture

Three containers run together. Prometheus scrapes and stores the metrics. Node Exporter exposes host level metrics such as processor, memory, disk, and network. Grafana reads from Prometheus to render dashboards and to evaluate alerts. Data flows from Node Exporter into Prometheus and then into Grafana for display and alerting.

## Running the Stack

Make sure Docker and the Docker Compose plugin are installed. Then run the command below from the repository root.

```bash
docker compose up -d
```

After the containers start, open the services in a browser. Grafana is available on port 3000 where the default user name is admin and the default password is admin. Prometheus is available on port 9090. Node Exporter is available on port 9100.

The datasource, the dashboard, and the alert rules all load automatically through provisioning, so nothing needs to be configured by hand after startup.

## Dashboards

The Node Overview dashboard presents the operational story of the host in one view. The top row shows current processor load, memory in use, root filesystem in use, and the status of the Node Exporter target. The lower rows trend processor usage, memory usage, disk usage, and network throughput over time. Together these panels answer whether the host is healthy right now and how it has behaved recently.

## Metrics

All metrics come from Node Exporter and Prometheus and they cover the most meaningful infrastructure signals. Processor utilization is derived from the idle counter so that the panel shows how busy the machine is. Memory utilization is derived from available memory against total memory. Disk utilization is derived from available bytes against total bytes on the root filesystem. Network throughput is derived from the receive and transmit byte counters. Target availability comes from the Prometheus up metric.

## Alerting

Three alert rules are provisioned into Grafana and evaluate every minute. The first rule fires when processor utilization stays above 80 percent. The second rule fires when free disk space on the root filesystem falls below 15 percent. The third rule fires when the Node Exporter target stops responding. Each rule moves from normal to firing and back to normal inside the Grafana alerting section, which is where the states can be shown.

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

## Operational Analysis

The dashboard is designed around the four signals that matter most for a single host, which are processor, memory, disk, and availability. Reading them together gives a fast verdict on host health. A high processor trend with stable memory usually points to a busy workload rather than a fault. Rising memory usage that does not fall back can indicate a leak and deserves attention before it forces the system to swap. Falling free disk space is the slowest moving but most damaging signal because a full disk stops writes and can crash services. The availability panel and its matching alert catch the case where the host or the exporter itself disappears.

The alert thresholds are chosen to warn before failure rather than after. A processor threshold of 80 percent leaves headroom to react. A free disk threshold of 15 percent gives time to clean up before the disk fills. The availability alert needs no threshold to tune because the target is either present or absent.

## Repository Layout

```bash
monitoring/
  docker-compose.yml
  prometheus/
    prometheus.yml
  grafana/
    provisioning/
      datasources/
        prometheus.yml
      dashboards/
        dashboards.yml
      alerting/
        rules.yml
  dashboards/
    node-overview.json
  README.md
```
