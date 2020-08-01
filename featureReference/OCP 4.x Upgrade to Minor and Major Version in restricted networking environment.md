
**_OCP 4.x Upgrade to Minor and Major Version in restricted networking environment_**

Main goals of updates/upgrades - bug fixes, new features, security vulnaribilities fixes, where ideal state is always be up to date.
Updates/upgrades can be done to the latest minor version of the existing current major version or to the next major version. 
For instance, if you deployed your cluster when the latest version was 4.4.12 you can upgrade it today to the latest minor 4.4.13 version 
or gradually to the latest existing version,i.e ocp 4.5.4.
In restricted networks this process includes additional steps of mirroring the relevant images in your existing private registry and changing 
configuration of several cluster components that will allow you to perform upgrade smoothly.

This document based on the next official Red Hat documentation links

[Updating a restricted network cluster](https://docs.openshift.com/container-platform/4.4/updating/updating-restricted-network-cluster.html)

[Updating a cluster between minor versions](https://docs.openshift.com/container-platform/4.3/updating/updating-cluster-between-minor.html)

[OpenShift Container Platform (OCP) 4 upgrade paths](https://access.redhat.com/solutions/4583231)

[Configuring the Samples Operator](https://docs.openshift.com/container-platform/4.2/openshift_images/configuring-samples-operator.html)


##
*1. Define your cluster upgrade path*

To upgrade your specific cluster to the latest minor version you don't need to perform upgrade path check, so you can jump directly to the next chapter.
But if you want to upgrade to the major version you need to know what is your cluster version upgrade path. 
To define it, perform the next:
```
# export CURRENT_VERSION=4.4.12
# export CHANNEL_NAME=stable-4.5
# curl -sH 'Accept:application/json' "https://api.openshift.com/api/upgrades_info/v1/graph?channel=${CHANNEL_NAME}" | jq -r --arg CURRENT_VERSION "${CURRENT_VERSION}" '. as $graph | $graph.nodes | map(.version=='\"$CURRENT_VERSION\"') | index(true) as $orig | $graph.edges | map(select(.[0] == $orig)[1]) | map($graph.nodes[.].version) | sort_by(.)'
OUTPUT
[]
```
It means you can't upgrade directly from existing version, 4.4.12, to any version in 4.5 major version, so next action is to define to what version inside 4.4 you can upgrade. For that, change your CHANNEL_NAME environment variable accordingly.
```
# export CHANNEL_NAME=stable-4.4
# curl -sH 'Accept:application/json' "https://api.openshift.com/api/upgrades_info/v1/graph?channel=${CHANNEL_NAME}" | jq -r --arg CURRENT_VERSION "${CURRENT_VERSION}" '. as $graph | $graph.nodes | map(.version=='\"$CURRENT_VERSION\"') | index(true) as $orig | $graph.edges | map(select(.[0] == $orig)[1]) | map($graph.nodes[.].version) | sort_by(.)'
OUTPUT
[
  "4.4.13"
]
```
Now you know that your next version for upgrade should be 4.4.13. And only after you will complet to upgrade to this latest minor version, you will repeat the steps above with CHANNEL_NAME=stable-4.5 to understand how to continue with upgrade path.

##
*2. Mirroring the OpenShift Container Platform image repository*

This step assume that you have external mirror registry and internal mirror registry ready with existing version repositories (It was required for your cluster deployment).
On your external mirror registry server (one that have connection to the Internet):
Set the required environment variables:
```
# export OCP_RELEASE=4.4.13
# export LOCAL_REGISTRY='registry.ocp43-prod.sales.lab.tlv.redhat.com:5000'
# export LOCAL_REPOSITORY='ocp4.4.13/openshift4.4.13'
# export PRODUCT_REPO='openshift-release-dev'
# cd /opt/registry/ (this is my base registry folder)
Check the content of the json file you prepared in deployment process that including your mirror registry.

# For example, our one called pull-secret2.json

OUTPUT
cat pull-secret2.json | jq
{
  "auths": {
    "cloud.openshift.com": {
      "auth": "b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K21hdGFuY2FybWVsaTk4MXF1eWZuYTlxdHlvZW03NHZyazdka3JtZHY3OjU0NFpBUVQzQldPTVpIRjFMOVpGT0ZHMFM5QTZOQkZPNE9IOEVLMjREUEhROVNCRUQ2OU9SNEdPSU5VQVJMSEU=",
      "email": "matan.carmeli7@gmail.com"
    },
    "quay.io": {
      "auth": "b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K21hdGFuY2FybWVsaTk4MXF1eWZuYTlxdHlvZW03NHZyazdka3JtZHY3OjU0NFpBUVQzQldPTVpIRjFMOVpGT0ZHMFM5QTZOQkZPNE9IOEVLMjREUEhROVNCRUQ2OU9SNEdPSU5VQVJMSEU=",
      "email": "matan.carmeli7@gmail.com"
    },
    "registry.connect.redhat.com": {
      "auth": "NTI0Nzc2MDF8dWhjLTFRdXlGTkE5cVRZb2VtNzR2Uks3RGtSbWR2NzpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSXdabVUwT0dFNU1qUXhaRGswWlRjMU9XTXlPVFZqTmpVeFl6Rm1PRGN4TUNKOS5uaGpuaTVjTHpIazF0Z243Z0NNZVVSQXlIRjE4NFlpd0tDd2pBcG9UX1JqUjZfak5JREJJSlZkLWhWUE1KYVlKWFFLY1pvY1ZQZWVfWFplUzZjVmQ3QXRkZGVNTWdLNWtZd3ZtczFsVnQyc0wtMHYwTDZOZ0FXQk9nY1hNbW9EcVFSb2tDQjBnakd0ZFNDbjItbTlSVXVwTkpfblJOUGpYSW1kVDAwSkJNd3dHUWUyVy1VQ0hWSTRzN09yNktNQUdHOWxWT0VoZU1tMnctRGpoOEZmTERTTlZDX0dueDNNODB6YUl4ak9MbmlZTzNXZGFaZXZmUUtoREtvYWpwREM5V1pXNTlEQkxiYTQ0b1lQWlVpUFMxNVdLMlVUcVNzUmpJR2JpMHV0LWwxLTRONGNSVlZsNmZLdWd2YjhudWxJUGV6cnU4ZXJzc1JyOWlrWXhCODFYQXVNUFNBc0xseG1KVzJPY1M0bERyeUlZX3daRFpYZ1M5X2FEUkNkSWppTWRuejZ0SG5KcHVfamFvalpVUmhyVDJfUUZVSEQ4dUwwMG9RVnJiUFBKNGVybENPQnJnMkRId1hvOGV2MFRoT2x2allfa0Q5azhCLTJZc2xtMVdvdTNnMEp3LS1Ia0w0MXNfd3F4OENMVXQtaDFMMWhKNHdfV3cxZFpUdlBIS2t2OXcwS0JjM1BZY1dzNWF4SU5uZk1kMEE1WWF3NGNVQnJvRjFFV0gyMU5NSzV0V1NoMm5Oa0ZFdTNWZEduRVhuelZpYnJJNko4Y01SeWxUR1hYUGdnMDF4a0FOVDlJNjV4RGpKMTJWNmRac0o4bXVJYjhobzZma25mekxPNHNicW9hR2xGbGZiTmRJTDYwSlpQYWV6RUdaQXdBOTlCYk83NFdjU0stN25zU0ZWOA==",
      "email": "matan.carmeli7@gmail.com"
    },
    "registry.redhat.io": {
      "auth": "NTI0Nzc2MDF8dWhjLTFRdXlGTkE5cVRZb2VtNzR2Uks3RGtSbWR2NzpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSXdabVUwT0dFNU1qUXhaRGswWlRjMU9XTXlPVFZqTmpVeFl6Rm1PRGN4TUNKOS5uaGpuaTVjTHpIazF0Z243Z0NNZVVSQXlIRjE4NFlpd0tDd2pBcG9UX1JqUjZfak5JREJJSlZkLWhWUE1KYVlKWFFLY1pvY1ZQZWVfWFplUzZjVmQ3QXRkZGVNTWdLNWtZd3ZtczFsVnQyc0wtMHYwTDZOZ0FXQk9nY1hNbW9EcVFSb2tDQjBnakd0ZFNDbjItbTlSVXVwTkpfblJOUGpYSW1kVDAwSkJNd3dHUWUyVy1VQ0hWSTRzN09yNktNQUdHOWxWT0VoZU1tMnctRGpoOEZmTERTTlZDX0dueDNNODB6YUl4ak9MbmlZTzNXZGFaZXZmUUtoREtvYWpwREM5V1pXNTlEQkxiYTQ0b1lQWlVpUFMxNVdLMlVUcVNzUmpJR2JpMHV0LWwxLTRONGNSVlZsNmZLdWd2YjhudWxJUGV6cnU4ZXJzc1JyOWlrWXhCODFYQXVNUFNBc0xseG1KVzJPY1M0bERyeUlZX3daRFpYZ1M5X2FEUkNkSWppTWRuejZ0SG5KcHVfamFvalpVUmhyVDJfUUZVSEQ4dUwwMG9RVnJiUFBKNGVybENPQnJnMkRId1hvOGV2MFRoT2x2allfa0Q5azhCLTJZc2xtMVdvdTNnMEp3LS1Ia0w0MXNfd3F4OENMVXQtaDFMMWhKNHdfV3cxZFpUdlBIS2t2OXcwS0JjM1BZY1dzNWF4SU5uZk1kMEE1WWF3NGNVQnJvRjFFV0gyMU5NSzV0V1NoMm5Oa0ZFdTNWZEduRVhuelZpYnJJNko4Y01SeWxUR1hYUGdnMDF4a0FOVDlJNjV4RGpKMTJWNmRac0o4bXVJYjhobzZma25mekxPNHNicW9hR2xGbGZiTmRJTDYwSlpQYWV6RUdaQXdBOTlCYk83NFdjU0stN25zU0ZWOA==",
      "email": "matan.carmeli7@gmail.com"
    },
    "registry.ocp43-prod.sales.lab.tlv.redhat.com:5000": {
      "auth": "YWRtaW46cmVkaGF0"
    }
  }
}

# export LOCAL_SECRET_JSON="/opt/registry/pull-secret2.json"
# export RELEASE_NAME="ocp-release"
# podman login quay.io 

OUTPUT
Authenticating with existing credentials...
Existing credentials are valid. Already logged in to quay.io

# oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-x86_64 --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE} | tee -a '/opt/registry/mirror-output${OCP_RELEASE}.txt'
OUTPUT
info: Mirroring 109 images to registry.ocp43-prod.sales.lab.tlv.redhat.com:5000/ocp4.4.13/openshift4.4.13 ...
```

Uploading to your external registry can take a while. After completing those steps you can tar you relevant blob folders (from the last day) and the relevant repository folder and move with this tar file to whitening process and after that extracting and adding to the relevant folders in your internal mirror registry.
To check that you have all relevant images in the repository you are just uploaded to your registry run the next:
```
# curl https://registry.ocp43-prod.sales.lab.tlv.redhat.com:5000/v2/ocp4.4.13/openshift4.4.13/tags/list -k -u admin:redhat

OUTPUT

{"name":"ocp4.4.13/openshift4.4.13","tags":["4.4.13-kube-etcd-signer-server","4.4.13-cli-artifacts","4.4.13-oauth-proxy","4.4.13-cluster-kube-controller-manager-operator","4.4.13-service-ca-operator","4.4.13-baremetal-operator","4.4.13-cluster-csi-snapshot-controller-operator","4.4.13-cluster-svcat-apiserver-operator","4.4.13-prometheus-operator","4.4.13-cluster-node-tuning-operator","4.4.13-cluster-dns-operator","4.4.13-openstack-machine-controllers","4.4.13-cluster-update-keys","4.4.13-cluster-svcat-controller-manager-operator","4.4.13-kuryr-controller","4.4.13-insights-operator","4.4.13-prometheus-config-reloader","4.4.13-csi-snapshot-controller","4.4.13-oauth-server","4.4.13-baremetal-runtimecfg","4.4.13-operator-registry","4.4.13-cluster-monitoring-operator","4.4.13-multus-route-override-cni","4.4.13-service-catalog","4.4.13-ironic-inspector","4.4.13-cluster-policy-controller","4.4.13-ironic-machine-os-downloader","4.4.13-cluster-openshift-apiserver-operator","4.4.13-machine-api-operator","4.4.13-kube-rbac-proxy","4.4.13-grafana","4.4.13-ironic-static-ip-manager","4.4.13-multus-admission-controller","4.4.13-aws-machine-controllers","4.4.13-libvirt-machine-controllers","4.4.13-cloud-credential-operator","4.4.13-keepalived-ipfailover","4.4.13-console-operator","4.4.13-kube-storage-version-migrator","4.4.13-cluster-node-tuned","4.4.13-cluster-kube-storage-version-migrator-operator","4.4.13-operator-marketplace","4.4.13-cluster-version-operator","4.4.13-openshift-controller-manager","4.4.13-kube-client-agent","4.4.13-kube-state-metrics","4.4.13-cluster-machine-approver","4.4.13-multus-whereabouts-ipam-cni","4.4.13-docker-registry","4.4.13-cluster-autoscaler","4.4.13-installer-artifacts","4.4.13-baremetal-installer","4.4.13-coredns","4.4.13","4.4.13-ironic-hardware-inventory-recorder","4.4.13-machine-config-operator","4.4.13-deployer","4.4.13-telemeter","4.4.13-ironic-ipa-downloader","4.4.13-cluster-samples-operator","4.4.13-cli","4.4.13-cluster-openshift-controller-manager-operator","4.4.13-baremetal-machine-controllers","4.4.13-cluster-kube-apiserver-operator","4.4.13-ovn-kubernetes","4.4.13-cluster-network-operator","4.4.13-tests","4.4.13-cluster-etcd-operator","4.4.13-multus-cni","4.4.13-kube-proxy","4.4.13-docker-builder","4.4.13-must-gather","4.4.13-sdn","4.4.13-openshift-apiserver","4.4.13-cluster-ingress-operator","4.4.13-ironic","4.4.13-operator-lifecycle-manager","4.4.13-prom-label-proxy","4.4.13-cluster-storage-operator","4.4.13-jenkins","4.4.13-machine-os-content","4.4.13-jenkins-agent-maven","4.4.13-cluster-config-operator","4.4.13-cluster-authentication-operator","4.4.13-gcp-machine-controllers","4.4.13-kuryr-cni","4.4.13-hyperkube","4.4.13-cluster-image-registry-operator","4.4.13-thanos","4.4.13-configmap-reloader","4.4.13-pod","4.4.13-prometheus","4.4.13-openshift-state-metrics","4.4.13-installer","4.4.13-cluster-bootstrap","4.4.13-cluster-autoscaler-operator","4.4.13-azure-machine-controllers","4.4.13-mdns-publisher","4.4.13-prometheus-node-exporter","4.4.13-prometheus-alertmanager","4.4.13-console","4.4.13-ovirt-machine-controllers","4.4.13-haproxy-router","4.4.13-cluster-kube-scheduler-operator","4.4.13-jenkins-agent-nodejs","4.4.13-container-networking-plugins","4.4.13-k8s-prometheus-adapter","4.4.13-local-storage-static-provisioner","4.4.13-etcd"]}
```
##
*3. Edit your cluster ImageContentSourcePolicy*

Next steps will be performed from installer machine of your cluster
```
# oc get ImageContentSourcePolicy
# oc edit ImageContentSourcePolicy image-policy-0

Change ocp4.4.12/openshift4.4.12 to ocp4.4.13/openshift4.4.13 and save

# oc edit ImageContentSourcePolicy image-policy-1

Change ocp4.4.12/openshift4.4.12 to ocp4.4.13/openshift4.4.13 and save
```
##
*4. Upgrade your cluster to latest minor version*

Now you can go to your Ocp console --> Administration --> Cluster settings --> Details --> Update
This process will run in background and can take a while. At the end of the process your cluster will be up to date (With latest minor version of the same major version)
At some point when you will check your update status you might see the next notification:
"Unable to apply 4.4.13: the cluster operator openshift-samples is degraded"
And by running oc get co you can see that openshift-samples cluster operator really in degraded state

```
# oc get co | grep openshift-samples
openshift-samples   4.4.13    True        True          True       38h
```

To fix this issue you need to add your registry to configs.samples.operator.openshift.io/cluster resource, since if samplesRegistry not defined, update of sample images trying to go to redhat.io to pull the relevant images and it can't do it in restricted network environments.

```
# oc edit configs.samples.operator.openshift.io/cluster
spec:
  architectures:
  - x86_64
  managementState: Managed
  samplesRegistry: registry.ocp43-prod.sales.lab.tlv.redhat.com:5000
```

Now by running oc get co you can see that openshift-samples cluster operator in Available state

```
# oc get co | grep openshift-samples
openshift-samples   4.4.13    True        False         False      38h
```
At the end of the process you can check your current version by running

```
# oc version
Client Version: 4.4.12
Server Version: 4.4.13
Kubernetes Version: v1.17.1+3288478
```
##
*5. Upgrade your cluster to major version*

Now, after successfull update to the latest minor version, you can continue and upgrade to the major version.
Before you will continue, please repeat steps in paragraph 2 (mirror your registry with required version images, for instance 4.5.4)
Next, before you update your cluster, you must manually create a ConfigMap that contains the signatures of the release images that you use. This signature allows the Cluster Version Operator (CVO) to verify that the release images have not been modified by comparing the expected and actual image signatures.

If you are upgrading from version 4.4.8 or later, you can use the oc CLI to create the ConfigMap. If you are upgrading from an earlier version, you must use the manual method.

###
Creating an image signature ConfigMap manually

Add the version to the OCP_RELEASE_NUMBER environment variable:
```
$ OCP_RELEASE_NUMBER=4.5.4
```
Add the system architecture for your cluster to ARCHITECTURE environment variable:
```
$ ARCHITECTURE=x86_64
```
Get the release image digest from Quay:
```
$ DIGEST="$(oc adm release info quay.io/openshift-release-dev/ocp-release:${OCP_RELEASE_NUMBER}-${ARCHITECTURE} | sed -n 's/Pull From: .*@//p')"
```
Set the digest algorithm:
```
$ DIGEST_ALGO="${DIGEST%%:*}"
```
Set the digest signature:
```
$ DIGEST_ENCODED="${DIGEST#*:}"
```
Get the image signature from mirror.openshift.com website:
```
$ SIGNATURE_BASE64=$(curl -s "https://mirror.openshift.com/pub/openshift-v4/signatures/openshift/release/${DIGEST_ALGO}=${DIGEST_ENCODED}/signature-1" | base64 -w0 && echo)
```
Create the ConfigMap:
```
$ cat >checksum-${OCP_RELEASE_NUMBER}.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: release-image-${OCP_RELEASE_NUMBER}
  namespace: openshift-config-managed
  labels:
    release.openshift.io/verification-signatures: ""
binaryData:
  ${DIGEST_ALGO}-${DIGEST_ENCODED}: ${SIGNATURE_BASE64}
EOF
```
Apply the ConfigMap to the cluster to update:
```
$ oc apply -f checksum-${OCP_RELEASE_NUMBER}.yaml
```
###
Edit your cluster ImageContentSourcePolicy*

Next steps will be performed from installer machine of your cluster
```
# oc get ImageContentSourcePolicy
# oc edit ImageContentSourcePolicy image-policy-0

Change ocp4.4.13/openshift4.4.13 to ocp4.5.4/openshift4.5.4 and save

# oc edit ImageContentSourcePolicy image-policy-1

Change ocp4.4.13/openshift4.4.13 to ocp4.5.4/openshift4.5.4 and save
```
Now you can go to your Ocp console --> Administration --> Cluster settings --> Details -->Channel and change to Stable-4.5 or Fast-4.5 --> Update

This process will run in background and can take a while. At the end of the process your cluster will be up to date (With latest minor version of the major version). The can encounter the same issues with openshift-samples operator during this upgrade - solution explaned above.
