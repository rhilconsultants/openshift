# Exercise 3 - Introduction to OpenShift CLI tool (OC)

## table of content:

1. login to OpenShift with the associate files.
2. explore the command line options
4. deploying Pods + deployment
3. deploy Service + route to your application.

## The Login

Each time we login to OpenShift 2 main action occur on our client Server

1. A Token login is been stored.
2. A Kubeconfig is been update with all the relevant values

first Let's see on which user we are login on 

```bash
$ oc whoami
```

Now let's see our Token 

```bash
$ oc whoami -t
```

(you notice that we did it for our registry login in Exercise 1)

Now that we see our Token we can catch from the file it is stored in :

```bash
$ cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    server: https://api...:443
  name: api...:443
- context:
    cluster: api...:443
    namespace: user01-project
    user: user01/api...:443
  name: user01/api...:443/user45
current-context: user01-project/api...:6443/user01
kind: Config
preferences: {}
users:
- name: admin/openShift.local:8443
  user:
    token: 18JdLxcf-f5FlBRPV0nwLGHhLzjTHfmUi5ZRpPKAobM
```

As you can see this is a example of a YAML file which contains all the necessary information regarding our current and Past logins.

Run it on your own file and see the results :

```bash
$ cat ~/.kube/config
```

## Exploring the Command Line Options

The oc command has many options and it is a product is growth just like OpenShift itself.

### Downloads

First create the ${HOME}/bin Directory

```bash
$ mkdir ${HOME}/bin
$ export PATH="${HOME}/bin:${PATH}"
```

To download oc all we need to do is to download the latest oc binary with the following command :

```bash
$ export OCP_RELEASE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt \
| grep 'Name:' | awk '{print $NF}')
$ wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-${OCP_RELEASE}.tar.gz
$ tar -xzf openshift-client-linux-${OCP_RELEASE}.tar.gz -C ~/bin/
```

### Auth Complete

In order to utilize the bash auto completion in our environment we need to run a few simple commands which are part of the package itself.  

to generate it just run the following command :

```bash
$ oc completion bash > ~/.bash_completion
```

** Now logout , login and test the command with the <TAB><TAB> key **

look at the oc version :

```bash
$ oc version
```

Now that we are running 2 version of oc we need to tell which one of them we want to use. 
The first oc binary which the command line found in the PATH variable is the one it is going to address when the command is invoked.
to change it back to the original version just remove the $HOME/bin from the PATH environment variable.

```bash
$ TMP_PATH=$(echo $PATH | sed "s/\/home\/${USER}\/bin\://g")
$ PATH=${TMP_PATH}
$ unset TMP_PATH
```

Or just logout and login back to the Bastion Server.

## deploying a pod + deployment

In this section we will how to create a pod and how to create a deployment which controls the Pods.

### creating Pods

as you know the POD is the smallest unit in our OpenShift Cluster so let's start by creating our first pod. 
Create a directory for our future YAML files and switch to that directory

```bash
$ mkdir ~/YAML
$ cd ~/YAML
```
now let's create our pod's YAML definition file :

```bash
$ cat > hello-go-pod-01.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: hello-go-01
  labels:
    app: hello-go
  namespace: project-${USER}
spec:
  containers:
    - name: hello-go
      image: image-registry.openshift-image-registry.svc:5000/$(oc project -q)/hello-go
      ports:
        - containerPort: 8080
```

and Let's craete it :

```bash
$ oc create -f hello-go-pod.yaml
```

now to see our Pods we need to run oc with a get argument :

```bash
$ oc get pods
```

now we see all our running Pods in our namesapce (project) and their status.

Now we will add another pod :

```bash
$ cat > hello-go-pod-02.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: hello-go-02
  labels:
    app: hello-go
  namespace: project-${USER}
spec:
  containers:
    - name: hello-go
      image: image-registry.openshift-image-registry.svc:5000/$(oc project -q)/hello-go
      ports:
        - containerPort: 8080
```

And let's get all the pods again :

```bash
$ oc get pods
```

Do you see the same container running on 2 different Pods ? good then everything we've done until now has been successful

#### cleaning

Before we move on to the next section we need to do a little bit of house cleaning.  
there are 2 ways to achieve that.

1. deleting from a YAML file
2. deleting by resource name 

for our first pod we will delete it by it's YAML file.  
this is a command way of work when we are working with a complexed YAML file which contains multiple resources which are connect to each other and we need to make sure the cleaning is thorough.

For our example it will be pod number 1 

```bash
$ oc delete -f hello-go-pod-01.yaml
```

For out second pod we will first grep the name and then delete it with another oc command :

```bash
$ oc get pods -o name | grep hello-go-02 | xargs oc delete 
```

even though there is only one POD we still ran the command with a grep for it's resource name.This is a good practice because in the real world we would like to delete a single Pod or Pods with a command identifier in it's name with out deleting any other PodS by mistake.

### Creating a Deployment.

A Deployment is Template holder and a set of definitions for Pods (one or more) it is going to deploy from the specified container.
In order to create a valid template we need to make sure our new Pods contains a label and that our deployment matches that label.  
More so we need to specified the number of Pods (replicas) we want it to run :

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
  replicas: 2
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

Now that the deployment is Ready we can apply it's configuraiton to the cluster:

```bash
$ oc apply -f hello-go-deployment.yaml
```

Now to view that our deployment is successful we can get both the deployment :

```bash
$ oc get deployment
```

And the Pods 

```bash
$ oc get pods
```

Try deleting the pods :

```bash
$ oc get pods -o name | grep hello-go | xargs oc delete
```

wait 20 seconds and then try to list the Pods again :

```bash
$ oc get pods
```

can you explain why there are still Pods running with a hello-go name ?

#### Changing the Replica

Right now we only have 2 Pods running for our hello-go application. Let's increase the number to 3 by changeing the replica value :

we can either use VIM 

```bash
$ vim hello-go-deployment.yaml
```
OR override the file

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
  replicas: 3
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
**NOTE**

If we override the file we need to make sure the name of the deployment does NOT change. If the name does changes then it will treated as a completely new deployment.

Now let's apply the cahnges :

```bash
$ oc apply -f hello-go-deployment.yaml
```
Now check how many Pods do you see ?

```bash
$ oc get pods
```

## Services and routes

Running our Pods is great But if we want to provide a service through those Pods then we need to expose then.

There are 2 type of exposing a Pod

1. internally
2. externally

### Internally

in order to expose a Pod internally to the namespace we need to create a service.

Sense our Pods are already running we can add a service with the matching label:

```bash
$ cat > hello-go-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: hellogo-service
  namespace: project-$(oc whoami)
spec:
  selector:
    app: hellogo
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
EOF
```
and create if :

```bash
$ oc create -f hello-go-service.yaml
```

Once the service is created we can access our Pods with it the namespace.

Select One of the Pods and rsh into it :

```bash
$ oc get pods -o name | grep heelo-go | head -1 | xrags oc rsh
```

now run our curl from exercise 1 to our service name 

```bash
$ curl http://hellogo-service:8080/test
Hello, you requested: /test
```
And Exit

```bash
exit
```

if you are getting the same result then your service is configured correctly (GOOD JUB !!!)

### Externally

In order to expose the Pods for request coming from out of our project (namespce) we need to create a route which is actually a reverse proxy definition back to our Pods matching the service we have just created.

In order to create a Route :

```bash
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

and deploy it :

```bash
$ oc create -f hello-go-route.yaml
```

Now let's run the same test only from our Bastion Server :

```bash
$ export ROUTE=$(oc get route/hellogo-route -n project-$(oc whoami) -o=jsonpath='{.spec.host}')"
$ curl http://${ROUTE}/test
Hello, you requested: /test
```

Notice that we did not have to define a PORT with our request.  

Can you explain why ?

## Command line interface Summery

In this exercise we create the very basic resource we need to run a stateless application. We have created a Pod and a matching deployment. followed by a service and a route to expose everything to the world.