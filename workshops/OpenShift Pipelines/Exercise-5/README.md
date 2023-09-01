# Exercise 5

## Before we Begin

In this Exercise we will create a Custom Image module and use it in a pipeline(Task).
The Object of the Exercise is to show how simple it is to create a new image module and start using within the pipeline so we will have a good showcase to our customers how easy it is to create a new module.  

### The Exercise use case 

In this case we will create a Custom image which we will use as our module image. In our case we will use the tools we had downloaded in our prerequisites section in order to create and deploy a simple application (the monkey-app) with a listener to our Monkey git repository which we will eventually are creating a full CI/CD for our Monkey application 

## Creating an ArgoCD Instance
From the OpenShift web console, in the `Administrator` tab, select `Installed Operators` from the `Operators` drop down.  Press on the `Red Hat Openshift GitOps` link and then press `All instances`. On the `Create new` drop down select `Argo CD`:
<img alt="create new ArgoCD Instance" src="create-new-argocd.jpg" width="100%" height="100%">

Press the `Form view` "Configure via" radio button.
Scroll down to the `Rbac` section and set the `Policy` to:
```
g,system:authenticated,role:admin
```
as follows:
 <img alt="ArgoCD Rbac policy" src="argocd-rbac-policy.jpg" width="100%" height="100%">

<!--
Note that on your work cluster, you should create a role for users that can create ArgoCD `Applications`.
-->

Scroll to the bottom and press the `Create` button.

Wait for the `Status` to show `Phase Available` and then verify that all `pods` have the ready status of `1/1 Running`.

Find the `Route` to Argo CD buy running the following command on the CLI:
```bash
oc get route argocd-server -o jsonpath='{"http://"}{.status.ingress[0].host}{"\n"}'
```

Browse to the address in your browser using the `https` protocol. You should see the following:
<img alt="ArgoCD login screen" src="argocd-login-screen.jpg" width="100%" height="100%">

Press the `LOG IN VIA OPENSHIFT` button and log in with your assigned OpenShift account and password.

<!--
### ArgoCD CLI Installation
The `argocd` CLI for Linux can be downloaded as follows:
```bash
curl -kLO $(oc get route argocd-server -o jsonpath='{"https://"}{.status.ingress[0].host}{"\n"}')/download/argocd-linux-amd64
chmod +x argocd-linux-amd64
mv argocd-linux-amd64 ~/bin/argocd
```
For other platforms, download the `argocd` CLI using instructions at [https://argo-cd.readthedocs.io/en/stable/cli_installation/](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

### ArgoCD CLI Login
Log in to our own instance of `ArgoCD` by running the following (a web browser instance will open):
```bash
argocd login --sso --insecure --grpc-web  $(oc get route argocd-server -o jsonpath='{.status.ingress[0].host}{"\n"}')
```

openssl s_client -showcerts -connect gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//"):443 < /dev/null 2>/dev/null | openssl x509 -outform PEM  | argocd cert add-tls --insecure gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//")

-->
### Certificate for Gitea (self-signed certificate)
```bash
openssl s_client -showcerts -connect gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//"):443 < /dev/null 2>/dev/null | openssl x509 -outform PEM > gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//")
```
Create a patch for the existing `ConfigMap` named `argocd-tls-certs-cm.yaml`:
```bash
oc create configmap argocd-tls-certs-cm --from-file gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//") --dry-run=client -o yaml > argocd-tls-certs-cm.yaml
```
Apply the patch to the `argocd-tls-certs-cm.yaml` `ConfigMap`:
```bash
oc patch configmap argocd-tls-certs-cm --patch-file argocd-tls-certs-cm.yaml
```
### ArgoCD Credentials for our Git Repository
Create a `Secret` with credentials for our Git repository by running the following in a `bash` shell:
```bash
oc create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitea
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//")
  password: openshift
  username: $(oc whoami)
EOF
```

### ArgoCD Application

Let's create an ArgoCD application that will periodically check our deployment repository, compare it with the deployment running in the cluster and update the cluster instance if necessary.

Run the following command in a `Bash` shell to create a file named `application.yaml`:
```bash
cat <<EOF > application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: httpserver
spec:
  project: default
  destination:
    namespace: $(oc whoami)
    server: 'https://kubernetes.default.svc'
  source:
    path: .
    repoURL: 'https://gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//")/$(oc whoami)/httpserver-cd.git'
    targetRevision: HEAD
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

Review the file `application.yaml`. What values will you need to change for your work environment?

Create the ArgoCD application by running:
```bash
oc create -f application.yaml
```

The `Application` should appear in the OpenShift GitOps (ArgoCD) web console.

Now let's make a change in our Exercise-3 application. In the file `src/main/java/demo/HTTPServerDemo.java` add the following before the line `server.start();`:
```
System.out.println("Starting the webserver!");
```
Save the changes, commit them to git and push them to the repository.

If you have not completed Exercise-4 manully create the `PipelineRun` that starts the build. This time, we will not enable the deployment in the `Pipeline`. Run the following in a `Bash` shell:
```bash
cat > ci-pipeline-run-no-deploy.yaml <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: ci-pipeline-run
spec:
  pipelineRef:
    name: ci-pipeline
  params:
    - name: git-source-url
      value: https://gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//")/$(oc whoami)/httpserver.git
    - name: git-cd-url
      value: https://gitea-demo-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//")/$(oc whoami)/httpserver-cd.git
    - name: image
      value: image-registry.openshift-image-registry.svc:5000/$(oc whoami)/httpserver
    - name: release-name
      value: httpserver
    - name: namespace
      value: $(oc whoami)
    - name: deploy
      value: false
  workspaces:
    - name: shared-data
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 5Gi
EOF
```
Start the `PipelineRun` as follows:
```bash
oc create -f ci-pipeline-run-no-deploy.yaml
```


After the build has completed, watch the `CURRENT SYNC STATUS` of the application in the ArgoCD web console. The `To HEAD` git has should change and the application should be updated with the latest image tag that was built.


# Congratulations

You have now completed the OpenShift Pipelines Workshop!
