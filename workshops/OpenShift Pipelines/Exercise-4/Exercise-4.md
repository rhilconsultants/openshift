# Exercise 4

## Before we Begin

In this Exercise we will create a Custom Image module and use it in a pipeline(Task).
The Object of the Exercise is to show how simple it is to create a new image module and start using within the pipeline so we will have a good showcase to our customers how easy it is to create a new module.  

### The Exercise use case 

In this case we will create a Custom image which we will use as our module image. In our case we will use the tools we had downloaded in our prerequisites section in order to create and deploy a simple application (the monkey-app) with a listener to our Monkey git repository which we will eventually are creating a full CI/CD for our Monkey application 

## building an Image
  
Let's build a container image which holds the 2 tools and we are going to use the container to run a pod and connect to is so we will be able to use the tools from it 

### the Dockerfile

First let's create the directory

    # mkdir ~/ubi-pipeline
    # cd ~/ubi-pipeline

Copy the 2 binaries we need to our new directory

    # cp ~/bin/oc ~/bin/tkn .

Now we will craete a simple endless command to run in the background so the image will not fail.

    # cat > run.sh << EOF
    #!/bin/bash
    tail -f /dev/null
    EOF

and we will make it executable 

    # chmod a+x run.sh

Now create a Dockerfile and copy the binaries to the new image

    # cat > Dockerfile << EOF
    FROM ubi8/ubi-minimal
    USER root
    COPY run.sh /opt/root-app/
    COPY tkn oc /usr/bin
    USER 1001
    ENTRYPOINT ["/opt/root-app/run.sh"]
    EOF

### Creating the Image

Once we've done that we can go ahead and create our image :

    # buildah bud -f Dockerfile -t ubi-pipeline .

### Pushing to the Registry

set your OpenShift cluster Prefix and you current namespace:

    # export CLUSTER="ocp4.example.com"
    # export NAMESPACE=$(oc project -q)

Now that we have our image we need to TAG it and push it to our registry

    # podman tag localhost/ubi-pipeline default-route-openshift-image-registry.apps.${CLUSTER}/${NAMESPACE}/ubi-pipeline

    # podman push default-route-openshift-image-registry.apps.${CLUSTER}/${NAMESPACE}/ubi-pipeline
    (You may need to login before you can push)

### Deploying on Openshift (Optional)

All that is left is to create a deployment for our image :

    #cat > deployment.yaml << EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ubi-pipeline
    spec:
      selector:
        matchLabels:
          app: ubi-pipeline
      replicas: 1
      template:
        metadata:
          labels:
            app: ubi-pipeline
        spec:
          containers:
            - name: ubi-pipeline
              image: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/ubi-pipeline
    EOF

And deploy it :

    # oc create -f deployment.yaml

After the deployment we can use the web console to login or use the oc command to get the pod terminal access

    # oc get pods -n $NAMESPACE -o name | grep ubi-pipeline | xargs oc rsh -n $NAMESPACE

## Creating a Service Account and kubeconfig

In order to provide the right permissions for our automation in Openshift we need to create a service account for authentication provide it the expected permissions and create an authentication file (kubeconfig).

### Service account

### Permissions 

### Generate Kubeconfig

### YAML Files

## The IAC Pipeline

Now that we have everything ready we can build the pipeline with the following tasks :

  1. PipelineResource : our git Repository
  2. task for deploying all of the YAML files in the deployment directory (App + Service)
  3. create a task for TDD 
  3. creating the listener

Now create the route YAML file and push it to git 

    # cat > deployment/route.yaml << EOF
    EOF

Create a Task that will Test the application route availability.

    # cat > route-tdd.yaml << EOF
    EOF

Watch for new pipeline runs and monitor their logs.

If every went as expected your IAC process is set.