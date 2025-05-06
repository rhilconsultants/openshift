# Exercise 3 - Ansible Container

### Create an ose-openshift Image

We are going to create a New Image of ose-ansible by building an image with the appropriate package along with a small shell script to define the variables and run the playbook 

First go to your ose-openshift directory:
```bash
$ mkdir ~/ose-openshift && cd ~/ose-openshift
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
   ansible-playbook $OPTS $PLAYBOOK_FILE -i $INVENTORY
fi' > run-ansible.sh
```

Make it As executable :

```bash
$ chmod a+x run-ansible.sh
```
#### Copy kubeconfig

For simple access we will copy the kubeconfig from out corrent working profile so the ansible playbook will be able to use it :

```bash
$ cp ~/.kube/config ~/ose-openshift/kubeconfig
```

#### the Dockerfile 

Let’s create a new Dockerfile and edit it:
```bash
FROM python:3.8-slim

# RUN adduser --disabled-password -u 1001 --home /opt/app-root/ slim

ENV HOME=/opt/app-root/ \
    PATH="${PATH}:/root/.local/bin"
RUN mkdir -p /opt/app-root/src && mkdir /opt/app-root/.kube/
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
        version="v4" \
        release="8" \
        architecture="x86_64" \
        atomic.run="once" \
        License="GPLv2+" \
        vendor="Slim" \
        io.openshift.maintainer.product="OpenShift Container Platform" \
        io.openshift.build.commit.id="f65cc700d2483fd9a485a7bd6cd929cbb111111" \
        io.openshift.build.source-location="https://github.com/openshift/openshift-ansible"

WORKDIR /opt/app-root/

ENTRYPOINT [ "/usr/bin/run-ansible.sh" ]
CMD [ "/usr/bin/run-ansible.sh" ]
```

**NOTE** 
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

Now we go ahead and push it to our Openshift internal registry

First setup the registry 
```bash
$ export REGISTRY="default-route-openshift-image-registry.apps.cluster-${UUID}.${UUID}.${SANDBOX}"
``` 

Login to the registry 
```bash
$ podman login -u $(oc whoami) -p $(oc whoami -t) ${REGISTRY}
```

Now tag the iamge and push it to our internal registry
```bash
$ podman tag ose-openshift ${REGISTRY}/${USER}-project/ose-openshift
$ podman push ${REGISTRY}/${USER}-project/ose-openshift 
```


## Running the Container 

First update the inventory file for our internal connection :
```bash
$ cat > inventory << EOF
[localhost]
127.0.0.1 ansible_connection=local ansible_host=localhost ansible_python_interpreter=/usr/bin/python3.8
[localhost:vars]
namespace=${USER}-project
EOF
```

Now let's copy the main.yaml and the roles directory from the past exercise to here 
```bash
$ cp ~/ose-ansible/main.yaml playbook.yaml
$ cp -R ~/ose-ansible/roles .
```

Create an src directory

```bash
$ mkdir ${HOME}/ose-openshift/src/
```

Running the Image

Now we can run the Ansible playbook to deploy your monkey-app application on OpenShift:

```bash
$ podman run -ti --rm --name ose-openshift \
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

Up until now we worked with a Pod definition , now let's change it to deployment  

Create a new file for deployment
```bash
$ cat > roles/monkey-app/templates/deployment.yaml.j2 << EOF
kind: Deployment
apiVersion: apps/v1
metadata:
  name: monkeyapp
spec:
  template:
    metadata:
      labels:
        app: monkey-app
    spec:
      containers:
        - name: monkey-app
          image: quay.io/two.oes/monkey-app
          ports:
          - containerPort: 8080
  replicas: 1
  selector:
    matchLabels:
      app: monkey-app
EOF
```

And replace the Pod referance with the deployment referance :

```bash
- name: set hello-go deployment to {{ state }}
  kubernetes.core.k8s:
    state: "{{ state }}"
    definition: "{{ lookup('template', 'deployment.yaml.j2') | from_yaml }}"
    namespace: ${USER}-project
```

Now run the playbook with the updates

```bash
$ podman run -ti --rm --name ose-openshift \
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

Now you should see the deployment , the replicaset and the Pod 
```bash
$ oc get all
```

That is it,
You can move to the next Exercise