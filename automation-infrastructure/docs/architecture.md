# Architecture Overview

## Summary

This framework uses a single tool, Ansible, to deploy and configure an
operational service running in Docker. There is no separate provisioning
tool and no virtual machine. Ansible connects to the local host and talks
directly to the Docker daemon through the community.docker collection.

## Components

1. **security_baseline role**
   Verifies Docker is installed and reachable before any deployment starts.
   Hardening settings (dropped capabilities, non-root user, resource limits)
   are defined as shared variables and applied to the service container in
   the service_deploy role.

2. **logging role**
   Creates a host directory to hold persisted logs and defines the log
   rotation settings used by the service container's logging driver.

3. **monitoring role**
   Deploys a cAdvisor container, which exposes a live dashboard of resource
   usage and health for every running container on the host.

4. **service_deploy role**
   Deploys the actual operational service (nginx by default) as a Docker
   container, with the security and logging settings from the earlier
   roles applied directly to the container definition.

## Flow

Running `ansible-playbook site.yml` executes the four roles in sequence:

| Step | Role              | Action                                           |
| ---- | ----------------- | ------------------------------------------------ |
| 1    | security_baseline | Confirms Docker is installed and reachable       |
| 2    | logging           | Prepares the log directory and rotation settings |
| 3    | monitoring        | Starts the cAdvisor container                    |
| 4    | service_deploy    | Starts the hardened service container            |

Each role completes fully before the next one begins, so a failure in an
earlier role (for example, Docker not being installed) stops the deployment
before any containers are started.

## Reusability

All container-specific values (image, ports, resource limits) live in
group_vars/all.yml. Deploying a different service only requires changing
those variables, the role logic itself does not need to change. Tags can
also be added to each role's tasks to allow running a subset of the
playbook independently, for example only re-running the monitoring role.

## Idempotency

Running the playbook a second time with no variable changes results in
no changes being reported, since each task checks current container state
before acting.
