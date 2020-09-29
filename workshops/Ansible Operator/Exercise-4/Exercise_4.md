
# Biulding an Operator

## Contents
  - Operator-SDK
    - Download UBI Image
    - Operator-sdk
  - Download the release binary
  - (Optional) - Verify the downloaded release binary
  - Install the release binary in your PATH
  - Removing the unneeded Role
  - Build and run the Operator
  - Ways to Run an Operator
  - Building
  - Modifying the Operator deploy manifest
  - Creating the Operator
  - Custom Variables
  - Accessing CR Fields
  - Removing Hellogo from the cluster
  - Head First
    - Task 1
    - Task 2 (Optional)
  - UBI Container with operator-sdk

## Operator-SDK
Until now we worked with containers , Ansible and the Ansible module for Kubernetes , now it’s time to bring it all together 

### Download UBI Image

First let’s make sure we have the UBI image (we know what it is now)

    # podman pull registry.infra.local:5000/ubi8/ubi-minimal

### Operator-sdk

#### Download the release binary

Set the release version variable:

    # export RELEASE_VERSION=v0.17.0

Now download the GNU binary

    # curl -LO https://github.com/operator-framework/operator-sdk/releases/download/${RELEASE_VERSION}/operator-sdk-${RELEASE_VERSION}-x86_64-linux-gnu

#### (Optional) - Verify the downloaded release binary

    #  curl -LO https://github.com/operator-framework/operator-sdk/releases/download/${RELEASE_VERSION}/operator-sdk-${RELEASE_VERSION}-x86_64-linux-gnu.asc

To verify a release binary using the provided asc files, place the binary and corresponding asc file into the same directory and use the corresponding command:

    #  gpg --verify operator-sdk-${RELEASE_VERSION}-x86_64-linux-gnu.asc

If you do not have the maintainers public key on your machine, you will get an error message similar to this:

    # gpg --verify operator-sdk-${RELEASE_VERSION}-x86_64-apple-darwin.asc
    gpg: assuming signed data in 'operator-sdk-${RELEASE_VERSION}-x86_64-apple-darwin'
    gpg: Signature made Fri Apr  5 20:03:22 2019 CEST
    gpg:                using RSA key <KEY_ID>
    gpg: Can't check signature: No public key

To download the key, use the following command, replacing $KEY_ID with the RSA key string provided in the output of the previous command: 
    #  gpg --recv-key "$KEY_ID"

You’ll need to specify a key server if one hasn’t been configured. For example: 

    #  gpg --keyserver keyserver.ubuntu.com --recv-key "$KEY_ID"

Now you should be able to verify the binary.

### Install the release binary in your PATH
    
    # chmod +x operator-sdk-${RELEASE_VERSION}-x86_64-linux-gnu 
    # mkdir -p ${HOME}/bin
    # cp operator-sdk-${RELEASE_VERSION}-x86_64-linux-gnu $HOME/bin/operator-sdk 
    # rm -f operator-sdk-${RELEASE_VERSION}-x86_64-linux-gnu

Now make sure you are using the right operator-sdk:

    # which operator-sdk
    /home/${USER}/bin/operator-sdk

### (Optional) Build a container with operator-sdk

Now that we have the binary and the image let’s bring them together and work from the pod
TIP
(Make the POD running first , then connect to the pod)
………….
(working within a pod will help us …)

## WorkFlow

The SDK provides workflows to develop operators in Go, Ansible, or Helm. In this tutorial we will be focusing on Ansible.
The following workflow is for a new Ansible operator:

  - Create a new operator project using the SDK Command Line Interface(CLI)
  - Write the reconciling logic for your object using ansible playbooks and roles
  - Use the SDK CLI to build and generate the operator deployment manifests
  - Optionally add additional CRD’s using the SDK CLI and repeat steps 2 and 3

First lets create a project with our new tool We’ll be building a Hello-go Ansible Operator for the remainder of this tutorial :
(Change the user in both places to your username)

    # cd ~/ose-openshift
    # operator-sdk new ${USER}-hellogo-operator --type=ansible \
    --api-version=hellogo.example.com/v1alpha1 --kind=${USER^}hellogo

Now let’s look at the TREE of our new object :


    # tree ${USER}-hellogo-operator
    ${USER}-memcached-operator
    ├── build
    │   ├── Dockerfile
    │   └── test-framework
    │       ├── ansible-test.sh
    │       └── Dockerfile
    ├── deploy
    │   ├── crds
    │   │   ├── cache_v1alpha1_memcached_crd.yaml
    │   │   └── cache_v1alpha1_memcached_cr.yaml
    │   ├── operator.yaml
    │   ├── role_binding.yaml
    │   ├── role.yaml
    │   └── service_account.yaml
    ├── molecule
    │   ├── default
    │   │   ├── asserts.yml
    │   │   ├── molecule.yml
    │   │   ├── playbook.yml
    │   │   └── prepare.yml
    │   ├── test-cluster
    │   │   ├── molecule.yml
    │   │   └── playbook.yml
    │   └── test-local
    │       ├── molecule.yml
    │       ├── playbook.yml
    │       └── prepare.yml
    ├── roles
    │   └── memcached
    │       ├── defaults
    │       │   └── main.yml
    │       ├── files
    │       ├── handlers
    │       │   └── main.yml
    │       ├── meta
    │       │   └── main.yml
    │       ├── README.md
    │       ├── tasks
    │       │   └── main.yml
    │       ├── templates
    │       └── vars
    │           └── main.yml
    └── watches.yaml
17 directories, 25 files

Now let’s change the directory :

    # cd ${USER}-hellogo-operator

To test the operator we will use another user named {USER}-client on OpenShift in order to test our deployment by consuming the hello-go service from it and not through the ansible playbook.


## Building the Ansible Role

Now that the Skeleton is set we can take the role from Exercise number 3 and apply if through the Operator.

First let’s take the templates  file from our previous exercise:And change the name to : '{{ meta.name }}-hellogo'

    # cat ~/ose-openshift/roles/Hello-go-role/templates/hello-go-deployment.yml.j2 \
    | sed "s/hellogo-pod/\'\{\{\ meta\.name\ \}\}-hellogo\'/"\
     > roles/${USER}hellogo/templates/hello-go-deployment.yml.j2

Now we can copy the tasks main.yml from our previous exercise and remove the ‘state’s section sense we will always want it as present and change the namespace to be read from the metadata and not pre defined  :

    # cat ~/ose-openshift/roles/Hello-go-role/tasks/main.yml \
    | sed "s/project-${USER}/\'\{\{\ meta\.namespace\ \}\}\'/" \
    | grep -v 'state:' > roles/${USER}hellogo/tasks/main.yml

Update the defaults main.yml file :

For the last act we would want to update the default:

    # cat > roles/${USER}hellogo/defaults/main.yml << EOF
    ---
    # defaults file for ${USER}hellogo
    state: present
    size: 3
    EOF

In order to provide a good operator we need to make sure we are taking care of all the aspects which means , adding a service and a route through the operator :

First copy the service to the templates directory :

    # cp ~/ose-openshift/hello-go-service.yaml roles/${USER}hellogo/templates/hello-go-service.yml.j2

And the route :

    # cp ~/ose-openshift/hello-go-route.yaml roles/${USER}hellogo/templates/hello-go-route.yml.j2

Now let’s make sure that the task main is reading from those templates as well :

    # cat >> roles/${USER}hellogo/tasks/main.yml  << EOF

    - name: set hello-go service
      k8s:
        definition: "{{ lookup('template', 'hello-go-service.yml.j2') | from_yaml }}"
        namespace:  '{{ meta.namespace }}'

    - name: set hello-go route
      k8s:
        definition: "{{ lookup('template', 'hello-go-route.yml.j2') | from_yaml }}"
        namespace:  '{{ meta.namespace }}'
    EOF

## Build and run the Operator

Before running the Operator, Kubernetes needs to know about the new custom resource definition 
the Operator will be watching, by running the following command 

#### Stage 1 **(As A Cluster Admin)**

    # oc create -f deploy/crds/hellogo.example.com_${USER}hellogos_crd.yaml

By running this command, we are creating a new resource type, ${USER}hellogo, on the cluster. 
We will give our Operator work to do by creating and modifying resources of this type.
But before regular users will be able to create a CR of the type of your CRD we need to allow 
them to do so by creating the following file:
As $USER


    # cat > deploy/custom-clusterRole.yaml  << EOF
    kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: aggregate-${USER}-hellogo-admin-edit
      labels:
        rbac.authorization.k8s.io/aggregate-to-admin: "true"
        rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rules:
    - apiGroups: ["hellogo.example.com"]
      resources: ["${USER}hellogos"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete", "deletecollection"]
    ---
    kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: aggregate-${USER}-hellogo-view
      labels:
        rbac.authorization.k8s.io/aggregate-to-view: "true"
    rules:
    - apiGroups: ["hellogo.example.com"]
      resources: ["${USER}hellogos"]
      verbs: ["get", "list", "watch"]
    EOF

### Ways to Run an Operator

Once the CRD is registered, there are two ways to run the Operator:
  - As a pod inside an Openshift cluster
  - As a go program outside the cluster using operator-sdk
For the sake of this tutorial, we will run the Operator as a pod inside of a Openshift Cluster. 
If you are interested in learning more about running the Operator using operator-sdk.

### Building

Running as a pod inside a Openshift cluster is preferred for production use.
Let’s build the hellogo-operator image:

    # operator-sdk build ${USER}-hellogo-operator:v0.0.1 --image-builder buildah

As you can see I am using “buildah” as a container builder so we need to make sure the buildah 
packages and the podman package are already installed.

Now retag and push the new image to our registry:

    # podman tag  localhost/${USER}-hellogo-operator:v0.0.1 \
    registry.infra.local:5000/${USER}/hellogo-operator:v0.0.1

And Push:

    # podman push registry.infra.local:5000/${USER}/hellogo-operator:v0.0.1

#### Modifying the Operator deploy manifest

Kubernetes deployment manifests are generated by ‘operator-sdk new’ in deploy/operator.yaml. 
We need to change the image placeholder 'REPLACE_IMAGE' to the previously-built image.

    apiVersion: apps/v1
    kind: Deployment
    metadata:
     name: ${USER}-hellogo-operator
    spec:
    # [...]
         Containers:
           - name: ${USER}-hellogo-operator
             # Replace 'REPLACE_IMAGE' with the built image name
             image: REPLACE_IMAGE
             imagePullPolicy: Always
    # [...]

The commands below will change the Deployment ‘image’.

    # sed -i  "s|\"REPLACE_IMAGE\"|registry.infra.local:5000/$USER/hellogo-operator:v0.0.1|g" deploy/operator.yaml

### Creating the Operator from deploy manifests

Now, we are ready to deploy the memcached-operator:

    # oc create -f deploy/service_account.yaml

#### Stage 2 **(As Cluster Admin)**

Create the custom cluster Role

    # oc create -f deploy/custom-clusterRole.yaml 

Create OpenShift Role specifying Operator Permissions

    # oc create -f deploy/role.yaml -n project-${USER} (change user to the requesting user)

Create OpenShift Role Binding assigning Permissions to Service Account

    # oc create -f deploy/role_binding.yaml -n project-${USER} (change user to the requesting user)

#### Stage 3 **(As A normal USER)**

Add a service account permissions:

    # oc adm policy add-role-to-user admin system:serviceaccount:project-${USER}:${USER}-hellogo-operator

Attach the pull secret to your newly created service account:

    # oc secrets link ${USER}-hellogo-operator pullsecret --for=pull

Follow the pods startup in the background:

    # oc get pods -w &

Create Operator Deployment Object

    # oc create -f deploy/operator.yaml

In your terminal you should see the following output :

    ${USER}-hellogo-operator-f9b84b855-d6chs   0/1     Pending       0          0s
    ${USER}-hellogo-operator-f9b84b855-d6chs   0/1     ContainerCreating   0          0s
    ${USER}-hellogo-operator-f9b84b855-d6chs   0/1     ContainerCreating   0          3s
    ${USER}-hellogo-operator-f9b84b855-d6chs   1/1     Running             0          4s

Another way to Verify that the hellogo-operator is running is by viewing the deployment:

    # oc get deployment
    NAME                DESIRED CURRENT UP-TO-DATE AVAILABLE AGE
    ${USER}-hellogo-operator  1       1       1          1         1m

Once the operator is running your are good to go and you can continue with testing it in another namespace 

### Using the Operator

Now that we have deployed our Operator, let’s create a CR and 3 instances of our hellogo application with our client user.
First login to openshift with the ${USER}-client :

    # oc login --username ${USER}-client --password 'OcpPa$$w0rd'

There is a sample CR in the scaffolding created as part of the Operator SDK:

    apiVersion: hellogo.example.com/v1alpha1
    kind: ${USER}hellogo
    metadata:
      name: example-${USER}hellogo
    spec:
      # Add fields here
      size: 3

Let’s go ahead and apply this in our Tutorial project to deploy 3  hellogo pods, using our Operator:

    # cat deploy/crds/hellogo.example.com_v1alpha1_${USER}hellogo_cr.yaml
    apiVersion: cache.example.com/v1alpha1
    kind: ${USER}hellogo
    metadata:
      name: example-${USER}hellogo
    spec:
      size: 3

Now run the the “oc create” command to create the proper CR:

    # oc create -f deploy/crds/hellogo.example.com_v1alpha1_${USER}hellogo_cr.yaml

Ensure that the hellogo-operator creates the deployment for the CR:

    # oc get deployment
    NAME                 DESIRED CURRENT UP-TO-DATE AVAILABLE AGE
    example-${USER}-hellogo    3       3       3          3         1m

#### STOP !!!

Nothing is happening right ?

Well this could be a result of us not configuration the watches.yaml file correctly.

go back to your old user 

    # oc login --username ${USER} --password 'OcpPa$$w0rd'

Let's edit the watches.yaml again with the option of 'watchClusterScopedResources' set the true "False by default"

    # vi watches.yaml
    ---
    - version: v1alpha1
      group: hellogo.example.com
      kind: ${USER^}hellogo
      role: ${USER}hellogo
      watchClusterScopedResources: true
      reconcilePeriod: 5m

once you have updated the watches.yaml file rebuild the operator :

    # operator-sdk build ${USER}-hellogo-operator:v0.0.1 --image-builder buildah

Tag amd push the new image :

    # podman tag  localhost/${USER}-hellogo-operator:v0.0.1 \
    registry.infra.local:5000/${USER}/hellogo-operator:v0.0.1

    # podman push registry.infra.local:5000/${USER}/hellogo-operator:v0.0.1

for best practice , delete and recreate the deploymnet.yaml

    # oc delete -f deploy/operator.yaml

And

    # oc create -f deploy/operator.yaml

Switch back to the ${USER}-client

    # oc login --username ${USER}-client --password 'OcpPa$$w0rd'

and run check the pods to see if they are now been created (we have not delete the CR which means it is still active
and waiting for actions from the cluster

Once the deployment is completed we can move on to the testing part

### TESTING

Test your hello-go with the new created route:

    # curl http://hellogo-service-${USER}-project-${USER}.apps.ocp4.infra.local
    Hello, you requested: /

## Custom Variables

To pass ‘extra vars’ to the Playbooks/Roles being run by the Operator, you can embed 
key-value pairs in the ‘spec’ section of the Custom Resource (CR).

This is equivalent to how — extra-vars can be passed into the ansible-playbook command.

The CR snippet below shows two ‘extra vars’ (message and newParamater) being passed in via spec. 

Passing 'extra vars' through the CR allows for customization of Ansible logic based on the contents of each CR instance.
## Sample CR definition where some

In most cases you would like to extend your CRD in order to allow customers to add more custom values to there request.

#### 'extra vars' are passed via the spec

    apiVersion: "app.example.com/v1alpha1"
    kind: "Database"
    metadata:
      name: "example"
    spec:
      message: "Hello world 2"
      newParameter: "newParam"

### Accessing CR Fields

Now that you’ve passed ‘extra vars’ to your Playbook through the CR spec, we need to read 
them from the Ansible logic that makes up your Operator.

Variables passed in through the CR spec are made available at the top-level to be read from Jinja templates. 

For the CR example above, we could read the vars ‘message’ and ‘newParameter’ from a Playbook like so:

    - debug:       
      msg: "message value from CR spec: {{ message }}"

    - debug:
      msg: "newParameter value from CR spec: {{ new_parameter }}"

Did you notice anything strange about the snippet above? The ‘newParameter’ variable that we set on our CR spec 
was accessed as ‘new_parameter’. 

Keep this automatic conversion from camelCase to snake_case in mind, as it will happen to all ‘extra vars’ passed into the CR spec.

## Removing hellogo from the cluster

First, delete the 'memcached' CR, which will remove the 4 Memcached pods and the associated deployment.

    # oc delete -f deploy/crds/hellogo.example.com_v1alpha1_${USER}hellogo_cr.yaml

Now let's look at the pods 


    # oc get pods

Then, delete the memcached-operator deployment.

    # oc delete -f deploy/operator.yaml

Finally, verify that the memcached-operator is no longer running.
    
    # oc get deployment

Ask the Cluster Admin to run :

    # oc delete -f deploy/role_binding.yaml
    # oc delete -f deploy/role.yaml
    # oc delete -f deploy/service_account.yaml
    # oc delete -f deploy/crds/cache_v1alpha1_memcached_crd.yaml

### Extra Tasts 

  - Update our hello-go code to use mariadb database and update our operator with mariadb dependency 

That is it, you are all done !!!
