# Building a Pipeline

## Components
Now that we know how to work with `Tasks` and their `params` it is a good time to move on and start working with `Pipelines`. A pipeline can consist of the following components:
* Tasks
* ~~ClusterTasks~~
* Conditional and Finally Tasks
* Workspaces
* Task Results

## Basic Pipeline

A `Pipeline` defines a set of `Tasks` that act as an ordered set of building blocks.

Copy the following to a file named `greetings-pipeline.yaml` to create a `Pipeline` that runs the `Tasks` created in the previous section:
```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: greetings
spec:
  params:
  - name: person
    type: string
  tasks:
    - name: hello-world
      taskRef:
        kind: Task
        name: echo-hello-world
    - name: hello-person
      runAfter:
        - hello-world
      taskRef:
        kind: Task
        name: echo-hello-person
      params:
      - name: person
        value: $(params.person)
```

Create the `Pipeline` object by running:
```bash
oc create -f greetings-pipeline.yaml
```

## PipelineRun

A `PipelineRun` resource is used to start a `Pipeline`.

Create a `PipelineRun` resource by copying the following to a file named `greetings-pipelinerun.yaml`:
```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: greetings-run
spec:
  pipelineRef:
    name: greetings
  params:
  - name: person
    value: "Alice"
```

Start the `Pipeline` by creating the `PipelineRun` object in OpenShift:
```bash
oc create -f greetings-pipelinerun.yaml
```

Track the progress by running:
```bash
tkn pipelinerun logs -f greetings-run
```
The output should be of the form:

  <span style="color:green">[hello-world : echo]</span> Hello World

  <span style="color:green">[hello-person : echo]</span> Hello Alice

You can view the `Pipeline` graphically and follow the `PipelineRun` logs in the OpenShift web console. Select `Pipelines` from the left pane. The `Administrator` drop down allows you to view `Pipeline`, `Tasks` and `Triggers` whereas in the `Developer` view, only `Pipelines` are available:

<img alt="OpenShift web console" src="pipelines-web-interface.png" width="75%" height="75%">

### The Pipeline Sequential/Parallel Tasks

The `Pipeline` above runs tasks sequentially (see `runAfter`). Let's add a `Task` that will run in parallel to the first `Task` by adding the following to the end of the `greetings-pipeline.yaml` file. Ensure that the indentation for the `Tasks` is the same as above:
```yaml
    - name: hello-parallel
      taskRef:
        kind: Task
        name: echo-hello-person
      params:
      - name: person
        value: "parallel person"
```

Update the `Pipeline` by running:
```bash
oc apply -f greetings-pipeline.yaml
```

QUESTION: Can you explain why "apply" is used here instead of "create"?

Review the updated `Pipeline` `details` in the OpenShift web console by clicking on the name of the `Pipeline`. Note that the new `Task` will run in parallel to the existing `Tasks`.

### Finally Tasks
If specified, a `finally` task is always run as the last step of the `Pipeline`. It can be used for cleanup, or to notify an external server about the status of the `Pipeline` (email, Slack, Teams, etc.).

Let's extend our `greetings-pipeline.yaml` example by adding a `finally` task.

```yaml
  finally:
    - name: last-task
      taskRef:
        kind: ClusterTask
        name: tkn
      params:
        - name: SCRIPT
          value: 'echo "Overall status: $(tasks.status)";echo "Logs:";tkn pr logs $(context.pipelineRun.name)'
```

Take note:
* The `Pipeline` is making use of a `Tekton` variable. More information on these variables can be found at [this link](https://tekton.dev/docs/pipelines/variables/).
* The `Pipeline` is using a (deprecated) `ClusterTask`. It is similar to a `Task` but it is cluster scoped. For a list of `ClusterTasks` install on your cluster run: `oc get ClusterTasks`


Update the `Pipeline` by running:
```bash
oc apply -f greetings-pipeline.yaml
```

View the `Pipeline details` of the `Pipeline` in the OpenShift web console.

Start the `Pipeline` by running:
```bash
oc delete -f greetings-pipelinerun.yaml
oc create -f greetings-pipelinerun.yaml
```

QUESTION: Can you explain why "oc apply" cannot be used here?

Review the logs of the `finally` task. Can you explain the status?

We will wait for the rest of the class to complete the exercise and move on to [Exercise 3](../Exercise-3/README.md).
