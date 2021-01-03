# Exercise 3 - Ansible K8S Module

## Contents

* Ansible Container for Kubernetes and OpenShift
  * Create an ose-openshift Image
  * Clean up
* Running the Container 
  * Exposing the Application
  * Testing the Deployment
  * Final Task
  * Cleanup


## Ansible Container for Kubernetes and OpenShift

Now that we know that we need to update our image we need to provide the proper RPMs which provide the K8S module  and add them to our image .

### Create an ose-openshift Image

We are going to create a New Image of ose-ansible by building an image with the appropriate package along with a small shell script to define the variables and run the playbook 

First go to your ose-openshift directory:
```bash
$ cd ~/ose-openshift
```
Now Create a shell script :
```bash
$ cat > run-ansible.sh << EOF
#!/bin/bash

ANSIBLE_ENV_VARS=""

if [[ -z "/tmp/inventory" ]]; then
echo "No inventory file provided (environment value INVENTORY)"
exit 1;
else
ANSIBLE_ENV_VARS=" INVENTORY=/tmp/inventory"
fi

if [[ -z "-v" ]]; then
echo "no OPTS option provided (OPTS environment value)"
else
ANSIBLE_ENV_VARS=" OPTS=-v"

fi 

if [[ -z "XbmtEV0DRLe33Zn7fwmMfHEdqdNspejGZFaise-qs1c" ]]; then 
echo "No Kubernetes Authentication key provided (K8S_AUTH_API_KEY environment value)"
else 
ANSIBLE_ENV_VARS=" K8S_AUTH_API_KEY=XbmtEV0DRLe33Zn7fwmMfHEdqdNspejGZFaise-qs1c"
fi

if [[ -z "https://api.cluster-56f8.56f8.sandbox318.opentlc.com:6443" ]]; then
echo "no Kubernetes API provided (K8S_AUTH_HOST environment value)"
else
ANSIBLE_ENV_VARS="  K8S_AUTH_HOST=https://api.cluster-56f8.56f8.sandbox318.opentlc.com:6443"
fi

if [[ -z "true" ]]; then
  echo "No validation flag provided (Default: K8S_AUTH_VALIDATE_CERTS=true)"
else
ANSIBLE_ENV_VARS=" K8S_AUTH_VALIDATE_CERTS=true"
fi  

if [[ -z $"/opt/app-root/ose-ansible/playbook.yaml" ]]; then
echo "No Playbook file provided... exiting"
exit 1
else
 ansible-playbook /opt/app-root/ose-ansible/playbook.yaml
fi

EOF
```

And let’s create a new Dockerfile and edit it:
```bash
$ cat > Dockerfile << EOF
FROM centos

ENV __doozer=update BUILD_RELEASE=2 BUILD_VERSION=v3.11.346 OS_GIT_MAJOR=3 OS_GIT_MINOR=11 OS_GIT_PATCH=346 OS_GIT_TREE_STATE=clean OS_GIT_VERSION=3.11.346-2 SOURCE_GIT_TREE_STATE=clean 
ENV __doozer=merge OS_GIT_COMMIT=f65cc70 SOURCE_DATE_EPOCH=1607700712 SOURCE_GIT_COMMIT=f65cc700d2483fd9a485a7bd6cd929cbbed1b772 SOURCE_GIT_TAG=openshift-ansible-3.11.346-1 SOURCE_GIT_URL=https://github.com/openshift/openshift-ansible
ENV DEFAULT_LOCAL_TMP=/tmp

MAINTAINER Your Name

USER root

# Playbooks, roles, and their dependencies are installed from packages.
RUN INSTALL_PKGS="python3-openshift.noarch ansible python3-cryptography openssl iproute httpd-tools"  \
 && yum repolist > /dev/null  \
 && : 'removed yum-config-manager'  \
 && : 'removed yum-config-manager'  \
# && yum install -y java-1.8.0-openjdk-headless  \
 && yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
 && yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS \
# && rpm -q $INSTALL_PKGS $x86_EXTRA_RPMS  \
 && yum clean all

RUN mkdir -p /opt/app-root/src
RUN echo 'remote_tmp     = /tmp' >> /etc/ansible/ansible.cfg  && echo 'local_tmp      = /tmp' >> /etc/ansible/ansible.cfg


ENV USER_UID=1001 \
    DEFAULT_LOCAL_TMP=/tmp \
    HOME=/opt/app-root/src \
    WORK_DIR=/opt/app-root/src \
    ANSIBLE_CONFIG=/etc/ansible/ansible.cfg \
    OPTS="-v"

# Add image scripts and files for running as a system container
# COPY root /

COPY run-ansible.sh /usr/bin/

USER ${USER_UID}

WORKDIR ${WORK_DIR}
ENTRYPOINT [ "/usr/bin/run-ansible.sh" ]
CMD [ "/usr/bin/run-ansible.sh" ]

LABEL \
        name="openshift3/ose-ansible" \
        summary="OpenShift's installation and configuration tool" \
        description="A containerized openshift-ansible image to let you run playbooks to install, upgrade, maintain and check an OpenShift cluster" \
        url="https://github.com/openshift/openshift-ansible" \
        io.k8s.display-name="openshift-ansible" \
        io.k8s.description="A containerized openshift-ansible image to let you run playbooks to install, upgrade, maintain and check an OpenShift cluster" \
        io.openshift.expose-services="" \
        io.openshift.tags="openshift,install,upgrade,ansible" \
        com.redhat.component="aos3-installation-container" \
        version="v3.11.346" \
        release="2" \
        architecture="x86_64" \
        atomic.run="once" \
        License="GPLv2+" \
        vendor="Red Hat" \
        io.openshift.maintainer.product="OpenShift Container Platform" \
        io.openshift.build.commit.id="f65cc700d2483fd9a485a7bd6cd929cbbed1b772" \
        io.openshift.build.source-location="https://github.com/openshift/openshift-ansible" \
        io.openshift.build.commit.url="https://github.com/openshift/openshift-ansible/commit/f65cc700d2483fd9a485a7bd6cd929cbbed1b772"

EOF
```

*NOTE* 
we are using here a centos base image for simplicity but in normal workloads we will need to use ubi to build our needed container.

Build the container:
```bash
$ buildah bud -f Dockerfile -t ose-openshift .
```

If everything went well, you should see the new image in your registry:
```bash
$ podman images
```
**(What do you see wrong with this image and method ???)**



## Running the Container 

Next, we'll use the Ansible k8s modules to leverage existing Kubernetes and OpenShift Resource files. Let's take use the hello-go deployment example.

```yaml
$ cat > roles/Hello-go-role/templates/hello-go-deployment.yml.j2 <<EOF
kind: Deployment
apiVersion: apps/v1
metadata:
  name: hellogo-pod
spec:
  template:
    metadata:
      labels:
        app: hellogo
    spec:
      containers:
        - name: hello-go
          image: ${REGISTRY}/${USER}/hello-go
          ports:
          - containerPort: 8080
  replicas: 1
  selector:
    matchLabels:
      app: hellogo
EOF
```
We will run our Ansible task in a namespace called project-${USER}. If we are using the internal OpenShift registry, we must allow the default service account in the project to pull images from the ${USER} respository in the registry by running:
```bash
$ oc project project-${USER}
$ oc policy add-role-to-group system:image-puller system:serviceaccounts:project-${USER} --namespace=${USER}
```

Update tasks file Hello-go-role/tasks/main.yml to create the hello-go deployment using the k8s module:
```yaml
$ cat > roles/Hello-go-role/tasks/main.yml <<EOF
---
- name: set hello-go deployment to {{ state }}
  k8s:
    state: "{{ state }}"
    definition: "{{ lookup('template', 'hello-go-deployment.yml.j2') | from_yaml }}"
    namespace: project-${USER}
EOF
```
Note that for environments using self-signed certificates the following `k8s` setting can be added:
```yaml
    verify_ssl: false
```
Modify the variables file Hello-go-role/defaults/main.yml, setting state: present by default.
```yaml
$ cat > roles/Hello-go-role/defaults/main.yml <<EOF
---
state: present
size: 1
EOF
```
Now we can run the Ansible playbook to deploy your hello-go application on OpenShift:
```bash
$ podman run --rm --name ose-openshift -tu `id -u` \
    -v ${HOME}/ose-openshift/inventory:/tmp/inventory:Z,ro  \
    -e INVENTORY_FILE=/tmp/inventory \
    -e OPTS="-v" \
    -v ${HOME}/ose-openshift/:/opt/app-root/ose-ansible/:Z,ro \
    -e PLAYBOOK_FILE=/opt/app-root/ose-ansible/playbook.yaml \
    -e K8S_AUTH_API_KEY=$(oc whoami -t) \
    -e K8S_AUTH_HOST=$(oc whoami --show-server) \
    -e K8S_AUTH_VALIDATE_CERTS=true \
    ose-openshift
```

You can see the hello-go deployment created in your namespace.
```bash
$ oc get all -n project-${USER}
```
The output should be similar to the following:
```
NAME                               READY   STATUS    RESTARTS   AGE
pod/hellogo-pod-6888f96bd8-whnbc   1/1     Running   0          65s

NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hellogo-pod   1/1     1            1           11m

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/hellogo-pod-6888f96bd8   1         1         1       11m
```

Next, let's make it possible to customize the replica count for our hello-go deployment by adding an hellogo_replicas variable to the DeploymentConfig template and setting the variable value dynamically using Ansible.

Modify the variables file `roles/Hello-go-role/defaults/main.yml`, setting size: 2:
```yaml
---
state: present
size: 2
```
Modify the roles/Hello-go-role/templates/hello-go-deployment.yml.j2 deployment template to read replicas from the hellogo_replicas variable rather than the fixed size of 1:
```yaml
kind: Deployment
apiVersion: v1
metadata:
  name: hellogo-pod
spec:
  template:
    metadata:
      labels:
        app: hellogo
    spec:
      containers:
        - name: hello-go
          image: ${REGISTRY}/${USER}/hello-go
          ports:
          - containerPort: 8080
  replicas: {{ size }}
  selector:
    matchLabels:
      app: hellogo
```
Running the Playbook again will read the variable hellogo_replicas and use the provided value to customize the hello-go DeploymentConfig.
```bash
$ podman run --rm --name ose-openshift -tu `id -u` \
    -v ~/ose-openshift/inventory:/tmp/inventory:Z,ro  \
    -e INVENTORY_FILE=/tmp/inventory \
    -e OPTS="-v" \
    -v ~/ose-openshift/:/opt/app-root/ose-ansible/:Z,ro \
    -e PLAYBOOK_FILE=/opt/app-root/ose-ansible/playbook.yaml \
    -e K8S_AUTH_API_KEY=$(oc whoami -t) \
    -e K8S_AUTH_HOST=$(oc whoami --show-server) \
    -e K8S_AUTH_VALIDATE_CERTS=true \
    ose-openshift
```
After running the Playbook, the cluster will scale the number of hellogo pods to meet the new requested replica count of 2. 
```bash
$ oc get pods -n project-${USER}
```
You should now see two pods running.

### Exposing the Application

In order to expose our application we first need to create a service with a label that matches the application label and then a create a route for that service.

Now we can add a service with the matching label:
```yaml
$ cat > hello-go-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: hellogo-service
  namespace: project-${USER}
spec:
  selector:
    app: hellogo
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
EOF
```
And now the route yaml:
```yaml
$ cat > hello-go-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: hellogo-route
  namespace: project-${USER}
spec:
  port:
    targetPort: 8080
  to:
    kind: Service
    name: hellogo-service
    weight: 100
  wildcardPolicy: None
EOF
```
Now create the service and route resources:
```bash
$ oc create -f hello-go-service.yaml -f hello-go-route.yaml
```
### Testing the Deployment

Create an environment variable with the route to the application's service:
```bash
$ ROUTE=$(oc get route hellogo-route -n project-${USER} -o=jsonpath='{.spec.host}')
$ echo ${ROUTE}
```
Now access the hello-go application:
```bash
$ curl ${ROUTE}/testingInsideOpenShift
```
The output should be:
```
Hello, you requested: /testingInsideOpenShift
```

### Final Task

If everything is running as expected we can delete it by changing the ‘state’ variable in the `roles/Hello-go-role/defaults/main.yml` file from **present** to **absent**. 

After changing it, run the playbook again and verify there are no pods by running the command: `oc get pods`.

### Cleanup

Remove the service and the route:
```bash
$ oc delete -f hello-go-route.yaml -f hello-go-service.yaml
```