# OCP Ansible Roles 

This repository is used for deploying various OCP workloads using Ansible Automation.

## Registry 

The `registry` role will create a Docker V2 registry using ansible local connection. This approach is very useful for mirroring images before a disconnected Openshift installation or Catalog mirroring.

The following automation works with a local ansible connection, taking into consideration all the needed steps for a docker registry to function as needed. After the playbook finishes and the validation phase has passed, you could just `podman login <your_registry>` to start interacting with it.

To run the automation:

* Change the vars which are located in `roles/registry/vars/main.yml` to your real registry FQDN.
* Run the command `ansible-playbook playbooks/registry.yml` and wait for it to finish
