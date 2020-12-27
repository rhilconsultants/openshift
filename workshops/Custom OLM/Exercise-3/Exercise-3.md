# Adding an Operator to the OLM using the CLI

## Prerequisites

### Option 1 Copy the opm Command
If the host that you are working on is has the same OS and processor as that running OpenShift, you can copy the `opm` command from a running container:
```bash
$ mkdir -p ${HOME}/bin
$ oc -n openshift-marketplace cp $(oc get pods -n openshift-marketplace | awk '/redhat-operators/{print $1}'):/usr/bin/opm $HOME/bin/opm
$ chmod +x ${HOME}/bin/opm
```

### Option 2: build the opm Command
Build the **opm** command as follows:
```bash
$ cd /tmp
$ git clone https://github.com/operator-framework/operator-registry.git
$ cd operator-registry
$ make build
$ mkdir -p $HOME/bin
$ cp bin/opm $HOME/bin
$ export PATH=$PATH:$HOME/bin
```

## Log into OpenShift and the Image Registry
If you haven't done so, log in to OpenShift and the image registry as specified in Exercise-0.

### Change to the Operator Directory
Ensure that the USER environment variable has been set.
Change to the operator's directory:
```bash
$ cd ~/ose-openshift/${USER}-hellogo-operator
```

## Create Images
Build and push the operator to the registry as follows:
```bash
$ make docker-build docker-push IMG=${REGISTRY}/${USER}/hellogo-operator:v0.0.1
```
If the Quay registry is being used for this workshop, log in via the web UI, select the `hellogo-operator` repository, press on the gear icon on the page that opened, press the `Make Public` button and then press `OK` in the pop-up. 

## Creating a Manifest
We will now create bundle manifests by running `make bundle` in the root of the operator project.
```bash
$ make bundle IMG=${REGISTRY}/${USER}/hellogo-operator:v0.0.1
```
When prompted enter required values. Replace "Usern" with your ${USER}.

Display name for the operator (required): 
> Usern Hellogo Operator

Description for the operator (required): 
> Hellogo HTTP request server

Provider's name for the operator (required): 
> Usern

Any relevant URL for the provider name (optional): 
> 

Comma-separated list of keywords for your operator (required): 
> hellogo

Comma-separated list of maintainers and their emails (e.g. 'name1:email1, name2:email2') (required): 
> usern@devnull    


A director named `bundle` is created. The `bundle` directory includes a ClusterServiceVersion and the CRDs that define the owned APIs of the CSV. It also includes an annotations file in its metadata folder which defines some higher level aggregate data that helps to describe the format and package information about how the bundle should be added into an index of bundles.

The following is the directory structure for our project.

```
bundle
├── manifests
│   ├── hellogo.example.com_${USER}hellogoes.yaml
│   ├── project-${USER}-operator-controller-manager-metrics-service_v1_service.yaml
│   ├── project-${USER}-operator-metrics-reader_rbac.authorization.k8s.io_v1_clusterrole.yaml
│   └── ${USER}-hellogo-operator.clusterserviceversion.yaml
├── metadata
│   └── annotations.yaml
└── tests
    └── scorecard
        └── config.yaml

4 directories, 6 files
```

When loading manifests into the database, the following invariants are validated:

 * The bundle must have at least one channel defined in the annotations.
 * Every bundle has exactly one ClustferServiceVersion.
 * If a ClusterServiceVersion `owns` a CRD, that CRD must exist in the bundle.

Due to a potential change in annotation expections, edit the file `bundle/metadata/annotations.yaml`, and make a copy of the line:
```
  operators.operatorframework.io.bundle.channels.v1: alpha
```
In one copy of the line, change `channels.v1` to `channel.default.v1`.


Build the bundle and push it to the registry:
```bash
$ make bundle-build BUNDLE_IMG=${REGISTRY}/${USER}/hellogo-operator-bundle:v0.0.1
$ podman push ${REGISTRY}/${USER}/hellogo-operator-bundle:v0.0.1
```
If the Quay registry is being used for this workshop, log in via the web UI, select the `hellogo-operator-bundle` repository, press on the gear icon on the page that opened, press the `Make Public` button and then press `OK` in the pop-up. 

## Building an index of Operators using `opm`

Now that you have published the container image containing your manifests, how do you actually make the bundle available to other users' Kubernetes clusters so that the Operator Lifecycle Manager can install the operator? This is where the bulk of the `operator-registry` project comes in. OLM has the concept of [CatalogSources](https://operator-framework.github.io/olm-book/docs/glossary.html#catalogsources) which define a reference to what packages are available to install onto a cluster. To make your bundle available, you can add the bundle to a container image which the CatalogSource points to. This image contains a database of pointers to bundle images that OLM can pull and extract the manifests from in order to install an operator. So, to make your operator available to OLM, you can generate an index image via opm with your bundle reference included:
Add an index as follows:
```bash
$ opm -c podman index add --bundles ${REGISTRY}/${USER}/hellogo-operator-bundle:v0.0.1 --tag ${REGISTRY}/${USER}/registry-index:0.0.1
$ podman push ${REGISTRY}/${USER}/registry-index:0.0.1
```
If the Quay registry is being used for this workshop, log in via the web UI, select the `registry-index` repository, press on the gear icon on the page that opened, press the `Make Public` button and then press `OK` in the pop-up.

If we are using the internal OpenShift registry, we must allow the default service account in the openshift-marketplace to pull images from the ${USER} respository in the registry by running:
```bash
$ oc policy add-role-to-group system:image-puller system:serviceaccounts:openshift-marketplace --namespace=${USER}
$ oc policy add-role-to-group system:image-puller system:serviceaccounts:openshift-operators --namespace=${USER}
```

The resulting image is referred to as an "Index". It is an image which contains a database of pointers to operator manifest content that is easily queriable via an included API that is served when the container image is run.

Now that image is available for clusters to use and reference with CatalogSources on their cluster.

For more detail on using `opm` to generate index images, take a look at the [documentation](https://github.com/operator-framework/operator-registry/blob/master/docs/design/opm-tooling.md).

## Using the index with Operator Lifecycle Manager

To add an index packaged with `operator-registry` to your cluster for use with [Operator Lifecycle Manager](https://github.com/operator-framework/operator-lifecycle-manager) (OLM) create a `CatalogSource` referencing the image you created and pushed above:
```bash
$ oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${USER}-manifests
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${REGISTRY}/${USER}/registry-index:0.0.1
  publisher: ${USER^}
  displayName: ${USER^}'s Operators
EOF
```
This will download the referenced image and start a pod in the designated namespace (`openshift-marketplace`). Watch the catalog pods to verify that it/they start correctly and reach the `Running` status:

```bash
$ oc get pods -n openshift-marketplace | grep ${USER}
```

Verify that your operator is available in the catalog by running:
```bash
$ oc get packagemanifests -n openshift-marketplace | grep ${USER}
```
The output should be of the form:
```
${USER}-hellogo-operator                               ${USER^}'s Operators     48s

```
As we did in the previous exercise, we can inspect the  operator by running:
```bash
$ oc describe packagemanifests ${USER}-hellogo-operator -n openshift-marketplace
```

You can now [subscribe](https://github.com/operator-framework/operator-lifecycle-manager#discovery-catalogs-and-automated-upgrades) to Operators with Operator Lifecycle Manager. This represents an intent to install an Operator and get subsequent updates from the catalog. Note that the `channel` value should match the value that you are using in your operator build. `alpha` is the default value:
```bash
$ oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${USER}-hellogo-subscription
  namespace: openshift-operators
spec:
  channel: alpha
  name: ${USER}-hellogo-operator
  source: ${USER}-manifests
  sourceNamespace: openshift-marketplace
EOF
```
The above creates an instance of the operator in the `openshift-marketplace` namespace. Wait until all pods are running before proceeding:
```bash
$ oc get pods -n openshift-marketplace | grep ${USER}
```

## Create an Instance of the Application
Create a new project for the application:
```bash
$ oc project ${USER}-client
```
Create an instance of the application using the generated custom resource:
```bash
$ oc create -f config/samples/hellogo_v1alpha1_${USER}hellogo.yaml
```
Watch for the application to start:
```bash
$ oc get all
```
When all pods are running, get the route and test the application:
```bash
$ ROUTENAME=$(oc get routes | awk '/sample/{print $2}')
$ curl ${ROUTENAME}/testing-app-created-by-my-operator-via-OLM
```
The output should be:
```
Hello, you requested: /testing-app-created-by-my-operator-via-OLM
```
## Cleanup
### Application
Erase the application:
```bash
$ oc delete -n ${USER}-client -f config/samples/hellogo_v1alpha1_${USER}hellogo.yaml
```
### Subscription
Log back into OpenShift using your ${USER} account and erase the subscription by running:
```bash
$ oc delete -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${USER}-hellogo-subscription
  namespace: openshift-operators
EOF
```
### Cluster Service Version
Get the name of the cluster service version:
```bash
$ oc get clusterserviceversion | grep ${USER}
```
Delete the cluster service version instance using the version specified above:
```bash
$ oc delete -n openshift-operators clusterserviceversion ${USER}-hellogo-operator.v0.0.1
```
### Catalog Source
Delete the catalog source:
```bash
$ oc delete -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${USER}-manifests
  namespace: openshift-marketplace
EOF
```