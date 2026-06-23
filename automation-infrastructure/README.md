# Automation and Infrastructure Project

This framework is a reusable Ansible-based deployment framework that deploys an operational service into Docker with a security baseline, log rotation, and a monitoring dashboard applied automatically.

See `docs/architecture.md` for the design and `docs/deployment_guide.md`
for setup and run instructions.

## Quick Start

```bash
ansible-galaxy collection install community.docker
ansible-playbook -i inventory.ini site.yml
```

Then visit:

- Service: <http://localhost:8080>
- Monitoring dashboard: <http://localhost:8081>
