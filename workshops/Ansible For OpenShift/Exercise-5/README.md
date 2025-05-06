# Exercise 5 - building and Ansible Operator

## Contents

* Operator-SDK
  * Download the Operator-SDK Binary
* WorkFlow
* Creating an Operator
* Building the Ansible Role
* Building and Running the Operator
  * Build and Push the Image
  * Install the CRD
  * Ways to Run an Operator
  * Deploy the Operator
* Using the Operator
* Testing
* Custom Variables
  * 'extra vars' are passed via the spec
  * Accessing CR Fields
* Removing hellogo from the Cluster
  * Delete CRs
  * Delete the Operator
* Extra Tasks

## Operator-SDK
Until now we worked with containers, Ansible and the Ansible module for Kubernetes (k8s). Now it’s time to bring it all together.

### Download the Operator-SDK Binary
#### Download from the Workshop Repository
```bash
$ mkdir -p ${HOME}/bin
$ cp /usr/share/workshop/operator-sdk* ${HOME}/bin/operator-sdk
$ chmod +x ${HOME}/bin/operator-sdk
```
#### Alternative - Download From the Web
If your instructor did not download the operator-sdk to /usr/share/workshop/ you can download the binary from the Internet:
```bash
$ mkdir ${HOME}/bin
$ export ARCH=$(case $(arch) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(arch) ;; esac)
$ export OS=$(uname | awk '{print tolower($0)}')
$ export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/latest/download
$ curl -Lo ${HOME}/bin/operator-sdk ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
$ chmod a+x ${HOME}/bin/operator-sdk
```

Now make sure you are using the right operator-sdk:
```bash
$ which operator-sdk
```
The output should be:
```
 ~/bin/operator-sdk
 ```
If the output is deferent just update the PATH environment variable :
```bash
$ export PATH="${HOME}/bin:${PATH}"
$ echo 'export PATH="${HOME}/bin:${PATH}"' >> ~/.bashrc
```

## WorkFlow

The SDK provides workflows to develop operators in Go, Ansible, or Helm. In this tutorial we will be focusing on Ansible.
The following workflow is for a new Ansible operator:

  - Create a new operator project using the SDK Command Line Interface (CLI)
  - Write the reconciling logic for your object using Ansible playbooks and roles
  - Use the SDK CLI to build and generate the operator deployment manifests
  - Optionally add additional CRD’s using the SDK CLI and repeat steps 2 and 3

## Creating an Operator
First lets create a project with our new tool. We’ll be building a Hello-go Ansible Operator for the remainder of this tutorial:
```bash
$ cd ~/ose-openshift
$ mkdir ${USER}-hellogo-operator && cd ${USER}-hellogo-operator
$ operator-sdk init --plugins=ansible --domain=example.com
$ operator-sdk create api --group monkey --version=v1alpha1 --kind=${USER^}monkey --generate-role
```
Now let’s look at the directory structure of our new object:
```bash
$ tree
    .
├── config
│   ├── crd
│   │   ├── bases
│   │   │   └── monkey.example.com_user1monkeys.yaml
│   │   └── kustomization.yaml
│   ├── default
│   │   ├── kustomization.yaml
│   │   ├── manager_auth_proxy_patch.yaml
│   │   └── manager_config_patch.yaml
│   ├── manager
│   │   ├── kustomization.yaml
│   │   └── manager.yaml
│   ├── manifests
│   │   └── kustomization.yaml
│   ├── prometheus
│   │   ├── kustomization.yaml
│   │   └── monitor.yaml
│   ├── rbac
│   │   ├── auth_proxy_client_clusterrole.yaml
│   │   ├── auth_proxy_role_binding.yaml
│   │   ├── auth_proxy_role.yaml
│   │   ├── auth_proxy_service.yaml
│   │   ├── kustomization.yaml
│   │   ├── leader_election_role_binding.yaml
│   │   ├── leader_election_role.yaml
│   │   ├── role_binding.yaml
│   │   ├── role.yaml
│   │   ├── service_account.yaml
│   │   ├── user1monkey_editor_role.yaml
│   │   └── user1monkey_viewer_role.yaml
│   ├── samples
│   │   ├── kustomization.yaml
│   │   └── monkey_v1alpha1_user1monkey.yaml
│   ├── scorecard
│   │   ├── bases
│   │   │   └── config.yaml
│   │   ├── kustomization.yaml
│   │   └── patches
│   │       ├── basic.config.yaml
│   │       └── olm.config.yaml
│   └── testing
│       ├── debug_logs_patch.yaml
│       ├── kustomization.yaml
│       ├── manager_image.yaml
│       └── pull_policy
│           ├── Always.yaml
│           ├── IfNotPresent.yaml
│           └── Never.yaml
├── Dockerfile
├── Makefile
├── molecule
│   ├── default
│   │   ├── converge.yml
│   │   ├── create.yml
│   │   ├── destroy.yml
│   │   ├── kustomize.yml
│   │   ├── molecule.yml
│   │   ├── prepare.yml
│   │   ├── tasks
│   │   │   └── user1monkey_test.yml
│   │   └── verify.yml
│   └── kind
│       ├── converge.yml
│       ├── create.yml
│       ├── destroy.yml
│       └── molecule.yml
├── playbooks
├── PROJECT
├── requirements.yml
├── roles
│   └── user1monkey
│       ├── defaults
│       │   └── main.yml
│       ├── files
│       ├── handlers
│       │   └── main.yml
│       ├── meta
│       │   └── main.yml
│       ├── README.md
│       ├── tasks
│       │   └── main.yml
│       ├── templates
│       └── vars
│           └── main.yml
└── watches.yaml
```

**Note**
As a convention, when creating Ansible operators, Ansible YAML files use a `.yml` suffix whereas Kubernetes/OpenShift assets use a `.yaml` suffix.

To test the operator on OpenShift we will use a different user named `{USER}-client`.


## Building the Ansible Role

Now that the skeleton files have been created, we can take the role files from Exercise-3 and apply them using the Operator.

First let’s take the templates file from our previous exercise and change the name to: '{{ ansible_operator_meta.name }}-monkey'

```bash
sed "s/monkeyapp/\'\{\{\ ansible_operator_meta\.name\ \}\}-monkeyapp\'/"\
 ../roles/monkey-app/templates/deployment.yaml.j2 \
 > 
```