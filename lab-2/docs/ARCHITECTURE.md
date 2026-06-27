# Architecture Overview

## Purpose

This repository automates the provisioning and hardening of a Linux web server using Bash scripts for early stage tasks and Ansible for full configuration management. The goal is to make the environment reproducible so it can be rebuilt from scratch with the same result every time.

## Components

### Bash scripts

The scripts directory contains seven standalone scripts that handle the foundational system tasks before Ansible takes over.

1. 01-update-system.sh updates and upgrades system packages.
2. 02-install-packages.sh installs the baseline package set including nginx, ufw, fail2ban, docker, and ansible.
3. 03-configure-services.sh enables and starts nginx and fail2ban, and writes a fail2ban SSH jail configuration.
4. 04-create-users.sh creates the deployer and monitor user accounts with home directories and ssh folders.
5. 05-configure-firewall.sh sets a deny by default UFW policy and opens ports 22, 80, and 443.
6. 06-generate-logs.sh collects disk, memory, service, and auth log data into a timestamped maintenance log and trims old logs.
7. 07-backup-dirs.sh creates the backup directory tree under /backups with correct permissions.

Each script checks current state before making changes, so running them again does not duplicate users, directories, or firewall rules.

### Ansible

The ansible directory contains the inventory, configuration, playbooks, and roles used to manage the server going forward.

Inventory and configuration

inventory.ini defines the webservers group and connection variables. ansible.cfg sets sane defaults including the roles path and privilege escalation behavior.

Playbooks

* hardening.yml applies the users, firewall, ssh_hardening, and backup roles.
* webserver.yml applies the webserver role to install and configure nginx.
* docker-deploy.yml applies the docker_app role to deploy a containerized service.
* site.yml imports all three playbooks in order so a single command provisions a complete host.

Roles

* users creates standard accounts and authorized keys.
* firewall configures UFW rules through the ufw Ansible module.
* ssh_hardening deploys a hardened sshd_config that disables root login and password authentication.
* backup creates the backup directory tree and installs a weekly cron job for scheduled updates.
* webserver installs nginx and deploys a templated index page that reports the hostname and deployment time.
* docker_app installs Docker and docker-compose-v2, and deploys a containerized service through a templated docker-compose file using `docker compose up -d`.

## Immutable infrastructure approach

Configuration is never edited by hand on the live host. Every change is expressed as a role or task in this repository, applied through Ansible, and version controlled in git. To rebuild the environment, a fresh host is added to the inventory and site.yml is run against it. Because every task is idempotent, running the same playbook again produces no additional changes on a host that is already in the desired state, which is the core test for configuration drift.

## Data flow

1. A new virtual machine is provisioned with SSH access. Ansible can be run from a separate control node or directly on the target host using ansible_connection=local.
2. The Bash scripts are run once on the target host to install the baseline package set including Ansible, and to configure services, users, and the firewall before Ansible takes over.
3. From that point forward, all configuration is managed through site.yml and the four playbooks it imports.
4. Scheduled maintenance, including the weekly update cron job, keeps the host current without manual intervention.
