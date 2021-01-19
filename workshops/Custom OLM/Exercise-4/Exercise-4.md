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
$ # Your instructor may need to run the following:
$ oc -n openshift-marketplace cp $(oc get pods -n openshift-marketplace | awk '/redhat-marketplace.*Running/{print $1}'):/bin/opm opm
$ # copy the opm file to the ~/buildimage directory
$ chmod +x opm
$ cat > Dockerfile <<EOF
FROM quay.io/podman/stable:latest
RUN yum -y install make && yum clean all
COPY opm /bin/opm
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

## Persistent Volume
We will create a persistent volume claim (PVC) to store temporary artifacts. This will speed up consecutive builds by storing needed images locally.
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

## Registry Secret
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

## Create a ServiceAccount and Pull Secret
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
## Pipeline Resources
### Git Pipeline Resource
Create a `PipelineResource` for the source code in the Git repository by running:
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
### Operator Image Pipeline Resource
Create a PipelineResource of type image for the operator's image:
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
#### Operator Bundle Image Pipeline Resource
Create a PipelineResource of type image for the operator bundles's image:
```bash
$ oc apply -f - <<EOF
apiVersion: tekton.dev/v1alpha1
kind: PipelineResource
metadata:
  name: image-${USER}-hellogo-operator-bundle
spec:
  type: image
  params:
    - name: url
      value: ${REGISTRY}/${USER}/hellogo-operator-bundle:v1.2.3
EOF
```

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
      - name: builtoperatorimage
        type: image
      - name: builtoperatorbundleimage
        type: image
  steps:
    - name: build-operator
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
          make docker-build IMG=\$(resources.outputs.builtoperatorimage.url)
    - name: push-operator
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
          podman push --tls-verify=\$(params.TLSVERIFY) \$(resources.outputs.builtoperatorimage.url)
    - name: build-bundle
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
          pwd;ls -ltr
          make bundle-build BUNDLE_IMG=\$(resources.outputs.builtoperatorbundleimage.url)
    - name: push-bundle
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
          podman push --tls-verify=\$(params.TLSVERIFY) \$(resources.outputs.builtoperatorbundleimage.url)
  volumes:
  - name: varlibcontainers
    persistentVolumeClaim:
      claimName: ${USER}-container-build
  - name: authjson
    configMap:
      name: authjson
EOF
```

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
  - name: builtoperatorimage
    type: image
  - name: builtoperatorbundleimage
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
        - name: builtoperatorimage
          resource: builtoperatorimage
        - name: builtoperatorbundleimage
          resource: builtoperatorbundleimage
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
    - name: builtoperatorimage
      resourceRef:
        name: image-${USER}-hellogo-operator
    - name: builtoperatorbundleimage
      resourceRef:
        name: image-${USER}-hellogo-operator-bundle
EOF
```
## Creating a Git Web Hook Trigger
## Test the Web Hook
