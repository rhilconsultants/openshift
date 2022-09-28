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
$ echo '#!/bin/bash

if [[ -z "$INVENTORY" ]]; then
  echo "No inventory file provided (environment value INVENTORY)"
  INVENTORY=/etc/ansible/hosts
else
  export INVENTORY=${INVENTORY}
fi

if [[ -z "$OPTS" ]]; then
  echo "no OPTS option provided (OPTS environment value)"
else
  export OPTS=${OPTS}

fi 

if [[ -z "$K8S_AUTH_API_KEY" ]]; then 
  echo "No Kubernetes Authentication key provided (K8S_AUTH_API_KEY environment value)"
else 
  export K8S_AUTH_API_KEY=${K8S_AUTH_API_KEY}
fi

if [[ -z "${K8S_AUTH_KUBECONFIG}" ]]; then
   echo "NO K8S_AUTH_KUBECONFIG environment variable configured"
   exit 1
fi

if [[ -z "${K8S_AUTH_HOST}" ]]; then
  echo "no Kubernetes API provided (K8S_AUTH_HOST environment value)"
else
   export  K8S_AUTH_HOST=${K8S_AUTH_HOST}
fi

if [[ -z "${K8S_AUTH_VALIDATE_CERTS}" ]]; then
    echo "No validation flag provided (Default: K8S_AUTH_VALIDATE_CERTS=true)"
else
   export K8S_AUTH_VALIDATE_CERTS=${K8S_AUTH_VALIDATE_CERTS}
fi  

if [[ -z $"$PLAYBOOK_FILE" ]]; then
  echo "No Playbook file provided... exiting"
  exit 1
else
   ansible-playbook $PLAYBOOK_FILE
fi' > run-ansible.sh
```

Make it As executable :

```bash
$ chmod a+x run-ansible.sh
```
#### Copy kubeconfig

For simple access we will copy the kubeconfig from out corrent working profile so the ansible playbook will be able to use it :

```bash
$ cp ~/.kube/config.json /ose-openshift/kubeconfig
```

#### the Dockerfile 

Let’s create a new Dockerfile and edit it:
```bash
FROM python:3.8-slim

# RUN adduser --disabled-password -u 1001 --home /opt/app-root/ slim

ENV HOME=/opt/app-root/ \
    PATH="${PATH}:/root/.local/bin"
RUN mkdir /opt/app-root/src && mkdir /opt/app-root/.kube/
COPY kubeconfig /opt/app-root/.kube/config.json
COPY run-ansible.sh /usr/bin/

RUN pip install pip --upgrade
RUN pip install ansible openshift kubernetes 

LABEL \
        name="openshift/ose-ansible" \
        summary="OpenShift's installation and configuration tool" \
        description="A containerized ose-openshift image to let you run playbooks" \
        url="https://github.com/openshift/openshift-ansible" \
        io.k8s.display-name="openshift-ansible" \
        io.k8s.description="A containerized ose-openshift image to let you run playbooks on OpenShift" \
        io.openshift.expose-services="" \
        io.openshift.tags="openshift,install,upgrade,ansible" \
        com.redhat.component="aos3-installation-container" \
        version="v3.11.346" \
        release="2" \
        architecture="x86_64" \
        atomic.run="once" \
        License="GPLv2+" \
        vendor="CentOS" \
        io.openshift.maintainer.product="OpenShift Container Platform" \
        io.openshift.build.commit.id="f65cc700d2483fd9a485a7bd6cd929cbbed1b772" \
        io.openshift.build.source-location="https://github.com/openshift/openshift-ansible"

WORKDIR /opt/app-root/

ENTRYPOINT [ "/usr/bin/run-ansible.sh" ]
CMD [ "/usr/bin/run-ansible.sh" ]
```

*NOTE* 
we are using here a pyhton-3.8 base image for simplicity but in normal workloads we will need to use ubi to build our needed container.

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

### Create a new namesapce :

```bash
$ $ oc new-project project-${USER}
```

Next, we'll use the Ansible k8s modules to leverage existing Kubernetes and OpenShift Resource files. Let's take use the hello-go deployment example.

### Create the YAML Files

** NOTE **
for internal registry update the REGISTRY inventory
```bash
$ export REGISTRY="image-registry.openshift-image-registry.svc:5000"
```
If you are using different registry just change the image path to the corrent registry

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
$ oc policy add-role-to-user admin system:serviceaccounts:project-${USER} --namespace=${USER}
```

First update the inventory file for our internal connection :
```bash
$ cat > inventory << EOF
[localhost]
127.0.0.1 ansible_connection=local ansible_host=localhost ansible_python_interpreter=/usr/bin/python3
EOF
```

Update tasks file Hello-go-role/tasks/main.yml to create the hello-go deployment using the k8s module:
```yaml
$ cat > roles/Hello-go-role/tasks/main.yml <<EOF
---
- name: set hello-go deployment to {{ state }}
  kubernetes.core.k8s:
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

Create an src directory

```bash
$ mkdir ${HOME}/ose-openshift/src/
```

### Copy kubeconfig

For simple access we will copy the kubeconfig from out corrent working profile so the ansible playbook will be able to use it :

```bash
$ cp ~/.kube/config.json /ose-openshift/kubeconfig
```

### Running the Image

Now we can run the Ansible playbook to deploy your hello-go application on OpenShift:
```bash
$ podman run --rm --name ose-openshift \
    -e OPTS="-v" \
    -v ${HOME}/ose-openshift/src/:/opt/app-root/src/:Z,rw \
    -v ${HOME}/ose-openshift/:/opt/app-root/ose-ansible/:Z,ro \
    -e PLAYBOOK_FILE=/opt/app-root/ose-ansible/playbook.yaml \
    -e K8S_AUTH_KUBECONFIG=/opt/app-root/ose-ansible/kubeconfig \
    -e INVENTORY=/opt/app-root/ose-ansible/inventory \
    -e K8S_AUTH_API_KEY=$(oc whoami -t) \
    -e DEFAULT_LOCAL_TMP=/tmp/ \
    -e K8S_AUTH_HOST=$(oc whoami --show-server) \
    -e K8S_AUTH_VALIDATE_CERTS=false \
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
$ podman run --rm --name ose-openshift \
    -e OPTS="-v" \
    -v ${HOME}/ose-openshift/src/:/opt/app-root/src/:Z,rw \
    -v ${HOME}/ose-openshift/:/opt/app-root/ose-ansible/:Z,ro \
    -e PLAYBOOK_FILE=/opt/app-root/ose-ansible/playbook.yaml \
    -e K8S_AUTH_KUBECONFIG=/opt/app-root/ose-ansible/kubeconfig \
    -e INVENTORY=/opt/app-root/ose-ansible/inventory \
    -e K8S_AUTH_API_KEY=$(oc whoami -t) \
    -e DEFAULT_LOCAL_TMP=/tmp/ \
    -e K8S_AUTH_HOST=$(oc whoami --show-server) \
    -e K8S_AUTH_VALIDATE_CERTS=false \
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