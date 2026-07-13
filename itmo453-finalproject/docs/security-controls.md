# Security Controls

I designed my deployment around defense in depth, each layer assumes the layer above it can fail.

## Control summary

| Layer       | Control              | Detail                                                                                                                 |
| ----------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Cloud       | OCI Security List    | Ingress limited to 22, 80, and 443 from 0.0.0.0/0                                                                      |
| Host        | UFW                  | Default deny incoming, allow OpenSSH, 80, and 443                                                                      |
| Host        | SSH hardening        | Key only auth, root login disabled, MaxAuthTries 3, X11 forwarding off                                                 |
| Host        | Fail2Ban             | sshd jail on the systemd journal plus nginx-botsearch jail on my proxy access logs, one hour bans enforced through UFW |
| Host        | Unattended upgrades  | Security patches apply automatically                                                                                   |
| Transport   | TLS                  | Let's Encrypt certificates, TLS 1.2 and 1.3 only, HSTS enabled                                                         |
| Application | Security headers     | HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy                                                         |
| Application | Grafana              | Local admin account from environment variables, signups disabled                                                       |
| Container   | Network segmentation | Monitoring backends on an internal network with no internet route                                                      |
| Container   | Least exposure       | Only my proxy publishes ports, every other service is unreachable externally                                           |
| Secrets     | .env file            | Credentials never committed, .gitignore enforces this                                                                  |

## Known consideration with Docker and UFW

Docker writes its own iptables rules for published ports, which means a published port can bypass UFW's own chain. I mitigate this two ways in my setup. First, only my proxy publishes ports, and 80 and 443 are intentionally public anyway. Second, my OCI Security List sits in front of the host entirely outside Docker's control, so even a misconfigured container publish would still be blocked at the cloud layer unless I also opened that port there.

## The Oracle default rule I found and removed

During my deployment, I ran into a real security gap that is worth documenting in detail because it cost me significant troubleshooting time and is a genuinely useful thing to know about Oracle Cloud. My OCI Security List, route table, and UFW rules all looked completely correct, yet certbot could not validate my domain and external port checks against port 80 all timed out.

I eventually found the actual cause by inspecting the raw kernel firewall table directly rather than trusting UFW's own status output:

```bash
sudo iptables -L INPUT -n --line-numbers -v
```

This revealed a leftover Oracle default rule sitting at a low position in the INPUT chain, ahead of UFW's own management chains: a blanket `REJECT` rule matching all protocols, all sources, all destinations. It had already caught over a hundred real packets by the time I found it. UFW's own `ufw status` command never revealed this, because UFW only reports on its own managed chains, not the full INPUT chain, so a rule sitting ahead of UFW's logic is invisible to UFW's own tooling even though it is actively blocking traffic.

I removed it and made the fix permanent:

```bash
sudo iptables -D INPUT <rule-number>
sudo apt-get install -y iptables-persistent
```

I confirmed saving my current rules when prompted, which persists the corrected rule set across reboots. This is the single most common reason a fresh Oracle Cloud deployment can appear completely broken despite every visible configuration being correct, and I recommend anyone deploying on OCI check for this rule directly with `iptables -L INPUT -n -v` rather than assuming `ufw status` tells the whole story.

## Access model

I have exactly one interactive entry point into my server, SSH as the ubuntu user with a key, password authentication disabled. Prometheus, cAdvisor, node exporter, and Loki have no external exposure and I review them through Grafana or an SSH tunnel. Grafana requires login before any dashboard is visible.
