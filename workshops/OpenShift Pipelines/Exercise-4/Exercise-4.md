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

    # mkdir ~/Tekton/ubi-pipeline
    # cd ~/Tekton/ubi-pipeline

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
    ENV KUBECONFIG=/opt/root-app/kubeconfig
    USER root
    COPY run.sh kubeconfig /opt/root-app/
    COPY tkn oc /usr/bin
    USER 1001
    ENTRYPOINT ["/opt/root-app/run.sh"]
    EOF

### Creating a Service Account and kubeconfig

In order to provide the right permissions for our automation in Openshift we need to create a service account for authentication provide it the expected permissions and create an authentication file (kubeconfig).

Let's make our working directory 

    # mkdir ~/Tekton/Ex4 && cd ~/Tekton/Ex4

#### Service account

Now let's create a service account in our namespace :

    # cat >> ubi-pipeline-sa.yaml << EOF
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: ubi-tekton
    EOF

And create it :

    # oc create -f ubi-pipeline-sa.yaml

#### Permissions 

To make things easy we will give the service account admin permissions on our namespace :

    # oc adm policy add-role-to-user admin system:serviceaccount:project-${USER}:ubi-tekton -n project-${USER}

#### Generate Kubeconfig

Fetch the name of the secrets used by the service account. This can be found by running the following command:

    # oc describe serviceAccounts ubi-tekton

Fetch the token from the secret.  

    # TOKEN_NAME=$(oc describe serviceAccounts ubi-tekton | grep Tokens | awk '{print $2}')

Using the Mountable secrets value, you can get the token used by the service account. Run the following command to extract this information:

    # oc describe secrets ${TOKEN_NAME}

and save the token to a variable :

    # TOKEN=$(oc describe secrets ${TOKEN_NAME} | grep 'token:' | awk '{print $2}')

To make things easy we are going to generate the kubeconfig for our user and change it to fit the service account.  
Let's first create the base file:

    # cd ~/Tekton/ubi-pipeline
    # oc config view --flatten --minify > kubeconfig

A Quick look at the file shows how the kubeconfig file looks like :

    # cat kubeconfig
    apiVersion: v1
    clusters:
    - cluster:
        insecure-skip-tls-verify: true
        server: https://api.ocp4.infra.local:6443
      name: api-ocp4-infra-local:6443
    contexts:
    - context:
        cluster: api-ocp4-infra-local:6443
        namespace: project-${USER}
        user: ${USER}
      name: project-${USER}/api-ocp4-infra-local:6443/${USER}
    current-context: project-${USER}/api-ocp4-infra-local:6443/${USER}
    kind: Config
    preferences: {}
    users:
    - name: ${USER}
      user:
        token: < user token >


And let's modify it to fit our new service account :

    # cat > kubeconfig << EOF
    apiVersion: v1
    clusters:
    - cluster:
        insecure-skip-tls-verify: true
        server: https://api.ocp4.infra.local:6443
      name: api-ocp4-infra-local:6443
    contexts:
    - context:
        cluster: api-ocp4-infra-local:6443
        namespace: project-${USER}
        user: ubi-tekton
      name: ubi-tekton
    current-context: ubi-tekton
    kind: Config
    preferences: {}
    users:
    - name: ubi-tekton
      user:
        token: $TOKEN
    EOF

Test the new file by setting the environment variable and point to it :

    # export KUBECONFIG="/home/${USER}/Tekton/ubi-pipeline/kubeconfig"

And Run oc command to see all the pods :

    # oc get pods

if you see all your running pipelines and the event listener pods ... you are good to go.  


### Creating the Image

Now that we have a kubeconfig we can copy it to our image and use it with our oc command to create object in our cluster.  
Once we've done that we can go ahead and create our image :

    # buildah bud -f Dockerfile -t ubi-pipeline .

### Pushing to the Registry

set your OpenShift cluster Prefix and you current namespace:

    # export CLUSTER="ocp4.infra.local"
    # export NAMESPACE=$(oc project -q)

Now that we have our image we need to TAG it and push it to our registry

    # podman tag localhost/ubi-pipeline default-route-openshift-image-registry.apps.${CLUSTER}/${NAMESPACE}/ubi-pipeline

    # podman push default-route-openshift-image-registry.apps.${CLUSTER}/${NAMESPACE}/ubi-pipeline
    (You may need to login before you can push)

### Deploying on Openshift (Optional)

Now that the image is ready let's create a working directory and deploy it :

    # cd ~/Tekton/Ex4/

All that is left is to create a deployment for our image :

    # cat > deployment.yaml << EOF
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

and look if the pod is running successfully :

    # oc get pods | grep ubi

After the deployment we can use the web console to login or use the oc command to get the pod terminal access

    # POD_ID=$(oc get pods -n $NAMESPACE -o name | grep ubi-pipeline | awk -F \/ '{print $2}')
    # oc rsh ${POD_ID}

Run get pod  (oc get pods) command to see that it's working and continue to the next section.


## The IAC Pipeline

Now that we have everything ready we can build the pipeline with the following tasks :

  1. PipelineResource : our git Repository
  2. task for deploying all of the YAML files in the deployment directory (App + Service)
  3. create a task for TDD 
  3. creating the listener


Create the deployment fie in the git repository :

    # mkdir ~/Tekton/monkey-app/deploy
    # cat > ~/Tekton/monkey-app/deploy/deployment.yaml << EOF
    kind: Deployment
    apiVersion: v1
    metadata:
      name: monkey-app
      namespace: project-${USER}
    spec:
      template:
        metadata:
          labels:
            app: monkey-app
        spec:
          containers:
            - name: monkey-app
              image: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/monkey-app:latest
              ports:
              - containerPort: 8080
      replicas: 1
      selector:
        matchLabels:
          app: monkey-app
    EOF


Create the service YAML file

    # cat > ~/Tekton/monkey-app/deploy/service.yaml << EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: monkey-app
      namespace: project-${USER}
    spec:
      selector:
        app: monkey-app
      ports:
        - protocol: TCP
          port: 8080
          targetPort: 8080
    EOF

Create the route YAML file

    # cat > ~/Tekton/monkey-app/deploy/route.yaml << EOF
    apiVersion: route.openshift.io/v1
    kind: Route
    metadata:
      name: monkey-app
      namespace: project-${USER}
    spec:
      port:
        targetPort: 8080
      to:
        kind: Service
        name: monkey-app
        weight: 100
      wildcardPolicy: None
    EOF

Add a task which uses our new Image for their run and deploy everything

    # cd ~/Tekton/Ex4/
    # cat > monkey-deploy-task << EOF
    kind: Task
    metadata:
      name: monkey-deploy-task
    spec:
      resources:
        inputs:
          - name: source
            type: git
      steps:
        - name: deploy
          image: 
          workingDir: /workspace/source/
          
          command: ["/bin/bash" ,"-c"]
          args:
            - |-
              oc create -f deploy/deployment.yaml
              oc create -f deploy/service.yaml
              oc create -f deploy/route.yaml
    EOF

Create the new Task :

    # oc create -f monkey-deploy-task.yaml

update the pipeline with our new task :

    # cp ../Ex2/pipeline-build-monkey-ws.yaml .

And Add the lines :

    - name: monkey-deploy
        taskRef:
          name: monkey-deploy-task
        runAfter: 
          - monkey-build-task-ws

Apply the update

    # oc apply -f pipeline-build-monkey-ws.yaml

now let's push our new files to our git and see what is happening :

    # cd ~/Tekton/monkey-app/
    # git add -A
    # git commit -a -m "Adding IAS"
    # git push origin master

Watch for new pipeline runs and monitor their logs.

If every went as expected your IAC process is set.

# Congratulations ...

You have completed the OpenShift Pipeline Workshop