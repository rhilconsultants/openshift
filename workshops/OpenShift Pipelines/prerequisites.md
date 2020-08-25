# prerequisites

In order to start working with OpenShift pipeline you Need to have the following basic skills :

  1. understanding of the English language.
  2. ability to view/edit YAML files
  3. basic understanding of OpenShift and OpenShift Objects


## OpenShift Cluster

## OpenShift Pipeline tools   

Before we start we need to download the right tools in order to work with Tekton  
The 2 tools are
  - oc - in order to login to the cluster
  - tkn - the tekton cli tool which is been used to easy create objects related to Openshift pipeline


### Downloads
  to download oc all we need to do is to download the latest oc binary with the following command :

    # export OCP_RELEASE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt \
    | grep 'Name:' | awk '{print $NF}')
    # wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux-${OCP_RELEASE}.tar.gz
    # tar -xzf openshift-client-linux-${OCP_RELEASE}.tar.gz -C ~/bin/

Now to download the tkn tool we can do it in the same matter

    # TKN_VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/sha256sum.txt \
    | grep tkn-linux | awk -F \- '{print $4}' | sed 's/.tar.gz//g')
    # wget https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/tkn-linux-amd64-${TKN_VERSION}.tar.gz
    # tar -zxvf tkn-linux-amd64-${TKN_VERSION}.tar.gz -C ~/bin/

Now that we have the 2 tools we need we start using them 

### Auth Complete

In order to utilize the bash auto completion in our environment we need to run a few simple commands which are part of the package itself.  

to generate it just run the following command :

    # mkdir ~/.bash_completion
    # oc completion bash > ~/.bash_completion/oc
    # tkn completion bash > ~/.bash_completion/oc

And let's make sure we can use it after we login :

    # echo 'source ~/.bash_completion/*' > ~/.bashrc

Now logout , login and test the command with the TAB key