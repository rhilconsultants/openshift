# prerequisites

In order to start working with OpenShift pipeline you Need to have the following basic skills :

  1. understanding of the English language.
  2. ability to view/edit YAML files
  3. basic understanding of OpenShift and OpenShift Objects


## OpenShift Cluster

## OpenShift Pipeline tools   

Before we start we need to download the right tools in order to work with OpenShift
The tools name is oc


### Downloads

First create the ${HOME}/bin Directory

    # mkdir ${HOME}/bin
    # export PATH="${HOME}/bin:${PATH}"

To download oc all we need to do is to download the latest oc binary with the following command :

    # export OCP_RELEASE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt \
    | grep 'Name:' | awk '{print $NF}')
    # wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-${OCP_RELEASE}.tar.gz
    # tar -xzf openshift-client-linux-${OCP_RELEASE}.tar.gz -C ~/bin/


### Auth Complete

In order to utilize the bash auto completion in our environment we need to run a few simple commands which are part of the package itself.  

to generate it just run the following command :

    # oc completion bash > ~/.bash_completion

** Now logout , login and test the command with the TAB key **

### cluster login

    # export OCP_DOMAIN="infra.local"
    # export OCP_CLUSTER="ocp4"
    # oc login api.$OCP_CLUSTER.$OCP_DOMAIN:6443

### tmux

for those of you who don't know tmux in a very powerful tool which allows us to run terminal manipulation in various forms. In our case we would want to slip the screen to 3 parts (vertical middle and 2 horizontal on the top side) to enable us better monitoring on all the process.

Here is how we do it :

first modify the tmux configuration file :

    # cat > ~/.tmux.conf << EOF
    unbind C-b
    set -g prefix C-a
    bind -n C-Left select-pane -L
    bind -n C-Right select-pane -R
    bind -n C-Up select-pane -U
    bind -n C-Down select-pane -D
    EOF

now start a tmux session :

    #tmux new-session -s tkn

next we will split the screen by clicking on CTRL+a then '"'.  
Now we will Navigate to the top bar by CTRL+UP (the ARROW UP)  
and create another slip horizontally by running CTRL+a then "%"  
To navigate between them you can run CTRL+ARROW and the arrows.  

now you are ready for work :)  


