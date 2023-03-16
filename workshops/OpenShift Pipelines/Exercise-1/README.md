# Exercise - 1 (Intro + Basics)

## Welcome to the Pipeline (Introduction)

OpenShift Pipelines is a cloud-native, continuous integration and continuous delivery (CI/CD) solution based on Kubernetes resources.
It uses Tekton building blocks to automate deployments across multiple platforms by abstracting away the underlying implementation details.   Tekton introduces a number of standard Custom Resource Definitions (CRDs) for defining CI/CD pipelines that are portable across Kubernetes distributions.
OpenShift Pipelines provide a set of standard Custom Resource Definitions (CRDs) that act as the building blocks from which you can assemble a CI/CD pipeline for your application.

### Key Features

  - OpenShift Pipelines is a serverless CI/CD system that runs `Pipelines` with all the required dependencies in isolated containers.
  - OpenShift Pipelines are designed for decentralized teams that work on microservice-based architecture.
  - OpenShift Pipelines use standard CI/CD pipeline definitions that are easy to extend and integrate with the existing Kubernetes tools, enabling you to scale on-demand.
  - You can use OpenShift Pipelines to build images with Kubernetes tools such as Source-to-Image (S2I), Buildah, Buildpacks, and Kaniko that are portable across any Kubernetes platform.
  - You can use the OpenShift Container Platform Developer Console to create Tekton resources, view logs of Pipeline runs, and manage pipelines in your OpenShift Container Platform namespaces.

## OpenShift Pipelines Concepts

### Task
A `Task` is the smallest configurable unit in a `Pipeline`. It is essentially a function of inputs and outputs that form the Pipeline build. It can run individually or as a part of a Pipeline. A `Pipeline` includes one or more `Tasks`, where each `Task` consists of one or more `Steps`. `Steps` are a series of commands that are sequentially executed by the `Task`.

### TaskRun
A `TaskRun` is automatically created by a `PipelineRun` for each `Task` in a `Pipeline`. It is the result of running an instance of a `Task` in a `Pipeline`. It can also be manually created if a `Task` runs outside of a `Pipeline`.

### Pipeline
A `Pipeline` consists of a series of `Tasks` that are executed to construct complex workflows that automate the build, deployment, and delivery of applications. It is a collection of parameters and one or more `Tasks`.

### PipelineRun
A `PipelineRun` is the running instance of a `Pipeline`. A `PipelineRun` initiates a `Pipeline` and manages the creation of a `TaskRun` for each `Task` being executed in the `Pipeline`.

### Workspace
A `Workspace` is a storage volume that a `Task` requires at runtime to receive input or provide output. A `Task` or `Pipeline` declares the `Workspace`, and a `TaskRun` or `PipelineRun` provides the actual location of the storage volume, which mounts on the declared `Workspace`. This makes the `Task` flexible, reusable, and allows the `Workspaces` to be shared across multiple Tasks.

### Trigger
A `Trigger` captures an external event, such as a Git pull request and processes the event payload to extract key pieces of information. This extracted information is then mapped to a set of predefined parameters, which trigger a series of tasks that may involve creation and deployment of Kubernetes resources. You can use `Triggers` along with `Pipelines` to create full-fledged CI/CD systems where the execution is defined entirely through Kubernetes resources.

## Create an OpenShift Project
Run the following command to create an OpenShift project:
```bash
oc new-project $(oc whoami)
```

## Using Pipelines - the Basics
Now that we understand (or at the very least familiarized) with all the concepts we can start by making sure that OpenShift Pipeline is install on our system.
We can do that by quering for `Pipeline` resource:
```bash
oc get pipelines
```

If the output is the message:

    error: the server doesn't have a resource type "pipelines"

Then OpenShift Pipelines has not been installed. If the output is of the form:

    No resources found in <project> namespace.

Then OpenShift Pipelines has been installed.


### Basic usage
First let's create a directory for this exercise and set it as the current working directory:

    mkdir ~/Tekton
    cd ~/Tekton

Now let's create our first `Task` by copying the following to a file named `echo-hello-world.yaml`:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: echo-hello-world
spec:
  steps:
    - name: echo
      image: registry.access.redhat.com/ubi8-minimal
      command:
        - echo
      args:
        - "Hello World"
```

Take a few seconds to review the `Task`. It is pretty straightforward when we look at it.
All we are asking the `Task` to do is to obtain our image module (the images that the task is using are actually the modules for our pipeline) and then it runs the echo command with the "Hello World" arguments.

Since a `Task` is a Kubernetes Custom Resource, we will go ahead and use the `oc` command to create it:

    oc create -f echo-hello-world.yaml

We can also use the `tkn` command to list the task:

    tkn task list

The output will be of the form:

    NAME               DESCRIPTION   AGE
    echo-hello-world                 X seconds ago

Now, In order to run the command we need to create a `TaskRun` custom resource. We can create it with a YAML file or by using the `tkn` command.

In order to create a YAML file, copy the following to a file named `tr-echo-hello-world.yaml`:
```yaml
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  name: taskrun-echo-hello-world
spec:
  taskRef:
    name: echo-hello-world
```

Now create the `TaskRun`:

    oc create -f tr-echo-hello-world.yaml

Now that we created a the `TaskRun` for our `Task` we can view it using the CLI:

    tkn taskrun list

To view the output of the `TaskRun` we can use the `tkn` tool:

    tkn taskrun logs taskrun-echo-hello-world

The output should be of the form:

<span style="color:green">[echo]</span> Hello World

In case the `Task` takes a long time to finish, we can look at the `pods` and their status:

    oc get pods

The output will be of the form:

    NAME                       STARTED         DURATION   STATUS
    taskrun-echo-hello-world   7 seconds ago   ---        Running(Pending)

The pod has not yet started. Perhaps it is downloading the container image for the first time. When the task has completed, the output should be of the following form:

    NAME                       STARTED         DURATION   STATUS
    taskrun-echo-hello-world   3 minutes ago   26s        Succeeded

<!--
In case you are getting an ImagePullErr in the status then that could be 1 of 2 reasons

  1. we are using a wrong image path (change it to your local registry)
  2. we didn't configure a pull secret to work with our registry

In case we need to solve reason number 2 then this is how to do it:

#### Generating config.json (registry authentication)
First we will generate a config.json file under our "$HOME/.docker" directory

    mkdir ~/.docker

Next we need to take our token and use it as a password:

    oc whoami -t

Take the output and put in where the trienge brakets are:

    REG_SECRET=`echo -n '<the username here>:<the token here>' | base64 -w0`

Now we will setup a few variable:

    MY_REGISTRY="default-route-openshift-image-registry.apps.${OCP_CLUSTER}.${OCP_DOMAIN}"

And create the File

    echo '{ "auths": {}}' | \
    jq '.auths += {"MY_REGISTRY": {"auth": "REG_SECRET","email": "me@working.me"}}' | \
    sed "s/REG_SECRET/$REG_SECRET/" | sed "s/MY_REGISTRY/$MY_REGISTRY/" | jq . > ~/.docker/config.json

To make sure we did o.k. just run the `podman` login command:

    podman login ${MY_REGISTRY}
    Authenticating with existing credentials...
    Existing credentials are valid. Already logged in to default-route-openshift-image-registry.apps.ocp4.infra.local

Now we will set our namespace into a variable:

    export NAMESPACE=$(oc project -q)

To make life easier for podman we can set an Environment variable for our config.json file

    export REGISTRY_AUTH_FILE="/home/$USER/.docker/config.json"

#### For External Registries
we will create a secret and add the file to our namespace

    oc create secret generic --from-file=.dockerconfigjson=${REGISTRY_AUTH_FILE} \
    --type=kubernetes.io/dockerconfigjson pullsecret -n $NAMESPACE

and then attach it to the pull operation:

    oc secrets link default pullsecret --for=pull -n $NAMESPACE

Delete the taskrun and recreate it, that should solve the issue.
-->
### Passing Parameters to Tasks
Now that we created a `Task` and a `TaskRun` we can go ahead and expand our `Task` by adding parameters to our task. `params` enable us to use the same `Task` for more than one resources which can be both the input and the output of a task.

Copy the following to a file named `task-hello-params.yaml`:
```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: echo-hello-person
spec:
  params:
    - name: person
      description: Person to greet
      default: bob
  steps:
    - name: echo
      image: registry.redhat.io/ubi8/ubi-minimal
      script: |
        echo "Hello $(params.person)"
```
In our example we have configured a parameter named `person` and added it as one of our arguments.

Let's go ahead and run it:

    oc create -f task-hello-params.yaml

Now that the `Task` has been created, we run it by creating a `TaskRun` resource using the `tkn` command as follows:

    tkn task start --use-param-defaults echo-hello-person

When we ran the command the last line of the output is the command we need to view the logs and make sure it is running as we wanted.
Go ahead and run the logs command ...
What do you see?

Now let's change "bob" to "sally" ...
There are several ways to do it:

1. update the YAML file and apply the changes
2. edit the current task using the oc command
3. send a new `param` to another run

The first option is pretty simple, just edit the file and change the `default` person from "bob" to "sally" and then apply the changes using:

    vi task-hello-params.yaml

and

    oc apply -f task-hello-params.yaml

Question: Why was "apply" used here instead of "create"?

The second way to change the name is even more simple. Run the following command to open an editor with the current contents of the `Task` object:

    oc get tasks -o name | grep person | xargs oc edit

Edit the name in the task. Once you save and exit the changes will take effect. Rerun the task.

The last way is preferred. We are going to create a `TaskRun` where we will define the param's new value in it. Copy the following to a file named `taskrun-hello-person-param-override.yaml`:
```yaml
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  name: echo-hello-person-task-run-override
spec:
  taskRef:
    name: echo-hello-person
  params:
    - name: person
      value: sally
```

Now create the `TaskRun`:

    oc create -f taskrun-hello-person-param-override.yaml

Now we can look at the logs and see the output we wanted:

    tkn taskrun logs echo-hello-person-task-run-override -f

If you see "Hello sally" then we are good to go.

## Bonus Task

Try sending the `param` value using the `tkn` command.

## Cleanup

After you haved completed all the tasks it is time for a cleanup:

    oc get taskrun -o name | xargs oc delete

We will wait for the rest of the class to complete the exercise and move on to [Exercise 2](../Exercise-2/README.md).
