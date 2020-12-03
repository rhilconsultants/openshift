# Adding an Operator to the OLM using the CLI

## Prerequisites

### Install the opm Command
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

### Change to the Operator Directory
Ensure that the USER environment variable has been set.
Change to the operator's directory:
```bash
$ cd ~/ose-openshift/${USER}-hellogo-operator
```

## Create Images
Build and push the operator to the registry as follows:
```bash
$ make docker-build docker-push IMG=registry.infra.local:5000/${USER}/hellogo-operator:v0.0.1
```

## Creating a Manifest
We refer to a directory of files with one ClusterServiceVersion as a "bundle". A bundle typically includes a ClusterServiceVersion and the CRDs that define the owned APIs of the CSV in its manifest directory, though additional objects may be included. It also includes an annotations file in its metadata folder which defines some higher level aggregate data that helps to describe the format and package information about how the bundle should be added into an index of bundles.

```
 # example bundle
 etcd
 ├── manifests
 │   ├── etcdcluster.crd.yaml
 │   └── etcdoperator.clusterserviceversion.yaml
 └── metadata
     └── annotations.yaml
```

When loading manifests into the database, the following invariants are validated:

 * The bundle must have at least one channel defined in the annotations.
 * Every bundle has exactly one ClusterServiceVersion.
 * If a ClusterServiceVersion `owns` a CRD, that CRD must exist in the bundle.

Generate kustomize bases and a kustomization.yaml for operator-framework manifests:
```bash
$ make bundle IMG=registry.infra.local:5000/${USER}/hellogo-operator:v0.0.1
```

Build the bundle and push it to the registry:
```bash
$ make bundle-build BUNDLE_IMG=registry.infra.local:5000/${USER}/hellogo-operator-bundle:v0.0.1
$ podman push registry.infra.local:5000/${USER}/hellogo-operator-bundle:v0.0.1
```

## Building an index of Operators using `opm`

Now that you have published the container image containing your manifests, how do you actually make that bundle available to other users' Kubernetes clusters so that the Operator Lifecycle Manager can install the operator? This is where the meat of the `operator-registry` project comes in. OLM has the concept of [CatalogSources](https://operator-framework.github.io/olm-book/docs/glossary.html#catalogsources) which define a reference to what packages are available to install onto a cluster. To make your bundle available, you can add the bundle to a container image which the CatalogSource points to. This image contains a database of pointers to bundle images that OLM can pull and extract the manifests from in order to install an operator. So, to make your operator available to OLM, you can generate an index image via opm with your bundle reference included:
Add an index as follows:
```bash
$ opm -c podman index add --bundles registry.infra.local:5000/${USER}/hellogo-operator-bundle:v0.0.1 --tag registry.infra.local:5000/${USER}/registry-index:0.0.1
$ podman push registry.infra.local:5000/${USER}/registry-index:0.0.1
```
The resulting image is referred to as an "Index". It is an image which contains a database of pointers to operator manifest content that is easily queriable via an included API that is served when the container image is run.

Now that image is available for clusters to use and reference with CatalogSources on their cluster.

For more detail on using `opm` to generate index images, take a look at the [documentation](https://github.com/operator-framework/operator-registry/blob/master/docs/design/opm-tooling.md).

## Using the index with Operator Lifecycle Manager

To add an index packaged with `operator-registry` to your cluster for use with [Operator Lifecycle Manager](https://github.com/operator-framework/operator-lifecycle-manager) (OLM) create a `CatalogSource` referencing the image you created and pushed above:
```bash
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${USER}-manifests
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.infra.local:5000/${USER}/registry-index:0.0.1
  publisher: ${USER^}
  displayName: ${USER^}'s Operators
EOF
```
This will download the referenced image and start a pod in the designated namespace (`openshift-marketplace`). Watch the catalog pods to verify that it/they start correctly and reach the `Running` status:

```bash
$ oc get pods -n openshift-marketplace | grep ${USER}
```
You can now [subscribe](https://github.com/operator-framework/operator-lifecycle-manager#discovery-catalogs-and-automated-upgrades) to Operators with Operator Lifecycle Manager. This represents an intent to install an Operator and get subsequent updates from the catalog:
```bash
oc create -f - <<EOF
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
$ oc new-project ${USER}-client
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
$ ROUTENAME=$(oc get route ${USER}hellogo-sample -o=jsonpath='{.spec.host}')
$ curl ${ROUTENAME}/test
```
The output should be:
```
Hello, you requested: /test
```
## Cleanup
Erase the application:
```bash
$ oc delete -n ${USER}-client -f config/samples/hellogo_v1alpha1_${USER}hellogo.yaml
```
Erase the subscription:
```bash
oc delete -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${USER}-hellogo-subscription
  namespace: openshift-operators
EOF
```

Get the name of the operator instance:
```bash
$ oc get clusterserviceversion | grep ${USER}
```
Delete the operator instance:
```bash
$ oc delete clusterserviceversion ${USER}-hellogo-operator.v0.0.1 -n openshift-operators
```
Delete the catalog source:
```bash
oc delete -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${USER}-manifests
  namespace: openshift-marketplace
EOF
```