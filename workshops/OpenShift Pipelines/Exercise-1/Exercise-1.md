# Exercise - 1 (Intro + Basics)

## welcome to the pipeline (Intro) 

OpenShift Pipelines is a cloud-native, continuous integration and continuous delivery (CI/CD) solution based on Kubernetes resources.  
It uses Tekton building blocks to automate deployments across multiple platforms by abstracting away the underlying implementation details.   Tekton introduces a number of standard Custom Resource Definitions (CRDs) for defining CI/CD pipelines that are portable across Kubernetes distributions.  
OpenShift Pipelines provide a set of standard Custom Resource Definitions (CRDs) that act as the building blocks from which you can assemble a CI/CD pipeline for your application.    

### Key features

  - OpenShift Pipelines is a serverless CI/CD system that runs Pipelines with all the required dependencies in isolated containers.
  - OpenShift Pipelines are designed for decentralized teams that work on microservice-based architecture.
  - OpenShift Pipelines use standard CI/CD pipeline definitions that are easy to extend and integrate with the existing Kubernetes tools, enabling you to scale on-demand.
  - You can use OpenShift Pipelines to build images with Kubernetes tools such as Source-to-Image (S2I), Buildah, Buildpacks, and Kaniko that are portable across any Kubernetes platform.
  - You can use the OpenShift Container Platform Developer Console to create Tekton resources, view logs of Pipeline runs, and manage pipelines in your OpenShift Container Platform namespaces.

### OpenShift Pipelines concepts

#### Task
A Task is the smallest configurable unit in a Pipeline. It is essentially a function of inputs and outputs that form the Pipeline build. It can run individually or as a part of a Pipeline. A Pipeline includes one or more Tasks, where each Task consists of one or more Steps. Steps are a series of commands that are sequentially executed by the Task.

#### TaskRun
A TaskRun is automatically created by a PipelineRun for each Task in a Pipeline. It is the result of running an instance of a Task in a Pipeline. It can also be manually created if a Task runs outside of a Pipeline.

#### Pipeline
A Pipeline consists of a series of Tasks that are executed to construct complex workflows that automate the build, deployment, and delivery of applications. It is a collection of PipelineResources, parameters, and one or more Tasks. A Pipeline interacts with the outside world by using PipelineResources, which are added to Tasks as inputs and outputs.

#### PipelineRun
A PipelineRun is the running instance of a Pipeline. A PipelineRun initiates a Pipeline and manages the creation of a TaskRun for each Task being executed in the Pipeline.

#### PipelineResource
A PipelineResource is an object that is used as an input and output for Pipeline Tasks. For example, if an input is a Git repository and an output is a container image built from that Git repository, these are both classified as PipelineResources. PipelineResources currently support Git resources, Image resources, Cluster resources, Storage Resources and CloudEvent resources.

#### Workspace
A Workspace is a storage volume that a Task requires at runtime to receive input or provide output. A Task or Pipeline declares the Workspace, and a TaskRun or PipelineRun provides the actual location of the storage volume, which mounts on the declared Workspace. This makes the Task flexible, reusable, and allows the Workspaces to be shared across multiple Tasks.

#### Trigger
A Trigger captures an external event, such as a Git pull request and processes the event payload to extract key pieces of information. This extracted information is then mapped to a set of predefined parameters, which trigger a series of tasks that may involve creation and deployment of Kubernetes resources. You can use Triggers along with Pipelines to create full-fledged CI/CD systems where the execution is defined entirely through Kubernetes resources.

#### Condition
A Condition refers to a validation or check, which is executed before a Task is run in your Pipeline. Conditions are like if statements which perform logical tests, with a return value of True or False. A Task is executed if all Conditions return True, but if any of the Conditions fail, the Task and all subsequent Tasks are skipped. You can use Conditions in your Pipeline to create complex workflows covering multiple scenarios.


# Using the Pipes (Basics)
Now that we understand (or at the very least familiarized ) with all the concepts we can start by making sure that pipeline is install on our system.  
we can do that by quering for service accounts and look for pipeline among them :

    # oc get sa | grep pipeline
    pipeline   2         5d17h


Now that we see the pipeline service account we can start by creating a simple task :

    apiVersion: tekton.dev/v1alpha1
    kind: Task
    metadata:
      name: echo-hello-world
    spec:
      steps:
        - name: echo
          image: registry.redhat.io/rhel7:latest
          # image: centos:centos7 - works as well
          command:
            - echo
          args:
            - "Hello World"

Take a few seconds to view the task. It is pretty straightforward when we look at it ...  
All we are asking the task to do is to obtain our image module (YES , the images that the task is using are actually the modules for our pipeline) and then it runs the echo command with the "Hello World" arguments

We can also use the command to list the task :

    # tkn task list

Now , In order to run the command we need to create a runtask (we can create it with a YAML or using the tkn command)  
For YAML :

    # cat > taskrun.yaml << EOF
    apiVersion: tekton.dev/v1alpha1
    kind: TaskRun
    metadata:
      name: echo-hello-world-task-run
    spec:
      taskRef:
        name: echo-hello-world
    EOF

    # oc create -f taskrun.yaml

Now that we created a Run for our task we can view it using the CLI :

    # tkn taskrun list

to view the output of the task run we can use our tkn tool :

    # tkn taskrun logs -f echo-hello-world-task-run

Now that we created a Task and a Task Run we can go ahead and expend our task by adding params to ou task  
"params" enable us to use the same task for more then one resources which can be both the input and the output of a task  
An example of params are as follow :

    # cat > task-params.yaml << EOF
    apiVersion: tekton.dev/v1alpha1
    kind: Task
    metadata:
      name: echo-hello-person
    spec:
      inputs:
        params:
          - name: person
            description: Person to greet
            default: There
      steps:
        - name: echo
          image: registry.redhat.io/rhel7:latest
          # image: centos:centos7 - works as well
          command:
            - echo
          args:
            - "Hello $(inputs.params.person)"
    EOF

