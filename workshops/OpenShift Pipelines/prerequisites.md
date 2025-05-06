# Prerequisites

In order to start working with OpenShift pipeline you Need to have the following basic skills:

1. Ability to view/edit YAML files
1. Basic understanding of OpenShift and OpenShift objects (CRDs)


## OpenShift Cluster

## OpenShift Pipeline tools   

Before we start we need to download the right tools in order to work with Tekton.
The 2 tools are
  - oc - used to to login to the cluster
  - tkn - the Tekton CLI tool which is used to create objects related to Openshift pipelines


### Downloads

First create the ${HOME}/bin Directory

    # mkdir ${HOME}/bin
    # export PATH="${HOME}/bin:${PATH}"
    # echo 'export PATH="${HOME}/bin:${PATH}"' >> ~/.bashrc

To download `oc` we need to do is to download the latest `oc` binary with the following command:

    # export OCP_RELEASE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt \
    | grep 'Name:' | awk '{print $NF}')
    # wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-${OCP_RELEASE}.tar.gz
    # tar -xzf openshift-client-linux-${OCP_RELEASE}.tar.gz -C ~/bin/

Now download the `tkn` tool in a similar manner:

    # TKN_VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/sha256sum.txt \
    | grep tkn-linux-amd64 | awk -F \- '{print $4}' | sed 's/.tar.gz//g')
    # wget https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/tkn-linux-amd64-${TKN_VERSION}.tar.gz
    # tar -zxvf tkn-linux-amd64-${TKN_VERSION}.tar.gz -C ~/bin/

Now that we have the tools that we need let's start using them.

### Auth Complete

In order to utilize the bash auto completion in our environment we need to run a few simple commands which are part of the package itself.  

to generate it just run the following command:

    # oc completion bash > ~/.bash_completion
    # tkn completion bash >> ~/.bash_completion

** Now logout, login and test the command with the TAB key **

### Cluster login

The Instractor will provide the Cluster details 

    # export OCP_DOMAIN="????"
    # export OCP_CLUSTER="???"
    # oc login api.$OCP_CLUSTER.$OCP_DOMAIN:6443

### tmux

For those of you who don't know tmux in a very powerful tool which allows us to run terminal manipulation in various forms. In our case we would want to slip the screen to 3 parts (vertical middle and 2 horizontal on the top side) to enable us better monitoring on all the process.

Here is how we do it:

First modify the tmux configuration file as follows:

    # cat > ~/.tmux.conf << EOF
    unbind C-b
    set -g prefix C-a
    bind -n C-Left select-pane -L
    bind -n C-Right select-pane -R
    bind -n C-Up select-pane -U
    bind -n C-Down select-pane -D
    EOF

Now start a tmux session:

    # tmux new-session -s tkn

#### Spliting the screen (NOT Mandatory)

Next we will split the screen by clicking on CTRL+a then '"'.  
Now we will Navigate to the top bar by CTRL+UP (the ARROW UP)  
and create another slip horizontally by running CTRL+a then "%"  
To navigate between them you can run CTRL+ARROW and the arrows.  

Now you are ready for work :)  

#### Suggestion

In Exercise 1, on the top left run watch for `taskrun` and on the right run watch for `tasks`:

    # watch -n 1 "oc get taskrun"
    # watch -n 1 "oc get tasks"

In the reset of the Exercises watch `pipelinerun` instead of `tasks`:

    # watch -n 1 "oc get pipelinerun"

