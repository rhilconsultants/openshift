# prerequisites

In order to start working with OpenShift pipeline you Need to have the following basic skills :

  1. understanding of the English language.
  2. ability to view/edit YAML files
  3. basic understanding of OpenShift and OpenShift Objects


## OpenShift Cluster


### Bastion login

```bash
$ export UUID="" # ask the Instructor
$ export SANDBOX="" # ask the Instructor
USER #   ask the Instructor
$ ssh USER@bastion.$UUID.${SANDBOX}
```
### tmux

for those of you who don't know tmux in a very powerful tool which allows us to run terminal manipulation in various forms. In our case we would want to slip the screen to 3 parts (vertical middle and 2 horizontal on the top side) to enable us better monitoring on all the process.

Start a tmux session :

```bash
tmux new-session -s ocp
```

next we will split the screen by clicking on CTRL+a then '"'.  
Now we will Navigate to the top bar by CTRL+UP (the ARROW UP)  
and create another slip horizontally by running CTRL+a then "%"  
To navigate between them you can run CTRL+ARROW and the arrows.  

Once you have logged in to the Bastion server you can connect to the cluster :

### Cluster Login

```bash
$ oc login --username=${USER} --password='r3dh4t1!' --server=api.cluster-${UUID}.${UUID}.${SANDBOX}:6443
```

