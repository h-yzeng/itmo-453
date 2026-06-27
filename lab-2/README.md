# Lab 2: Automation, Scripting, and Immutable Infrastructure

This repository contains the Bash scripts and Ansible playbooks used to provision, harden, and deploy a web server in a repeatable way.

## Repository structure

```bash
lab2-automation/
  scripts/                  Bash automation scripts
  ansible/
    ansible.cfg
    inventory.ini
    playbooks/              site.yml, webserver.yml, hardening.yml, docker-deploy.yml
    roles/                  users, firewall, ssh_hardening, backup, webserver, docker_app
  docs/
    ARCHITECTURE.md
    REFLECTION.md
```

## Prerequisites

- A target host or VM running Ubuntu, reachable over SSH
- Ansible installed on the control node
- An SSH key pair for the ansible user defined in inventory.ini

## Step 1: Bootstrap with Bash scripts

Run these once on the target host, in order, before Ansible takes over. They require root privileges.

```bash
sudo ./scripts/01-update-system.sh
sudo ./scripts/02-install-packages.sh
sudo ./scripts/03-configure-services.sh
sudo ./scripts/04-create-users.sh
sudo ./scripts/05-configure-firewall.sh
sudo ./scripts/07-backup-dirs.sh
```

06-generate-logs.sh can also be run manually at any time to generate an immediate log snapshot under /var/log/lab2-automation/. It is additionally installed as a weekly cron job by the backup role.

## Step 2: Update the inventory

Edit ansible/inventory.ini and set ansible_host to the IP address of your target machine, and point ansible_ssh_private_key_file at the correct key.

If running Ansible directly on the target host (control node and managed node are the same machine), add `ansible_connection=local` to the host line and omit the SSH key file:

```ini
[webservers]
web1 ansible_host=127.0.0.1 ansible_connection=local
```

## Step 3: Run the playbooks

To provision everything in one pass:

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

To run a single stage instead:

```bash
ansible-playbook playbooks/hardening.yml
ansible-playbook playbooks/webserver.yml
ansible-playbook playbooks/docker-deploy.yml
```

## Step 4: Verify the deployment

- Run `curl http://localhost` to confirm nginx is serving the templated index page.
- Run `curl http://localhost:8080` to confirm the Docker container is running.
- Run `sudo ufw status verbose` to confirm firewall rules.
- Run `sudo grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config` to confirm SSH hardening.
- Run `id deployer && id monitor` to confirm user accounts exist.
- Run `sudo crontab -l` to confirm the weekly update cron job is installed.
- Run `ls /backups/` to confirm backup directories were created.
- Run `sudo bash scripts/06-generate-logs.sh && ls /var/log/lab2-automation/` to confirm log generation.

## Step 5: Demonstrate rebuild capability

To prove the environment is reproducible, destroy the target VM and provision a new one with the same IP and SSH access, then run:

```bash
ansible-playbook playbooks/site.yml
```

against the new host. The resulting server should match the original in every respect. Re-running the same command against an unchanged host should report no changes, which confirms idempotency and the absence of configuration drift.

## Documentation

See docs/ARCHITECTURE.md for a full breakdown of each script and role, and docs/REFLECTION.md for the infrastructure as code discussion covering automation benefits, scalability, security, drift, and immutable infrastructure concepts.
