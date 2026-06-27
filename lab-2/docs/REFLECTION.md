# Infrastructure-as-Code Reflection

## Benefits of automation

The benefits of automation especially in provisioning is to eliminate the human mistakes and manual procedures that lead to inconsistent servers. Every task in this lab such as installation of packages and setting up of firewalls is specified once in a script or playbook and then executed in the exact manner every time. This reduces the time spent on manual setup of the machine from hours to minutes while eliminating the possibility of missing out on a required step.

## Operational scalability

Since the same set of playbooks will execute on any host added to the inventory file, scaling from one server to many only requires adding entries in the inventory file. Roles are reusable parts of the process so a new service may leverage the pre-defined users, firewall and ssh hardening roles.

## Security implications

Storing firewall rules and SSH settings in code allows for consistent baseline security across all machines that includes denied root logins, password authentication turned off, and default deny policy in the firewall. It is possible to review, track, and roll back security settings kept in git as opposed to the manual procedure of securing each host when it is deployed.

## Risks of configuration drift

Configuration drift occurs when the host is altered manually after its initial deployment leading to differences between its current and documented states. The solution to configuration drift in this lab is making sure that every change made is idempotent. Hardening.yml and webserver.yml files can be ran repeatedly on hosts with no changes made. Drift can therefore be detected easily by simply running the playbooks and ensuring that there are no hosts reporting changed states. Drifting can be fixed easily by running the playbooks again.

## Immutable infrastructure concepts

In the immutable infrastructure approach the running servers are considered disposable since the idea is not to continuously patch them but to destroy and rebuild them based on the exact same playbooks. This lab proves that this concept works since the whole setup from the user accounts and even the containers is done using the version controlled playbooks. Building a server again is as simple as setting up a fresh machine and running site.yml on it.
