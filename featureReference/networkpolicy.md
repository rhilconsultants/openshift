## Network Policy

A more commonly implemented feature today as it is now default in OCP, network policy allows easily managing network isolation inside the SDN.  This allows implementation of the following options:

1. namespace isolation
2. isolation inside a namespace
3. allowing ingress traffic based on namespaces and/or source app label 
4. allowing ingress traffic based on destination app label

### Example Network Policy Yamls

The most common reoccuring scenarios I have found are to set the following defaults on all project creation:

1. Block all traffic from outside the namespace
2. Allow traffic only from the OCP Routers

The following Yamls will achieve this:

```
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-same-namespace
spec:
  podSelector:
  ingress:
  - from:
    - podSelector: {}
```

```
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata: 
  name: allow-from-default-namespace
spec:
  podSelector:
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: ingress
```

Note that in the second example, the label used is the generic label in the openshift-ingress namespace where the routers are running.  

HostNetwork:  In the case you see that the rule is not working, meaning it is not allowing traffic from the routers to the application service running in your namespace, you then need to add the label to the default namespace as follows as the traffic is routed through the default namespace:

```
oc edit namespace default
```

```
labels:
  network.openshift.io/policy-group: ingress
  ...
```

For more information please see the official documentation:
https://docs.openshift.com/container-platform/4.3/networking/configuring-networkpolicy.html
