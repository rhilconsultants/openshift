# Working with a Pipeline

## Components 
Now that we know how to work with tasks and their params it is a good time to move on and start working with pipelines  
Pipelines are consistent of several parts :

  1. pipeline resources
  2. pipeline pvc
  3. pipeline (metadata definition)
  4. pipeline Run 

  In this part we will go over each of the components and understand how they all work together to create a healthy pipeline.

## Getting dirty

### Planing the Pipeline

I know it may sound Obvious but a good pipeline needs a good planing before we even write the first row  
We need to know what are our resources , we need to know what are our tasks and we need to know if we have an option to run  
several tasks in parallel or do we need to run them sequentially 

### Planning

In this part we are going to build a pipeline that will work with a git repository as it's input resource. In the pipeline we will  
run a task that will build a simple go application , save it to a pvc and will create the application in OpenShift.(sound simple right?)  

### Configuring the Resource

As mentioned we will start by configuring the pipeline resource git which will be used for our Source Resource.  
In order to configure it we will apply the following YAML:  

    #cat > pipelineResource-git.yaml << EOF
    apiVersion: tekton.dev/v1alpha1
    kind: PipelineResource
    metadata:
      name: monkey-app-git
    spec:
      type: git
      params:
        - name: revision
          value: master
        - name: url
          value: https://github.com/ooichman/pipeline-tutorial.git
    EOF

Now we can create another resource which will be our output resource , In our case we will create an output resource which will be our application Image.

First export your namespace :

    #export NAMESPACE=`oc project -q`

Now we will create the pipeline resource YAML file.

    # cat > pipelineResouce-image.yaml << EOF
    apiVersion: tekton.dev/v1alpha1
    kind: PipelineResource
    metadata:
      name: monkey-app
    spec:
      type: image
      params:
      - name: url
        value: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/monkey-app:latest

Another resource that we are going to use in our case is a PVC to store our image after it is build.  
For that we are going to create our PVC as follow :

    #cat > pipeline-pvc.yaml << EOF
    kind: PersistentVolumeClaim
    apiVersion: v1
    metadata:
      name: container-build
      namespace: $NAMESPACE
    spec:
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: 5Gi
      storageClassName: managed-nfs-storage
      EOF

Now that we have created all our Resources we can start with the FUN part which is the build process


### Pipeline Tasks

Our pipeline needs tasks so it will know what to do.  
In our pipeline we need to stop and think about what it needs to do , taking into pieces and build a task from each piece.  

So to make our job easier we basically need to :

  1. build the application from the git Repository
  2. push it to our registry
  3. deploy the application using our YAML files

  so for the first task we can use an image named buildah which we can obtain from quay.io to build the image :

our task should look like :

    #cat > task-build-image.yaml << EOF
    apiVersion: tekton.dev/v1beta1
    kind: Task
    metadata:
      name: monkey-build-task
    spec:
    ##################### New content ###################
      resources:
        inputs:
          - {type: git, name: source}
        outputs:
          - {type: image , name: image}
    ##################### New content ###################
      params:
        - name: image-name
          description: The Name of the Image we want to use
          type: string
          default: "monkey-app"
      steps:
    ##################### New content ###################
        - name: build
          image: quay.io/buildah/stable:v1.11.0
          workingDir: /workspace/source/
          volumeMounts:
          - name: varlibcontainers
            	mountPath: /var/lib/containers
          command: ["/bin/bash" ,"-c"]
          args:
            - |-
              buildah bud -f Dockerfile -t image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/$(inputs.params.image-name):latest .
      volumes:
      - name: varlibcontainers
        persistentVolumeClaim:
          claimName: container-build
    ##################### New content ###################

As you can see we added a few more components we haven't used so far.  

in our spec definition we've added the "resources" schema.  
That is enabling us to use our pipeline resource (which we defined earlier) in our task which in this case we are using our git repository and the image as our output.  
  
Next we are using a param option to define our application name.  
For the last part use can see that we are defining our PVC as our mount directory and then we are running our buildah application.

