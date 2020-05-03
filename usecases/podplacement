## Managing Pod Placement Using Labels 

A common customer request is to control where the pods are running based on a few parameters

1. Infrastructure Pods - metrics, logging, routers
2. Project Teams - Dev Groups 

## Breakdown of Approaches

There are a number of solutions that can be taken regarding this.  Below are a list of common solutions that I have seen in the field

### OCP Router Placement

In OCP 4, the router is now managed by a CRD, and therefore in order to control its nodeselector, it needs to be updated.


In the spec section of the CRD you can add the following in order that the routers be placed on the infra nodes:

First open the CRD for editting:

```
oc edit ingresscontrollers.operator.openshift.io -n openshift-ingress-operator  default
```

Then add the nodeSelector:

```
spec:
  nodePlacement:
    nodeSelector:
      matchExpressions:
      - key: node-role.kubernetes.io/infra
        operator: In
        values:
        - ""
```

For more informatio please see the official documentation:

https://docs.openshift.com/container-platform/4.3/networking/ingress-operator.html

### Managing Project Labeling

A common solution it control pod placement based on projects is to add a default node selector in the project namespace configuration.  This will insure that all pods that are deployed in the project will only run on nodes with the desired label.

To implement, add the following under the annotations section of the namespace:


Open the namespace for editting

```
oc edit namespace myproject
```

Update the annotations:

```
annotations:
  openshift.io/node-selector: “node-role.kubernetes.io/worker=""
  ...
```

Note that running pods will not be relocated automatically.  In order for the change to take effect on them you must kill the pods.
