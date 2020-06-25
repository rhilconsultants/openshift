## OCP Ansible Roles 

This repository is used for deploying various OCP workloads using Ansible Automation.

## Local Storage Operator 

This role installs the Local Storage Operator and configures all the needed parameters for the LSO to create the PVs needed locally for OCS. in `defaults/main.yml` you could change the vars for getting the device labels/ UUIDs of the attached local devices. This role requires creating devices for both MONs and OSDs, eventually the LSO will autodiscover those devices and create the needed PVs for MONs and OSDs. 

The automation will create a Subscription, OperatorGroup and a Namespace for the LSO, it will also use Jinja2 template to create the localvolume CR for both MONs and OSDs. 

## Openshift Container Storage Operator 

This role installed the StorageCluster need for OCS in order to function. This role creates a Namespace, Subscription and an OperatorGroup. After creating those, the role will create your StorageCluster which will take the DeviceSets using the previously created PVs. At the end, the role will set the Ceph RBD StorageClass as the default one so that all workloads could used by the RBD StorageClass.
In the `defaults/main.yml` file, just specify the current StorageClass so that the role will which one it should disable. 

## Registry 

The `registry` role will create a Docker V2 registry using ansible local connection. This approach is very useful for mirroring images before a disconnected Openshift installation or Catalog mirroring. 

