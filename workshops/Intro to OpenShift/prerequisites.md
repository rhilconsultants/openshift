# prerequisites

In order to start working with OpenShift pipeline you Need to have the following basic skills :

  1. understanding of the English language.
  2. ability to view/edit YAML files
  3. basic understanding of OpenShift and OpenShift Objects


## OpenShift Cluster



### Bastion login

```bash
$ export OCP_UUID="" # ask the Instructor  
$ ssh bastion.$UUID.example.opentlc.com:6443
```

### Cluster Login

```bash
$ oc login api.cluster-${UUID}.${UUID}.example.opentlc.com:6443
```

### tmux

for those of you who don't know tmux in a very powerful tool which allows us to run terminal manipulation in various forms. In our case we would want to slip the screen to 3 parts (vertical middle and 2 horizontal on the top side) to enable us better monitoring on all the process.

Here is how we do it :

first modify the tmux configuration file :

```bash
cat > ~/.tmux.conf << EOF
unbind C-b
set -g prefix C-a
bind -n C-Left select-pane -L
bind -n C-Right select-pane -R
bind -n C-Up select-pane -U
bind -n C-Down select-pane -D
EOF
```

now start a tmux session :

```bash
tmux new-session -s tkn
```

next we will split the screen by clicking on CTRL+a then '"'.  
Now we will Navigate to the top bar by CTRL+UP (the ARROW UP)  
and create another slip horizontally by running CTRL+a then "%"  
To navigate between them you can run CTRL+ARROW and the arrows.  

now you are ready for work :)  


