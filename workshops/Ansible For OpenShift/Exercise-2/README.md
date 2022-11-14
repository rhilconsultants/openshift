# Exercise 2

## Ansible Kubernetes Module
In This Exercise we will learn about the Ansible kubernetes Module.

The 3 way we are going to work with the module are :

- kubernetes.core.k8s
- kubernetes.core.k8s_info
- kubernetes.core.k8s_exec

### kubernetes.core.k8s Synopsis

- Use the Kubernetes Python client to perform CRUD operations on K8s objects.
- Pass the object definition from a source file or inline. See examples for reading files and using Jinja templates or vault-encrypted files.
- Access to the full range of K8s APIs.
- Authenticate using either a config file, certificates, password or token.
- Supports check mode.

### kubernetes.core.k8s_info Synopsis

- Use the Kubernetes Python client to perform read operations on K8s objects.
- Access to the full range of K8s APIs.
- Authenticate using either a config file, certificates, password or token.
- Supports check mode.
- This module was called k8s_facts before Ansible 2.9. The usage did not change.

### kubernetes.core.k8s_exec Synopsis

- Use the Kubernetes Python client to execute command on K8s pods.

