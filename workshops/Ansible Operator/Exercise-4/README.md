
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
$ mkdir ${HOME}/bin
$ export ARCH=$(case $(arch) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(arch) ;; esac)
$ export OS=$(uname | awk '{print tolower($0)}')
$ export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/latest/download
$ curl -Lo ${HOME}/bin/operator-sdk ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
$ chmod a+x ${HOME}/bin/operator-sdk
```

Now make sure you are using the right operator-sdk:
```bash
$ which operator-sdk
```
The output should be:
```
 ~/bin/operator-sdk
 ```
If the output is deferent just update the PATH environment variable :
```bash
$ export PATH="${HOME}/bin:${PATH}"
$ echo 'export PATH="${HOME}/bin:${PATH}"' >> ~/.bashrc
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
$ mkdir ${USER}-hellogo-operator && cd ${USER}-hellogo-operator
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

**Note**
As a convention, when creating Ansible operators, Ansible YAML files use a `.yml` suffix whereas Kubernetes/OpenShift assets use a `.yaml` suffix.

To test the operator on OpenShift we will use a different user named `{USER}-client`.


## Building the Ansible Role

Now that the skeleton files have been created, we can take the role files from Exercise-3 and apply them using the Operator.

First let’s take the templates file from our previous exercise and change the name to: '{{ ansible_operator_meta.name }}-hellogo'
```bash
$ sed "s/hellogo-pod/\'\{\{\ ansible_operator_meta\.name\ \}\}-hellogo\'/" \
    ../roles/Hello-go-role/templates/hello-go-deployment.yml.j2 \
    > roles/${USER}hellogo/templates/hello-go-deployment.yml.j2
```
Now we will copy the task's main.yml from our previous exercise and remove the ‘state’ section as we will always want it as **present**. We will also change the namespace value to be read from the metadata so that it is not hard-coded:
```bash
$ sed -e "s/namespace:.*/namespace: \'\{\{\ ansible_operator_meta\.namespace\ \}\}\'/" \
    -e "/state:/d" ../roles/Hello-go-role/tasks/main.yml \
    > roles/${USER}hellogo/tasks/main.yml
```
The next step is to update the default values:
```bash
$ cat > roles/${USER}hellogo/defaults/main.yml <<EOF
---
state: present
size: 3
EOF
```
A well written operator will ensure that all container requirements are fulfilled. Therefore we will add a service and a route through the operator:

First copy the service to the templates directory after change the hardcoded name to a generated name:
```bash
$ sed -e "s/name:.*/name: \'\{\{\ ansible_operator_meta\.name\ \}\}-hellogo\'/" \
    -e "s/namespace:.*/namespace: \'\{\{\ ansible_operator_meta\.namespace\ \}\}\'/" \
      ../hello-go-service.yaml > roles/${USER}hellogo/templates/hello-go-service.yml.j2
```
Now copy the route after removing hardcoded values:
```bash
$ sed -e "0,/name:.*/s//name: \'\{\{\ ansible_operator_meta\.name\ \}\}-hellogo\'/" \
    -e "s/namespace:.*/namespace: \'\{\{\ ansible_operator_meta\.namespace\ \}\}\'/" \
    -e "/to:/,\$s/name:.*/name: \'\{\{\ ansible_operator_meta\.name\ \}\}-hellogo\'/" \
    ../hello-go-route.yaml > roles/${USER}hellogo/templates/hello-go-route.yml.j2
```
Add Ansible tasks that will read the `service` and `route` templates:
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
Our operator will need permission to access the service and route objects. Add the following to the first **resources** section of `config/rbac/role.yaml`:

    - services

Add the following section to the end of the `config/rbac/role.yaml` file:

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
      - apiGroups:
          - service.openshift.io
        resources:
          - services
        verbs:
          - create
          - delete
          - get
          - list
          - patch
          - update
          - watch   

## Building and Running the Operator

### Build and Push the Image
Log into OpenShift and to the image registry as instructed in Exercise-0.

The Makfile generated by the `operator-sdk` uses the "docker" command to build and push images. Sense we are Running podman and not docker we need to trick the Makefile to think it is actually running docker by linking the podman binary to our ~/bin directory and named the link "docker"
```bash
$ ln -s /usr/bin/podman ~/bin/docker
```
For this workshop, we will use the same namespace as in the previous exercises and we will expose /metrics endpoint without any authn/z:
```bash
$ sed -i -e "s/namespace:.*/namespace: project-${USER}/" \
    -e "s/namePrefix:.*/namePrefix: project-${USER}-operator-/" \
    -e "s/- manager_auth_proxy_patch.yaml/#&/" config/default/kustomization.yaml
```
The first step is to build the operator image:
```bash
$ make docker-build IMG=${REGISTRY}/project-${USER}/hellogo-operator:v0.0.1
```
In case you are hiting an error , run the following command for a fix :
```bash
$ sed -i 's/-r\ ${HOME}\/requirements.yml/-r\ ${HOME}\/requirements.yml\ --force/' Dockerfile
```

The next step is to push the operator image to the registry:
```bash
$ make docker-push IMG=${REGISTRY}/project-${USER}/hellogo-operator:v0.0.1
```
Note that the above two commands can be combined using: make docker-build docker-push IMG=...

If the Quay registry is being used for this workshop, log in via the web UI, select the `hellogo-operator` repository, press on the gear icon on the page that opened, press the `Make Public` button and then press `OK` in the pop-up. 

### Ways to Run an Operator

Once the CRD is registered, there are two ways to run the Operator:
  - As a pod inside an Openshift cluster
  - As a go program outside the cluster using operator-sdk
For the sake of this tutorial, we will run the Operator as a pod inside of a Openshift Cluster. 
If you are interested in learning more about running the Operator using operator-sdk.

### Deploy the Operator

Create a namespace ${USER}-hellogo-operator-system, create the CRC, install the RBAC configuration and create a Kubernetes Deployment by running:

(Ask the Instructor)
```bash
$ make deploy IMG=${REGISTRY}/project-${USER}/hellogo-operator:v0.0.1
```
Verify that the operator is running by checking the output of:
```bash
$ oc get all -n project-${USER}
```
The output should be of the form:

    NAME                                                               READY   STATUS    RESTARTS   AGE
    pod/${USER}-hellogo-operator-controller-manager-55bfdf7795-drwvm   1/1     Running   0          4m55s

    NAME                                                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
    service/${USER}-hellogo-operator-controller-manager-metrics-service   ClusterIP   172.25.195.190   <none>        8443/TCP   4m55s

    NAME                                                          READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/${USER}-hellogo-operator-controller-manager   1/1     1            1           4m55s

    NAME                                                                     DESIRED   CURRENT   READY   AGE
    replicaset.apps/${USER}-hellogo-operator-controller-manager-55bfdf7795   1         1         1       4m55s-

### Create RBAC Rules for the Custom Resource
By default, the `operator-sdk` generates scaffolding for an operator with `cluster` wide privileges.

Create an RBAC ClusterRole with read/write permissions for the custom resource by running:
```bash
$ oc create -f config/rbac/${USER}hellogo_editor_role.yaml
```
The ClusterRole can be assigned to individual users as follows:
```bash
$ oc adm policy add-cluster-role-to-user ${USER}hellogo-editor-role $(oc whoami)
```

**OPTIONAL** 

Alternatively, an RBAC `group` could be created with the ClusterRole permissions, and `users` can be assigned to the group. For example, create a new group named `hellogo-users`:
```bash
$ oc adm groups new hellogo-users
```
Add the ClusterRole permission to the group:
```bash
$ oc adm policy add-cluster-role-to-group ${USER}hellogo-editor-role hellogo-users
```
Add users to the group:
```bash
$ oc adm groups add-users hellogo-users user1
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

In order to instantiate 3 hellogo pods using the operator, change "foo: bar" to "size: 3":
```yaml
$ cat > config/samples/hellogo_v1alpha1_${USER}hellogo.yaml << EOF
apiVersion: hellogo.example.com/v1alpha1
kind: ${USER^}hellogo
metadata:
  name: ${USER}hellogo-sample
spec:
  size: 3
EOF
```
### Image Permission

**NOTE**
This section is only relevant if you are building a cluster scope Operator , for namespace scope you can skip this step

If we are using the internal OpenShift registry, we must allow the default service account in the project that we will use to pull images from the ${USER} repository in the registry by running:
```bash
$ oc project ${USER}-client
$ oc policy add-role-to-group system:image-puller system:serviceaccounts:${USER}-client --namespace=${USER}
```

Log in to OpenShift with the ${USER}-client:
```bash
$ oc login --username user<user number +30> --password '...' api.$OCP_CLUSTER.$OCP_DOMAIN:6443
```
Create a new project for our testing:
```bash
$ oc project ${USER}-client
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
Verify that the route was created:
```bash
$ oc get routes
```
The output should be of the form:
```
NAME                          HOST/PORT                                                   PATH   SERVICES                      PORT   TERMINATION   WILDCARD
${USER}hellogo-sample-hellogo   ${USER}hellogo-sample-hellogo-${USER}-client.apps-crc.testing          ${USER}hellogo-sample-hellogo   8080                 None
```
Test your hello-go application with the newly created route:
```bash
$ curl $(oc get routes | awk '/hellog/{print $2}')/testing-app-created-by-my-operator
```
The output should be:
```
Hello, you requested: /testing-app-created-by-my-operator
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

Log in to OpenShift as ${USER} and delete the operator using:
```bash
$ make undeploy
```
Finally, verify that the operator is no longer running.
```bash 
$ oc get deployment
```

That is it, you are all done !!!
