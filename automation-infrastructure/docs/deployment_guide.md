# Deployment Guide

## Prerequisites

- Docker installed and running on the host
- Python 3 installed
- Ansible installed (`pip install ansible`)
- community.docker collection installed:

  ```bash
  ansible-galaxy collection install community.docker
  ```

## Repository Layout

```bash
infra-framework/
├── site.yml
├── inventory.ini             # points ansible at localhost
├── group_vars/all.yml        # all configurable variables
├── roles/
│   ├── security_baseline/    # confirms docker is ready, defines hardening
│   ├── logging/               # prepares log directory and rotation
│   ├── monitoring/            # deploys cAdvisor
│   └── service_deploy/        # deploys the hardened service container
└── docs/                      # this guide and the architecture overview
```

## Running the Deployment

From the repository root:

```bash
ansible-playbook -i inventory.ini site.yml
```

This will, in order:

1. Confirm Docker is installed and reachable
2. Create the log directory on the host
3. Start the cAdvisor monitoring container
4. Start the service container with security and logging settings applied

## Verifying the Deployment

Check running containers:

```bash
docker ps
```

Check the service is reachable:

```bash
curl http://localhost:8080
```

Check the monitoring dashboard:

```bash
http://localhost:8081
```

Check service logs:

```bash
docker logs webapp
```

## Demonstrating Idempotency

Run the playbook a second time:

```bash
ansible-playbook -i inventory.ini site.yml
```

No changes should be reported for tasks where nothing changed, since
Ansible checks current state before acting.

## Changing the Deployed Service

Edit group_vars/all.yml and change service_name, service_image, or
service_port, then re-run the playbook. No role logic needs to change.

## Tearing Down

```bash
docker rm -f webapp cadvisor
```
