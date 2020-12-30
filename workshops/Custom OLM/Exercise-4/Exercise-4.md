# CI/CD OpenShift Pipeline For an Operator
## Installation
### Red Hat OpenShift Pipelines Operator
It is assumed that your instructor installed Red Hat OpenShift Pipelines in your environment.
### tkn Command
Download the latest version of the `tkn` command for your development host from:
```
https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/
```
and install it in your ${HOME}/bin directory.
## Build Image
At present, there is no image that can be used to build an operator. We will create one as follows:
```bash
$ mkdir ~/buildimage && cd ~/buildimage
$ cat > Dockerfile <<EOF
FROM quay.io/podman/stable:latest
RUN yum -y install make git && yum clean all
EOF
$ podman build -t ${REGISTRY}/${USER}/operator-sdk-build-tools .
$ podman push ${REGISTRY}/${USER}/operator-sdk-build-tools
```

## Git Repository


Convert the operatory directory to a `git` repository:
```bash
$ cd ~/ose-openshift/${USER}-hellogo-operator
$ git init
$ git add .
$ git commit -m 'initial release'
```
First ensure that an environment variable `GIT_REPO` is set specifying the `git` repository.
```bash
$ git remote add origin http://${USER}:${USER}@${GIT_REPO}/${USER}/${USER}-hellogo-operator.git
$ git push -u origin master
```
## Pipeline Resources
### Registry Secret
Generate a `config.json` file with authentication for the workshop registry as follows:
```bash
$ REG_SECRET=$(echo -n "$(oc whoami):$(oc whoami -t)" | base64 -w0)
$ echo "{\"auths\":{\"${REGISTRY}\":{\"auth\":\"${REG_SECRET}\"}}}" > ~/auth.json
```
Create a ConfigMap with the secret:
```bash
$ (cd $HOME;oc create configmap authjson --from-file=auth.json)
```
The output should be:
```
configmap/authjson created
```
### Git Scaffold Pipeline Resource
Create a `PipelineResource` for the source code by running:
```bash
$ oc create -f - <<EOF
apiVersion: tekton.dev/v1alpha1
kind: PipelineResource
metadata:
  name: git-${USER}-hellogo-operator
spec:
  type: git
  params:
    - name: revision
      value: master
    - name: url
      value: http://${USER}:${USER}@${GIT_REPO}/${USER}/${USER}-hellogo-operator
EOF
```
### Image Pipeline Resource
```bash
$ oc apply -f - <<EOF
apiVersion: tekton.dev/v1alpha1
kind: PipelineResource
metadata:
  name: image-${USER}-hellogo-operator
spec:
  type: image
  params:
    - name: url
      value: ${REGISTRY}/${USER}/hellogo-operator:v1.2.3
EOF
```
## Persistent Volume
We will create a persistent volume claim (PVC) to store temporary artifacts.
```bash
$ oc create -f - <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ${USER}-container-build
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 3Gi
  volumeMode: Filesystem
EOF
```
Ensure that the PVC has a status of `Bound` before continuing.
## Pipeline Tasks

### Building the Operator
```bash
$ oc apply -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: ${USER}-build-hellogo-operator-task
spec:
  params:
    - name: TLSVERIFY
      description: Verify the TLS on the registry endpoint (for push/pull to a non-TLS registry)
      default: "false"
  resources:
    inputs:
      - name: source
        type: git
    outputs:
      - name: builtimage
        type: image
  steps:
    - name: build
      image: ${REGISTRY}/${USER}/operator-sdk-build-tools:latest
      workingDir: /workspace/source/
      securityContext:
        privileged: true
      env:
      - name: REGISTRY_AUTH_FILE
        value: /workspace/authjson/auth.json
      volumeMounts:
      - name: varlibcontainers
        mountPath: /var/lib/containers
      - name: authjson
        mountPath: /workspace/authjson
      command: ["/bin/bash" ,"-c"]
      args:
        - |-
          make docker-build IMG=\$(resources.outputs.builtimage.url)
    - name: push
      image: ${REGISTRY}/${USER}/operator-sdk-build-tools:latest
      workingDir: /workspace/source/
      securityContext:
        privileged: true
      env:
      - name: REGISTRY_AUTH_FILE
        value: /workspace/authjson/auth.json
      volumeMounts:
      - name: varlibcontainers
        mountPath: /var/lib/containers
      - name: authjson
        mountPath: /workspace/authjson
      command: ["/bin/bash" ,"-c"]
      args:
        - |-
          podman push --tls-verify=\$(params.TLSVERIFY) \$(resources.outputs.builtimage.url)
  volumes:
  - name: varlibcontainers
    persistentVolumeClaim:
      claimName: ${USER}-container-build
  - name: authjson
    configMap:
      name: authjson
EOF
```
Create a secret to pull images from the image registry:
```bash
$ oc create secret docker-registry regcred \
                    --docker-server=${REGISTRY} \
                    --docker-username=${USER} \
                    --docker-password=$(oc whoami -t) \
                    --docker-email=${USER}@devnull.com
```

Create a `ServiceAccount` to use the secret:
```bash
$ oc create -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${USER}-serviceaccount
secrets:
  - name: regcred
EOF
```
Link the secret to the default pull credentials:
```bash
$ oc secrets link ${USER}-serviceaccount regcred --for=pull
```

### Creating Operator-Bundle Images
### Creating an Index of Operators
## Create a Pipeline and PipelineRun
Create a pipeline as follows:
```bash
$ oc create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: ${USER}-build-hellogo-operator-pipeline
spec:
  resources:
  - name: source
    type: git
  - name: builtimage
    type: image
  tasks:
  - name: build-hellogo-operator
    taskRef:
      name: ${USER}-build-hellogo-operator-task
    resources:
      inputs:
        - name: source
          resource: source
      outputs:
        - name: builtimage
          resource: builtimage
EOF
```

Create a PipelineRun as follows:
```bash
$ oc create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: ${USER}-build-hellogo-operator-pipeline-run
spec:
  serviceAccountName: ${USER}-serviceaccount
  pipelineRef:
    name: ${USER}-build-hellogo-operator-pipeline
  resources:
    - name: source
      resourceRef:
        name: git-${USER}-hellogo-operator
    - name: builtimage
      resourceRef:
        name: image-${USER}-hellogo-operator
EOF
```
## Creating a Git Web Hook Trigger
## Test the Web Hook
