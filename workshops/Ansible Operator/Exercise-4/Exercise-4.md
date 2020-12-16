
# Excercise 4 - Building an Operator

## Contents

* Operator-SDK
  * Download the Operator-SDK Binary
* WorkFlow
* Creating an Operator
* Building the Ansible Role
* Building and Running the Operator
  * Build and Push the Image
  * Install the CRD
  * Ways to Run an Operator
  * Deploy the Operator
* Using the Operator
* Testing
* Custom Variables
  * 'extra vars' are passed via the spec
  * Accessing CR Fields
* Removing hellogo from the Cluster
  * Delete CRs
  * Delete the Operator
* Extra Tasks

## Operator-SDK
Until now we worked with containers, Ansible and the Ansible module for Kubernetes (k8s). Now it’s time to bring it all together.

### Download the Operator-SDK Binary
#### Download from the Workshop Repository
```bash
$ mkdir -p ${HOME}/bin
$ cp /usr/share/workshop/operator-sdk* ${HOME}/bin/operator-sdk
$ chmod +x ${HOME}/bin/operator-sdk
```
#### Alternative - Download From the Web
If your instructor did not download the operator-sdk to /usr/share/workshop/ you can download the binary from the Internet:
```bash
$ mkdir -p ${HOME}/bin
$ export RELEASE_VERSION=v1.2.0
$ curl -L -o operator-sdk https://github.com/operator-framework/operator-sdk/releases/download/${RELEASE_VERSION}/operator-sdk-${RELEASE_VERSION}-x86_64-linux-gnu
$ chmod +x ${HOME}/bin/operator-sdk
```

Now make sure you are using the right operator-sdk:
```bash
$ which operator-sdk
```
The output should be:
```
 ~/bin/operator-sdk
 ```

## WorkFlow

The SDK provides workflows to develop operators in Go, Ansible, or Helm. In this tutorial we will be focusing on Ansible.
The following workflow is for a new Ansible operator:

  - Create a new operator project using the SDK Command Line Interface (CLI)
  - Write the reconciling logic for your object using Ansible playbooks and roles
  - Use the SDK CLI to build and generate the operator deployment manifests
  - Optionally add additional CRD’s using the SDK CLI and repeat steps 2 and 3

## Creating an Operator
First lets create a project with our new tool. We’ll be building a Hello-go Ansible Operator for the remainder of this tutorial:
```bash
$ cd ~/ose-openshift
$ mkdir ${USER}-hellogo-operator
$ cd ${USER}-hellogo-operator
$ operator-sdk init --plugins=ansible --domain=example.com
$ operator-sdk create api --group hellogo --version=v1alpha1 --kind=${USER^}hellogo --generate-role
```
Now let’s look at the directory structure of our new object:

    $ tree
    .
    ├── config
    │   ├── crd
    │   │   ├── bases
    │   │   │   └── hellogo.example.com_${USER}hellogoes.yaml
    │   │   └── kustomization.yaml
    │   ├── default
    │   │   ├── kustomization.yaml
    │   │   └── manager_auth_proxy_patch.yaml
    │   ├── manager
    │   │   ├── kustomization.yaml
    │   │   └── manager.yaml
    │   ├── prometheus
    │   │   ├── kustomization.yaml
    │   │   └── monitor.yaml
    │   ├── rbac
    │   │   ├── auth_proxy_client_clusterrole.yaml
    │   │   ├── auth_proxy_role_binding.yaml
    │   │   ├── auth_proxy_role.yaml
    │   │   ├── auth_proxy_service.yaml
    │   │   ├── kustomization.yaml
    │   │   ├── leader_election_role_binding.yaml
    │   │   ├── leader_election_role.yaml
    │   │   ├── ${USER}hellogo_editor_role.yaml
    │   │   ├── ${USER}hellogo_viewer_role.yaml
    │   │   ├── role_binding.yaml
    │   │   └── role.yaml
    │   ├── samples
    │   │   ├── hellogo_v1alpha1_${USER}hellogo.yaml
    │   │   └── kustomization.yaml
    │   ├── scorecard
    │   │   ├── bases
    │   │   │   └── config.yaml
    │   │   ├── kustomization.yaml
    │   │   └── patches
    │   │       ├── basic.config.yaml
    │   │       └── olm.config.yaml
    │   └── testing
    │       ├── debug_logs_patch.yaml
    │       ├── kustomization.yaml
    │       ├── manager_image.yaml
    │       └── pull_policy
    │           ├── Always.yaml
    │           ├── IfNotPresent.yaml
    │           └── Never.yaml
    ├── Dockerfile
    ├── Makefile
    ├── molecule
    │   ├── default
    │   │   ├── converge.yml
    │   │   ├── create.yml
    │   │   ├── destroy.yml
    │   │   ├── kustomize.yml
    │   │   ├── molecule.yml
    │   │   ├── prepare.yml
    │   │   ├── tasks
    │   │   │   └── ${USER}hellogo_test.yml
    │   │   └── verify.yml
    │   └── kind
    │       ├── converge.yml
    │       ├── create.yml
    │       ├── destroy.yml
    │       └── molecule.yml
    ├── playbooks
    ├── PROJECT
    ├── requirements.yml
    ├── roles
    │   └── ${USER}hellogo
    │       ├── defaults
    │       │   └── main.yml
    │       ├── files
    │       ├── handlers
    │       │   └── main.yml
    │       ├── meta
    │       │   └── main.yml
    │       ├── README.md
    │       ├── tasks
    │       │   └── main.yml
    │       ├── templates
    │       └── vars
    │           └── main.yml
    └── watches.yaml
    
    27 directories, 54 files

Note: as a convention, when creating Ansible operators, Ansible YAML files use a `.yml` suffix whereas Kubernetes/OpenShift assets use a `.yaml` suffix.

To test the operator we will use another user named {USER}-client on OpenShift in order to test our deployment by consuming the hello-go service from it and not through the Ansible playbook.


## Building the Ansible Role

Now that the skeleton files have been created, we can take the role from Exercise number 3 and apply if through the Operator.

First let’s take the templates file from our previous exercise and change the name to: '{{ ansible_operator_meta.name }}-hellogo'
```bash
$ sed "s/hellogo-pod/\'\{\{\ ansible_operator_meta\.name\ \}\}-hellogo\'/" \
    ~/ose-openshift/roles/Hello-go-role/templates/hello-go-deployment.yml.j2 \
    > roles/${USER}hellogo/templates/hello-go-deployment.yml.j2
```
Now we will copy the task's main.yml from our previous exercise and remove the ‘state’ section as we will always want it as **present**. We will also change the namespace value to be read from the metadata so that it is not hard-coded:
```bash
$ sed -e "s/namespace:.*/namespace: \'\{\{\ ansible_operator_meta\.namespace\ \}\}\'/" \
    -e "/state:/d" ~/ose-openshift.bad/roles/Hello-go-role/tasks/main.yml \
    > roles/${USER}hellogo/tasks/main.yml
```
The next step is to update the default values:
```bash
$ cat > roles/${USER}hellogo/defaults/main.yml <<EOF
---
# defaults file for ${USER}hellogo
state: present
size: 3
EOF
```
A well written operator will ensure that all container requirements are fulfilled. Therefore we will add a service and a route through the operator:

First copy the service to the templates directory after change the hardcoded name to a generated name:
```bash
$ sed -e "s/name:.*/name: \'\{\{\ ansible_operator_meta\.name\ \}\}-hellogo\'/" \
    -e "s/namespace:.*/namespace: \'\{\{\ ansible_operator_meta\.namespace\ \}\}\'/" \
      ~/ose-openshift/hello-go-service.yaml > roles/${USER}hellogo/templates/hello-go-service.yml.j2
```
Now copy the route after removing hardcoded values:
```bash
$ sed -e "0,/name:.*/s//name: \'\{\{\ ansible_operator_meta\.name\ \}\}-hellogo\'/" \
    -e "s/namespace:.*/namespace: \'\{\{\ ansible_operator_meta\.namespace\ \}\}\'/" \
    -e "/to:/,\$s/name:.*/name: \'\{\{\ ansible_operator_meta\.name\ \}\}-hellogo\'/" \
    ~/ose-openshift/hello-go-route.yaml > roles/${USER}hellogo/templates/hello-go-route.yml.j2
```
Add an Ansible tasks that will read these templates:
```yaml
$ cat >> roles/${USER}hellogo/tasks/main.yml  <<EOF
- name: set hello-go service
  k8s:
    definition: "{{ lookup('template', 'hello-go-service.yml.j2') | from_yaml }}"
    namespace:  '{{ ansible_operator_meta.namespace }}'

- name: set hello-go route
  k8s:
    definition: "{{ lookup('template', 'hello-go-route.yml.j2') | from_yaml }}"
    namespace:  '{{ ansible_operator_meta.namespace }}'
EOF
```
In addition, our operator will need permission to access the service and route objects. Add the following to the first **resources** section of `config/rbac/role.yaml`:

    - services

Add the following section to the end of the `config/rbac/role.yaml`:

      - apiGroups:
          - route.openshift.io
        resources:
          - routes
        verbs:
          - create
          - delete
          - get
          - list
          - patch
          - update
          - watch

## Building and Running the Operator
### Log in to OpenShift
Log into OpenShift (if you have not already done so):
```bash
$ oc login api.$OCP_CLUSTER.$OCP_DOMAIN:6443
```
Create an environment variable pointing to the OpenShift registry:
```bash
$ REGISTRY="$(oc get route/default-route -n openshift-image-registry -o=jsonpath='{.spec.host}')"
```
Log in to the local registry:
```bash
podman login -u unused -p $(oc whoami -t) ${REGISTRY}
```

### Build and Push the Image

The generated Makfiles uses the "docker" command to build and push images. We will change the build to use the "podman" command, but will not change the Makefile target names:
```bash
$ sed -i "s/docker /podman /g" Makefile
```
For this workshop, we will use the same namespace as in the previous exercises:
```bash
$ sed -i "s/namespace:.*/namespace: project-${USER}/" config/default/kustomization.yaml
```
The first step is to build the operator image:
```bash
$ make docker-build IMG=${REGISTRY}/project-${USER}/hellogo-operator:v0.0.1
```
The next step is to push the operator image to the registry:
```bash
$ make docker-push IMG=${REGISTRY}/project-${USER}/hellogo-operator:v0.0.1
```
Note that the above two commands can be combined using: make docker-build docker-push IMG=...

### Install the CRD

Before running the operator, OpenShift needs to know about the new custom resource definition 
that the operator will be watching, by running the following command:
```bash
$ make install
```
### Ways to Run an Operator

Once the CRD is registered, there are two ways to run the Operator:
  - As a pod inside an Openshift cluster
  - As a go program outside the cluster using operator-sdk
For the sake of this tutorial, we will run the Operator as a pod inside of a Openshift Cluster. 
If you are interested in learning more about running the Operator using operator-sdk.

### Deploy the Operator

Create a namespace ${USER}-hellogo-operator-system, install the RBAC configuration and create a Kubernetes Deployment (for this workshop: using the OpenShift internal name of our image) by running:
```bash
$ make deploy IMG=image-registry.openshift-image-registry.svc:5000/project-${USER}/hellogo-operator:v0.0.1
```
Verify that the operator is running by checking the output of:
```bash
$ oc get all -n project-${USER}
```
The output should be of the form:

    NAME                                                               READY   STATUS    RESTARTS   AGE
    pod/${USER}-hellogo-operator-controller-manager-55bfdf7795-drwvm   2/2     Running   0          4m55s

    NAME                                                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
    service/${USER}-hellogo-operator-controller-manager-metrics-service   ClusterIP   172.25.195.190   <none>        8443/TCP   4m55s

    NAME                                                          READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/${USER}-hellogo-operator-controller-manager   1/1     1            1           4m55s

    NAME                                                                     DESIRED   CURRENT   READY   AGE
    replicaset.apps/${USER}-hellogo-operator-controller-manager-55bfdf7795   1         1         1       4m55s-

### Create RBAC Rules for the Custom Resource
Create a read/write RBAC role for the custom resource by running:
```bash
$ oc create -f config/rbac/{USER}hellogo_editor_role.yaml
```
Allow a user to access the RBAC role:
```bash
$ oc adm policy add-cluster-role-to-user ${USER}hellogo-editor-role ${USER}-client
```

## Using the Operator

Now that we have deployed our operator, let’s create a CR and 3 instances of our hellogo application with our client user.

There is a sample CR in the scaffolding created as part of the Operator SDK config/samples/hellogo_v1alpha1_${USER}hellogo.yaml:
```yaml
apiVersion: hellogo.example.com/v1alpha1
kind: ${USER^}hellogo
metadata:
  name: ${USER}hellogo-sample
spec:
  foo: bar
````
Change "foo: bar" to "size: 3" and we will deploy 3 hellogo pods, using our operator:
```yaml
$ cat config/samples/hellogo_v1alpha1_${USER}hellogo.yaml
apiVersion: hellogo.example.com/v1alpha1
kind: ${USER^}hellogo
metadata:
  name: ${USER}hellogo-sample
spec:
  size: 3
```
First login to OpenShift with the ${USER}-client:
```bash
$ oc login --username ${USER}-client --password 'OcpPa$$w0rd' api.$OCP_CLUSTER.$OCP_DOMAIN:6443
```
Create a new project for our testing:
```bash
$ oc new-project ${USER}-client
```
Because we are using the internal OpenShift registry, we need to allow access to the hello-go image from the new project:
```bash
$ oc adm policy add-role-to-user system:image-puller system:serviceaccount:${USER}-client:default --namespace=project-${USER}
```
Now run use the “oc create” command to create the proper CR:
```bash
$ oc create -f config/samples/hellogo_v1alpha1_${USER}hellogo.yaml
```
Ensure that the hellogo-operator creates the deployment for the CR:
```bash
$ oc get deployment
```
The output should be:
```
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
${USER}hellogo-sample-hellogo   3/3     3            3           43s
```
## TESTING

Test your hello-go application with the newly created route:
```bash
$ curl $(oc get routes | awk '/hellog/{print $2}')/testing
```
The output should be:
```
Hello, you requested: /testing
```
## Custom Variables

To pass ‘extra vars’ to the Playbooks/Roles being run by the Operator, you can embed 
key-value pairs in the ‘spec’ section of the Custom Resource (CR).

This is equivalent to how — extra-vars can be passed into the ansible-playbook command.

The CR snippet below shows two ‘extra vars’ (message and newParamater) being passed in via spec. 

Passing 'extra vars' through the CR allows for customization of Ansible logic based on the contents of each CR instance.

### 'extra vars' are passed via the spec
```yaml
apiVersion: "app.example.com/v1alpha1"
kind: "Database"
metadata:
  name: "example"
spec:
  message: "Hello world 2"
  newParameter: "newParam"
```
### Accessing CR Fields

Now that you’ve passed ‘extra vars’ to your Playbook through the CR spec, we need to read 
them from the Ansible logic that makes up your Operator.

Variables passed in through the CR spec are made available at the top-level to be read from Jinja templates. 

For the CR example above, we could read the vars ‘message’ and ‘newParameter’ from a Playbook like so:
```yaml
- debug:       
  msg: "message value from CR spec: {{ message }}"

- debug:
  msg: "newParameter value from CR spec: {{ new_parameter }}"
```
Did you notice anything strange about the snippet above? The ‘newParameter’ variable that we set on our CR spec 
was accessed as ‘new_parameter’. 

Keep this automatic conversion from camelCase to snake_case in mind, as it will happen to all ‘extra vars’ passed into the CR spec.

## Removing hellogo from the Cluster

### Delete CRs
First, delete the CR, which will remove the all the pods and the associated deployment. The following can be run by the user that created the CR:
```bash
$ oc delete -f config/samples/hellogo_v1alpha1_${USER}hellogo.yaml
```
The pods will terminate and disappear.

### Delete the Operator

Log in as a cluster administrator and delete the operator using:
```bash
$ make undeploy
```
Finally, verify that the operator is no longer running.
```bash 
$ oc get deployment
```
## Extra Tasks 

  - Update our hello-go code to use mariadb database and update our operator with mariadb dependency 

That is it, you are all done !!!
