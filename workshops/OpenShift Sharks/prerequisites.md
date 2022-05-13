# Prerequisites

In order to start working with OpenShift you Need to have the following basic skills:

1. Ability to view/edit YAML files
1. Basic understanding of OpenShift and OpenShift objects (CRDs)


## OpenShift Cluster

Login to our LAB bastion server using your SSH client (the username will be provided by the instracture)

## OpenShift tools   

Before we start we need to download the right tools in order to work.
The 2 tools are
  - oc - used to to login to the cluster
  - ksniff - will be presented in Exercise 2


### Downloads

First create the ${HOME}/bin Directory

```bash
$ mkdir ${HOME}/bin
$ export PATH="${HOME}/bin:${PATH}"
$ echo 'export PATH="${HOME}/bin:${PATH}"' >> ~/.bashrc
```

To download `oc` we need to do is to download the latest `oc` binary with the following command:

```bash
$ export OCP_RELEASE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt \
| grep 'Name:' | awk '{print $NF}')

$ echo $OCP_RELEASE
$ wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-${OCP_RELEASE}.tar.gz
$ tar -xzf openshift-client-linux-${OCP_RELEASE}.tar.gz -C ~/bin/
```
### oc bash auto completion

> In order to utilize the bash auto completion in our environment we need to run a few simple commands which are part of the package itself.  

To generate it just run the following command:

```bash
$ oc completion bash > ~/.bash_completion
```

**Now logout, login and test the command with the TAB key**

### Cluster login

> NOTE: The Instractor will provide the Cluster details

```bash
# export OCP_DOMAIN="????" ( example : sandbox661.opentlc.com )
# echo 'OCP_DOMAIN="???"' >> ~/.bashrc
# oc login api.cluster-${GUID}.${GUID}.$OCP_DOMAIN:6443
```

### tmux

For those of you who don't know tmux in a very powerful tool which allows us to run terminal manipulation in various forms. In our case we would want to slip the screen to 3 parts (vertical middle and 2 horizontal on the top side) to enable us better monitoring on all the process.

Here is how we do it:

First modify the tmux configuration file as follows:

```bash
$ cat > ~/.tmux.conf << EOF
unbind C-b
set -g prefix C-a
bind -n C-Left select-pane -L
bind -n C-Right select-pane -R
bind -n C-Up select-pane -U
bind -n C-Down select-pane -D
EOF
```
Now start a tmux session:

```bash
tmux new-session -s ocp
```

#### Spliting the screen (NOT Mandatory)

Now we will split the screen by clicking on CTRL+a then '"'.  
Next we will Navigate to the top bar by CTRL+UP (the ARROW UP) and create another slip horizontally by running CTRL+a then "%"  
To navigate between them you can run CTRL+ARROW and the arrows.  

Now you are ready for work :)  

#### Suggestion

In Exercise 1, on the top left run watch for `taskrun` and on the right run watch for `tasks`:

```bash
$ watch -n 1 "oc get pods"
$ watch -n 1 "oc get events"
```
