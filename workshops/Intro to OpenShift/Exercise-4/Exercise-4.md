# Exercise 4 - OpenShift Quota

## table of content 
In the following exercise we will learn how to :

1. create a quota
2. modify the quota for a specified namespace
3. modifying our deployment with request and limits


## create a quota



A resource quota, defined by a ResourceQuota object, provides constraints that limit aggregate resource consumption per project. It can limit the quantity of objects that can be created in a project by type, as well as the total amount of compute resources and storage that may be consumed by resources in that project.

This guide describes how resource quotas work, how cluster administrators can set and manage resource quotas on a per project basis, and how developers and cluster administrators can view them.

Let's create a Basic Quota Definition :

```bash
$ cd ~/YAML
$ NAMESPACE=$(oc project -q)
$ cat > ResourceQuota.yaml << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: core-object-counts
  namespace: ${NAMESPACE}
spec:
  hard:
    memory: "2Gi"
    cpu: "20"
    pods: "3" 
    replicationcontrollers: "2" 
    secrets: "2" 
    services: "2" 
EOF
```

Now Ask the Cluster Admin to create the Resource

(As the Cluster Admin)
```bash
$ oc create -f ResourceQuota.yaml
```

Now let's update the replica of our application to exceed the limit by updating the replicas in our deployment file 


```bash
$ cat > hello-go-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-go
  namespace: project-$(oc whoami)
spec:
  selector:
    matchLabels:
      app: hello-go
  replicas: 5
  template:
    metadata:
      labels:
        app: hello-go
    spec:
      containers:
        - name: hello-go
          image: image-registry.openshift-image-registry.svc:5000/$(oc project -q)/hello-go
          ports:
            - containerPort: 8080
EOF
```

and apply it :

```bash
$ oc apply -f hello-go-deployment.yaml
```

Now let's look at the number of Pods :

```bash 
$ oc get pods
```

as you can see because your limit is only 4 pods you can not create more then 4 pods even if the replicas are set to 5.

## Modifying the quota

Now we will edit the quota so it will be able to create the extra pod :

```bash
$ cat > ResourceQuota.yaml << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: core-object-counts
  namespace: ${NAMESPACE}
spec:
  hard:
    memory: "2Gi"
    cpu: "20"
    pods: "5" 
    replicationcontrollers: "2" 
    secrets: "2" 
    services: "2" 
EOF
```

And ask the Cluster Administrator to apply them :

```bash
$ oc apply -f ResourceQuota.yaml
```

We need to wait up to 7 minutes for the quota cycle to complete and reschedule the wait of the Pods with it's limits.

run the list of Pods again and see the results:

```bash
$ oc get pods
```

## Adding Request and Limits 


By default, containers run with unbounded compute resources on an OpenShift Container Platform cluster. With limit ranges, you can restrict resource consumption for specific objects in a project:

  - pods and containers: You can set minimum and maximum requirements for CPU and memory for pods and their containers.
  - Image streams: You can set limits on the number of images and tags in an ImageStream object.
  - Images: You can limit the size of images that can be pushed to an internal registry.
  - Persistent volume claims (PVC): You can restrict the size of the PVCs that can be requested.

If a pod does not meet the constraints imposed by the limit range, the pod cannot be created in the namespace.

### viewing the current Configuration :

```bash
$ oc get limits
```

Now see see the limits in details :

```bash
$ oc get limits -o name | xargs oc get -o yaml
```

Now ,as A developers Let's set the limits and request :

```bash
$ cat > hello-go-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-go
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      app: hello-go
  replicas: 2
  template:
    metadata:
      labels:
        app: hello-go
    spec:
      containers:
        - name: hello-go
          image: image-registry.openshift-image-registry.svc:5000/$NAMESPACE/hello-go
          resources:
            requests:
              memory: "64Mi"
              cpu: "250m"
            limits:
              memory: "128Mi"
              cpu: "500m"
          ports:
            - containerPort: 8080
EOF
```

and Apply it :
```bash
$ oc apply -f hello-go-deployment.yaml
```

you can see that the pods have been restarted and now are running within the request and limits we configured.


**That is it*** 
you have completed Exercise 4

## OpenShift Quota

In this exercise we played with some quota limitation, modified the namespace limits and added request and limits to our application.