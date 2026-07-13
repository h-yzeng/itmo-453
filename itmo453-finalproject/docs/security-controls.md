# Security Controls

Defense in depth is the design principle. Each layer assumes the layer above it can fail.

## Control summary

| Layer | Control | Detail |
| --- | --- | --- |
| Cloud | OCI Security List | Ingress limited to 22, 80, and 443 from 0.0.0.0/0 |
| Host | UFW | Default deny incoming, allow OpenSSH, 80, and 443 |
| Host | SSH hardening | Key only auth, root login disabled, MaxAuthTries 3, X11 forwarding off |
| Host | Fail2Ban | sshd jail on the systemd journal plus nginx-botsearch jail on proxy access logs, one hour bans enforced through UFW |
| Host | Unattended upgrades | Security patches apply automatically |
| Transport | TLS | Let's Encrypt certificates, TLS 1.2 and 1.3 only, HSTS enabled |
| Application | Security headers | HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy |
| Application | Grafana | Local admin account from environment variables, signups disabled |
| Container | Network segmentation | Monitoring backends on an internal network with no internet route |
| Container | Least exposure | Only the proxy publishes ports, all other services are unreachable externally |
| Secrets | .env file | Credentials never committed, .gitignore enforces this |

## Known consideration with Docker and UFW

Docker writes its own iptables rules for published ports, which means a published port bypasses UFW. This stack mitigates the issue two ways. First, only the proxy publishes ports, and 80 plus 443 are intentionally public anyway. Second, the OCI Security List sits in front of the host entirely outside its control, so even a misconfigured container publish would still be blocked at the cloud layer unless the port was also opened there.

## Oracle default rules

Oracle Ubuntu images ship persistent iptables REJECT rules that silently block everything except SSH even after the Security List is opened. The bootstrap script removes those rules and reloads netfilter so UFW becomes the single host firewall of record. This is documented because it is the single most common reason a fresh OCI deployment appears broken.

## Access model

There is exactly one interactive entry point, SSH as the ubuntu user with a key. Prometheus, cAdvisor, node exporter, and Loki have no external exposure and are reviewed through Grafana or an SSH tunnel. Grafana requires login before any dashboard is visible.
