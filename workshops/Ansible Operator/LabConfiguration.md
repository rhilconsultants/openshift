# Ansible Operator Lab Configuration

## Golang Installation
To install Go, run the following as the root user:

```bash
# dnf install -y golang.x86_64
```

## Install OpenShift and Container Image Commands:
* oc
* podman, buildah
* curl
* ansible
* make

## OpenShift Variables
Ensure that users configure environment variables for login to OpenShift:
```bash
# oc login api.$OCP_CLUSTER.$OCP_DOMAIN:6443
```

## Registry for the Workshop
The workshop is registry agnostic. That being said, whatever registry is use, it must be accessible and specified as unsecure in OpenShift.
### Option 1: Using the OpenShift Internal Registry
#### Exposing the Internal Registry
Set up an environment variable REGISTRY as follows:
```bash
# export REGISTRY="$(oc get routes -n openshift-image-registry -o json | jq -r '.items[].spec | select(.to.name=="image-registry") | .host')"
```
Check the value of `REGISTRY`. If it was not set, you may need to expost the registry service before running the command.

To expose the registry (as cluster admin):

```bash
# oc patch configs.imageregistry.operator.openshift.io/cluster \
--patch '{"spec":{"defaultRoute":true}}' --type=merge
```

#### Setting the Registry as Trusted
##### Creating Self Signed Certificate and CA

In order to make sure we have a supported registry we can generate a certificate request and then sighed it with letsencrypt to avoid any SSL errors.

to generate the certificate request: 

```bash
# export DOMAIN="$OCP_CLUSTER.$OCP_DOMAIN"
# export SHORT_NAME="*.apps"
```

and now let's create an answer file for the openssl command :
```bash
# cat > wildcard_answer.txt << EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
x509_extensions = req_ext
req_extensions = req_ext
distinguished_name = dn
[ dn ]
C=US
ST=New York
L=New York
O=MyOrg
OU=MyOrgUnit
emailAddress=me@working.me
CN = ${SHORT_NAME}.${DOMAIN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${SHORT_NAME}
DNS.2 = ${SHORT_NAME}.${DOMAIN}
EOF
```

Now let's create the certificate key :
```bash
# openssl genrsa -out wildcard.key 4096
```

and the certificate request :
```bash
# openssl req -new -key wildcard.key -out wildcard.csr -config <( cat wildcard_answer.txt )
```

It is a very good practice at this point to Test the CSR for DNS alternative names :

```bash
# openssl req -in wildcard.csr -noout -text | grep DNS
                  DNS:*.apps, DNS:*.apps.${DOMAIN}
```

Now Let's create a Custom CA:

```bash
# cat > csr_ca.txt << EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn 
x509_extensions = usr_cert
[ dn ]
C=US
ST=New York
L=New York
O=MyOrg
OU=MyOU
emailAddress=me@working.me
CN = server.example.com
[ usr_cert ]
basicConstraints=CA:TRUE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer 
EOF
```
Now for the key and the CA certificate :

```bash
# openssl genrsa -out ca.key 4096
# openssl req -new -x509 -key ca.key -days 730 -out ca.crt -config <( cat csr_ca.txt )
```
Now copy the ca.crt to your anchors directory :

```bash
# cp ca.crt /etc/pki/ca-trust/source/anchors/registry.crt
# update-ca-trust extract
```

All we need to do now is to sign the certificate and update OpenShift

```bash
# openssl x509 -req -in wildcard.csr -CA ca.crt -CAkey ca.key \
-CAcreateserial -out wildcard.crt -days 730 \
-extensions 'req_ext' -extfile <(cat wildcard_answer.txt)
```

##### Updating OpenShift wildcard

Now that we have the certificate and key of our new wildcard first we need to update OpenShift with the CA certificate and then the with the certificate and key

```bash
# cat > user-ca-bundle.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-ca-bundle
namespace: openshift-config
data:
  ca-bundle.crt: |
EOF
```

Add the CA for the file :
```bash
# cat ca.crt | sed "s/^/\ \ \ \ \ /g" >> user-ca-bundle.yaml
```
And update the ca configmap
```bash
# oc create -f user-ca-bundle.yaml
```

Update the ConfigMap certificate:
```bash
# oc patch proxy/cluster --type merge --patch '{"spec":{"trustedCA":{"name": "user-ca-bundle"}}}'
```

Creating the Route Wildcard bundle with our new certificate :
```bash
# cat wildcard.crt ca.crt > wildcard-bundle.crt 
```
Create a secret
```bash
# oc create secret tls router --cert=./wildcard-bundle.crt --key=./wildcard.key -n openshift-ingress
```

Finally patch the ingress controller operator to use the router certificate as the new default certificate.

```bash
# oc patch ingresscontrollers.operator default \
--type=merge -p '{"spec":{"defaultCertificate": {"name": "router"}}}' \
-n openshift-ingress-operator
```

##### Extract OpenShift api certificate

In some cases the environment is using a self signed for the Openshift API:
```bash
# cat ~/.kube/config | grep certificate-authority-data | awk '{print $2}' | base64 -d > openshift.crt
# cp openshift.crt /etc/pki/ca-trust/source/anchors/
# update-ca-trust extract
```

Check that all nodes are in a `Ready` state:
```bash
# oc get nodes
```

##### updating custom CA

##### Add the External Registry as Untrusted
Add the registry as trusted:
```bash
# oc patch --type=merge --patch="{\"spec\":{\"registrySources\":{\"insecureRegistries\":[\"${REGISTRY}\"]}}}" image.config.openshift.io/cluster
```
The machine-config-operator will push this change to all nodes. As the change is pushed out, nodes will change status to `NotReady,SchedulingDisabled`. Wait for all nodes to be `Ready`.
#### Configuring a Secret
Just update the ConfigMap of the proxy/cluster
```bash
# oc edit configmap user-ca-bundle -n openshift-config
```
And add your relevant CA

### Option 2: Using a Quay Registry
#### Installing Quay
Configure environment variables:
```bash
# QUAY_NAMESPACE="quay-enterprise"
# QUAY_NAME="quay"
# CLUSTER_DOMAIN=$(oc get route -n openshift-authentication oauth-openshift -o=jsonpath='{.spec.host}' | sed "s/oauth-openshift\.//")
# REGISTRY="${QUAY_NAME}-${QUAY_NAMESPACE}.${CLUSTER_DOMAIN}"
# echo ${REGISTRY}
```

#### Install the Quay Operator
Create a project named `quay-enterprise`:
```bash
# oc new-project ${QUAY_NAMESPACE}
```
Log in to quay.io using the Red Hat provided password and create a secret:
```bash
# podman login -u="redhat+quay" -p="<REDACTED>" quay.io
# oc create secret generic redhat-pull-secret --from-file=".dockerconfigjson=${XDG_RUNTIME_DIR}/containers/auth.json" --type='kubernetes.io/dockerconfigjson'
```
Install the Quay operator via the Web UI to the project named `quay-enterprise`.
![QuayInstall](images/redhatquay.png)
Wait for `Status` state `Succeeded`:
![WaitForSucceed](images/redhatquaysucceeded.png)

#### Setting the Registry as Trusted
Note that Quay does not appear to recover from this change, therefore, it must be run before Quay is created.

Check that all nodes are in a `Ready` state:
```bash
# oc get nodes
```
Add the registry as trusted:
```bash
# oc patch --type=merge --patch="{\"spec\":{\"registrySources\":{\"insecureRegistries\":[\"${REGISTRY}\"]}}}" image.config.openshift.io/cluster
```
The machine-config-operator will push this change to all nodes. As the change is pushed out, nodes will change status to `NotReady,SchedulingDisabled`. Wait for all nodes to be `Ready`.

#### Create the Quay Instance
Create the Quay instance by running the following:

```bash
# oc create -f - <<EOF
apiVersion: redhatcop.redhat.io/v1alpha1
kind: QuayEcosystem
metadata:
  name: ${QUAY_NAME}
  namespace: ${QUAY_NAMESPACE}
spec:
  quay:
    imagePullSecretName: redhat-pull-secret
    externalAccess:
      hostname: ${QUAY_NAME}-${QUAY_NAMESPACE}.${CLUSTER_DOMAIN}
EOF
```




The default login for quay is quay/password.
#### CRC - Setting the Registry as Trusted (ony for CRC)
```bash
#  ssh -i ~/.crc/machines/crc/id_rsa -o StrictHostKeyChecking=no core@$(crc ip) << EOF
  sudo echo " " | sudo tee -a /etc/containers/registries.conf
  sudo echo "[[registry]]" | sudo tee -a /etc/containers/registries.conf
  sudo echo "  location = \"${REGISTRY}\"" | sudo tee -a /etc/containers/registries.conf
  sudo echo "  insecure = true" | sudo tee -a /etc/containers/registries.conf
  sudo echo "  prefix = \"\"" | sudo tee -a /etc/containers/registries.conf
  sudo systemctl restart crio
  sudo systemctl restart kubelet
EOF
```

## Downloading Red Hat Images
Log in to the registry and create accounts for course users(1-n), "ubi8" and "openshift3".

Use the step below for the registry that will be used for the workshop.

### Download Red Hat Images to Local Registry
Access to a number of images used in this course requires a Red Hat account. Download them to the local OpenShift registry as follows:

First we need to create A kubeconfig to make sure we do not run over the "system:admin" account

```bash
# mkdir -p /root/cluster/auth/
# touch /root/cluster/auth/kubeconfig
# export KUBECONFIG="/root/cluster/auth/kubeconfig"
```

Now login to Openshift as a cluster admin account with token:
```bash
# oc login api.$OCP_CLUSTER.$OCP_DOMAIN:6443
```

create a new registry authentication file :
```bash
# mkdir -p ~/.registry/
# echo '{"auths":{}}' > ~/.registry/auths.json
```

### Log in to the Red Hat Registry
Use podman to login to both registries 
```bash
# export REGISTRY_AUTH_FILE="~/.registry/auths.json"
# podman login registry.redhat.io
# podman login $REGISTRY
```

Once you logged in into both registries we can continue with the image Download 

```bash
# oc new-project openshift3
# skopeo copy --authfile $REGISTRY_AUTH_FILE docker://registry.redhat.io/openshift3/ose-ansible docker://${REGISTRY}/openshift3/ose-ansible
# oc new-project ubi8
# skopeo copy --authfile $REGISTRY_AUTH_FILE docker://registry.redhat.io/ubi8/go-toolset docker://${REGISTRY}/ubi8/go-toolset
```

Now make sure authenticated users have access to those images
```bash
# oc adm policy add-role-to-group system:image-puller system:authenticated -n ubi8
Warning: Group 'system:authenticated' not found
clusterrole.rbac.authorization.k8s.io/system:image-puller added: "system:authenticated"

# oc adm policy add-role-to-group system:image-puller system:authenticated -n openshift3
Warning: Group 'system:authenticated' not found
clusterrole.rbac.authorization.k8s.io/system:image-puller added: "system:authenticated"
```

The image quay.io/operator-framework/ansible-operator is downloaded in Exercise-4. This image appears to download:
* https://galaxy.ansible.com/download/community-kubernetes-0.11.1.tar.gz
* https://galaxy.ansible.com/download/operator_sdk-util-0.1.0.tar.gz

### Download Red Hat Images to an External Registry
#### Create Users in the External Registry
Create users:
- user[1-n] for workshop attendies
- openshift3
- ubi8

#### Download Images
Access to a number of images used in this course requires a Red Hat account. Download them to the local OpenShift registry as follows:
```bash
# REGISTRY="<route to registry in use>"
# skopeo copy --authfile $REGISTRY_AUTH_FILE docker://registry.redhat.io/openshift3/ose-ansible\
 docker://${REGISTRY}/openshift3/ose-ansible
# skopeo copy --authfile $REGISTRY_AUTH_FILE docker://registry.redhat.io/ubi8/go-toolset\
 docker://${REGISTRY}/ubi8/go-toolset
```

**IMPORTANT:** Manually set the `Repository Visibility` to `public` for both images.

<!--
The image quay.io/operator-framework/ansible-operator is downloaded in Exercise-4. This image appears to download:
* https://galaxy.ansible.com/download/community-kubernetes-0.11.1.tar.gz
* https://galaxy.ansible.com/download/operator_sdk-util-0.1.0.tar.gz
-->

Optional Images:
* quay.io/operator-framework/ansible-operator:v1.3.0

## Download the Operator SDK
```bash
# export ARCH=$(case $(arch) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(arch) ;; esac)
# export OS=$(uname | awk '{print tolower($0)}')
# export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/latest/download
# curl -Lo /usr/local/bin/operator-sdk ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
# chmod a+x /usr/local/bin/operator-sdk
```

## Generate RPM directory
in Exercise 3 the users will need access to the /usr/share/workshop/RPMs/* directory in order to add the RPM required for python3-openshift.  
All we need to do is to enable EPEL
```bash
# dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
``` 

Use --downloadonly with the dnf command :
```bash
# mkdir /usr/share/workshop/RPMs/
# dnf install -y python3-openshift --downloadonly --downloaddir=/usr/share/workshop/RPMs/
```
The Student may need it for testing so install it on the Bastion
```bash
# dnf install -y python3-openshift
```

## OpenShift Accounts
Create accounts for:
* ${USER}
* ${USER}-client

## OpenShift Projects
Create OpenShift projects owned by ${USER}:
* project-${USER}
* ${USER}

```bash
# for int in {1..20}; do
oc new-project user${int}
oc adm policy add-role-to-user admin user${int} -n user${int}
oc new-project project-user${int}
oc adm policy add-role-to-user admin user${int} -n project-user${int}
done
```

## OpenShift Roles
For each user:
oc policy add-role-to-user registry-editor <username>

## Podman rootless configuration
/etc/subuid may need to be configured for podman rootless use.