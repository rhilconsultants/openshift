# Ansible Operator Lab Configuration

## Golang Installation
To install Go, run the following as the root user:

```bash
# yum install -y golang.x86_64
```

## Install OpenShift and Container Image Commands:
* oc
* podman, buildah
* curl
* ansible

## OpenShift Variables
Ensure that users configure environment variables for login to OpenShift:
```bash
$ oc login api.$OCP_CLUSTER.$OCP_DOMAIN:6443
```

## Download Red Hat Images to Local Registry
Access to a number of images used in this course requires a Red Hat account. Download them to the local OpenShift registry as follows:
```bash
$ podman login registry.redhat.io
$ oc login -u kubeadmin
$ REGISTRY="$(oc get route/default-route -n openshift-image-registry -o=jsonpath='{.spec.host}')"
$ oc new-project openshift3
$ skopeo copy docker://registry.redhat.io/openshift3/ose-ansible docker://${REGISTRY}/openshift3/ose-ansible
$ oc new-project ubi8
$ skopeo copy docker://registry.redhat.io/ubi8/go-toolset docker://${REGISTRY}/ubi8/go-toolset
```

The image quay.io/operator-framework/ansible-operator is downloaded in Exercise-4. This image appears to download:
* https://galaxy.ansible.com/download/community-kubernetes-0.11.1.tar.gz
* https://galaxy.ansible.com/download/operator_sdk-util-0.1.0.tar.gz

## Download the Operator SDK
```bash
$ export RELEASE_VERSION=v1.2.0
$ cd /usr/share/workshop/
$ curl -LO https://github.com/operator-framework/operator-sdk/releases/download/${RELEASE_VERSION}/operator-sdk-${RELEASE_VERSION}-x86_64-linux-gnu
```

## OpenShift Accounts
Create accounts for:
* ${USER}
* ${USER}-client

## OpenShift Projects
Create OpenShift projects owned by ${USER}:
* project-${USER}
* ${USER}-hellogo-operator-system

## Podman rootless configuration
/etc/subuid may need to be configured for podman rootless use.