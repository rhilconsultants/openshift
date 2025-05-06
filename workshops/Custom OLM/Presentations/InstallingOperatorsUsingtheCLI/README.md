# Operator Installation Using the CLI

## Choose an Operator
View the list of Operators available to the cluster from OperatorHub:
```bash
$ oc get packagemanifests -n openshift-marketplace
```
The output will be of the form:
```
NAME                                                 CATALOG               AGE
infinibox-operator-certified                         Certified Operators   120m
datadog-operator-certified-rhmp                      Red Hat Marketplace   120m
iot-simulator                                        Community Operators   120m
...
```
For our example, we will install the Quay Container Security operator:
```bash
$ oc get packagemanifests -n openshift-marketplace | grep jaeger
```
The output will be of the form:
```
jaeger                                               Community Operators   4h54m
jaeger-product                                       Red Hat Operators     4h54m
```
Select the operator and create an environment variable with its name:
```bash
$ OPERATOR_NAME="jaeger"
```
## Inspect the Operator
Inspect the Operator to verify its supported install modes and available channels:
```bash
$ oc describe packagemanifests ${OPERATOR_NAME} -n openshift-marketplace
```
Note the `Description` section as it provides information on how to use the operator.

Note the `Install Modes` section. If `MultiNamespace` or `AllNamespace` types are no supported, then an OperatorGroup needs to be defined.
## Create a Subscription
Identify the operator's channel:
```bash
$ DEFAULT_CHANNEL=$(oc get packagemanifests ${OPERATOR_NAME} -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')
```
Identify the operator's catalog source:
```bash
$ CATALOG_SOURCE=$(oc get packagemanifests ${OPERATOR_NAME} -n openshift-marketplace -o jsonpath='{.status.catalogSource}')
```

Create a Subscription object to subscribe a namespace to an Operator, for example:
```bash
$ oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${OPERATOR_NAME}
  namespace: openshift-operators 
spec:
  channel: ${DEFAULT_CHANNEL}
  name: ${OPERATOR_NAME}
  source: ${CATALOG_SOURCE} 
  sourceNamespace: openshift-marketplace 
EOF
```
The output should be:
```
subscription.operators.coreos.com/openshift-pipelines-operator-rh created
```
Watch for the operator to become available in the `openshift-operators` namespace:
```bash
$ oc get all -n openshift-operators
```

## Create an Instance of the Operator
Read the Operator's documentation to check what CRDs the Operator provides. For this case, we will create a simple object:
```bash
$ oc create -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger-all-in-one-inmemory
  namespace: openshift-operators
EOF
```

## Cleanup
First delete instances created by the operator.
## Deleting the Operator


Check the current version of the subscribed Operator in the currentCSV field:
```bash
$ oc get subscription ${OPERATOR_NAME} -n openshift-operators -o yaml | grep currentCSV
```

Now delete the operator:
```bash
$ oc delete -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${OPERATOR_NAME}
  namespace: openshift-operators
EOF
```
Delete the ClusterServiceVersion related to the operator found above:
```bash
$ oc delete clusterserviceversion -n openshift-operators <currentCSV-from-above>
```
