# Exercise 4 - Ansible K8S Module

## Contents

* Running Ansible with Kubernetes
  * Exposing the Application
  * Testing the Deployment
  * Final Task
  * Cleanup


## Running Ansible with Kubernetes

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
          image: image-registry.openshift-image-registry.svc:5000/project-${USER}/hello-go
          ports:
          - containerPort: 8080
  replicas: 1
  selector:
    matchLabels:
      app: hellogo
EOF
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

NAME                                      IMAGE REPOSITORY                                                                 TAGS     UPDATED
imagestream.image.openshift.io/hello-go   default-route-openshift-image-registry.apps-crc.testing/project-${USER}/hello-go   latest   2 minutes ago

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
          image: image-registry.openshift-image-registry.svc:5000/project-${USER}/hello-go
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