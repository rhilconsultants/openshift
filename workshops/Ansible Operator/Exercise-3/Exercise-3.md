# Exercise 3 - Ansible K8S module

## Contents
  - Running the Container
    - Exposing the application:
    - Final Task
  - Advanced - Generate kubeconfig

## Ansible Container

Now that we know that we need to update our image we need to provide the proper RPMs which provide the K8S module  and add them to our image .

### Create the ose-openshift container

The RPMs you need are in /usr/share/workshop/RPMS

First go to your ose-openshift directory:

    # cd ~/ose-openshift

Now Copy the RPMs from the share Directory:

    # cp /usr/share/workshop/RPMs/* .

And let’s create a new Dockerfile and edit it :

    # cat > Dockerfile << EOF
    FROM registry.infra.local:5000/openshift3/ose-ansible
    MAINTAINER  Meemail me@comefind.me # not a real email

    USER root
    WORKDIR /opt/app-root/
    COPY python* .
    RUN yum install -y python* && rm -f python*
    EOF

Build the container :

    # buildah bud -f Dockerfile -t ose-openshift .

If Everything went well , you should see the new image on the Server

    # podman image list

**(What do you See wrong with this image and method ???)**

### Clean up

Remove the RPMs from the folder

    # rm -f ~/ose-openshift/*.rpm

## Running the Container 

**Make sure you are running the container with the variable of 
“K8S_AUTH_KUBECONFIG” after you added a map to your ${HOME}/.kube/config file**

    # podman run ...

** (HINT: create a new file named run.sh and copy/paste the content of the command 

to it. This will make it easier for you to run the command several times ) **

Now that we created a ConfigMap  we can continue.

Next, we'll use the Ansible k8s module to leverage existing Kubernetes and 

OpenShift Resource files. Let's take the hello-go deployment example.

**Note**: We've modified the resource file slightly as we will be deploying on OpenShift.


    # cat > roles/Hello-go-role/templates/hello-go-deployment.yml.j2 << EOF
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
              image: registry.infra.local:5000/${USER}/hello-go
              ports:
              - containerPort: ${GO_PORT}
      replicas: {{ size }}
      selector:
        matchLabels:
          app: hellogo
    EOF

Update tasks file Hello-go-role/tasks/main.yml to create the hello-go deployment using the k8s module

    # cat > roles/Hello-go-role/tasks/main.yml <<EOF
    ---
    - name: set hello-go deployment to {{ state }}
      k8s:
       state: "{{ state }}"
       definition: "{{ lookup('template', 'hello-go-deployment.yml.j2') | from_yaml }}"
       namespace: project-${USER}
    EOF

Modify vars file Hello-go-role/defaults/main.yml, setting state: present by default.

    # cat >> roles/Hello-go-role/defaults/main.yml <<EOF
    ---
    state: present
    size: 1
    EOF

Note that we are working with an internal registry with authentication required.

Until now we used our config.json file (which we generated in the first exercise ) 

but OpenShift doesn’t know about that file. For that we need to create a secret for 

the registry and then link it to our OpenShift pull request.

Let’s generate a secret specific for docker-registry :

**(change the USER to your user):**

    # oc create secret generic --from-file=.dockerconfigjson=/home/$USER/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson pullsecret

And link it to our namespace pull request :

    # oc secrets link default pullsecret --for=pull

Now we can run the Playbook to deploy your hello-go on to OpenShift

    # podman run --name ose-openshift ...

And remove leftovers :

    # podman rm ose-openshift

You can see the hello-go deployment created in your namespace.

    # oc get all -n project-${USER}

Next, let's make it possible to customize the replica count for our hello-go deployment by 

adding an hellogo_replicas variable to the DeploymentConfig template and filling 

the variable value dynamically with Ansible.

Modify vars file Hello-go-role/defaults/main.yml, setting size: 2

    ---
    state: present
    size: 2

Modify the hello-go deployment definition to read replicas from the hellogo_replicas variable

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
              image: registry.infra.local:5000/${USER}/hello-go
              ports:
              - containerPort: ${GO_PORT}
      replicas: {{ size }}
      selector:
        matchLabels:
          app: hellogo

Running the Playbook again will read the variable hellogo_replicas and use the provided value 

to customize the hello-go DeploymentConfig.

    # podman run --name ose-openshift ...

Clean it up.

    # podman rm ose-openshift

After running the Playbook, the cluster will scale down one of the hello-go pods to meet the new requested replica count of 2. 

    # oc get all -n project-${USER}

#### Exposing the application

In order to expose our application we first need to create a service with a matching 

label of the application label and then a route for that service.

Now we can add a service with the matching label :

    # cat > hello-go-service.yaml << EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: hellogo-service-${USER}
    spec:
      selector:
        app: hellogo
      ports:
        - protocol: TCP
          port: ${GO_PORT}
          targetPort: ${GO_PORT}
EOF

And now the route yaml :

    # cat > hello-go-route.yaml << EOF
    apiVersion: route.openshift.io/v1
    kind: Route
    metadata:
      annotations:
        openshift.io/host.generated: "true"
      name: hellogo-service-${USER}
      namespace: project-${USER}
    spec:
      host: hellogo-service-${USER}-project-${USER}.apps.ocp4.infra.local
      port:
        targetPort: ${GO_PORT}
      to:
        kind: Service
        name: hellogo-service-${USER}
        weight: 100
      wildcardPolicy: None
    status:
      ingress:
      - conditions:
        host: hellogo-service-${USER}-project-${USER}.apps.ocp4.infra.local
        routerCanonicalHostname: apps.ocp4.infra.local
        routerName: default
        wildcardPolicy: None
    EOF

And create them :

    # oc create -f hello-go-service.yaml -f hello-go-route.yaml

Now test your deployment :

    # curl http://hellogo-service-${USER}-project-${USER}.apps.ocp4.infra.local/testing
    Hello, you requested: /testing

If everything works as expected then remove the service and the route.

    # oc delete -f hello-go-route.yaml -f hello-go-service.yaml

#### Final Task

If everything is running as expected we can delete it by changing the  ‘state’ 

var in the defaults.yaml file from present to absent. 

After changing it, run the playbook again and verify you have no pods with `oc get pods`.


