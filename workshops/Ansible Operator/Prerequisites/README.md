# Prerequisites - Workshop Configuration

## Setting up tmux

for those of you who don't know tmux in a very powerful tool which allows us to run terminal manipulation in various forms. In our case we would want to slip the screen to 3 parts (vertical middle and 2 horizontal on the top side) to enable us better monitoring on all the process.

Here is how we do it :

first modify the tmux configuration file :

```bash
$ cat > ~/.tmux.conf << EOF
unbind C-b
set -g prefix C-a
EOF
```

now start a tmux session :

```bash
$ tmux new-session -s ocp
```

next we will split the screen by clicking on CTRL+a then '"'.  
Now we will Navigate to the top bar by CTRL+a then UP (the ARROW UP)  
To navigate between them you can run CTRL+a followed by the ARROW you wish to go.   

## Logging in to OpenShift
First let’s log in to the cluster (login credentials placed in the sheets file under ocp user and ocp password):
```bash
$ export OCP_CLUSTER="" # Ask the Instructor 
$ export OCP_DOMAIN="" # Ask the Instructor 
$ oc login -u ${USER} api.$OCP_CLUSTER.$OCP_DOMAIN:6443
```

## Logging in to the Workshop Registry
Different registries are used in this workshop. Your instructor will direct you which of the steps in this section to follow to log in to the registry for this workshop.

### Logging in to the Internal OpenShift Registry
Log in to the internal OpenShift registry by running:
```bash
$ REGISTRY="default-route-openshift-image-registry.apps.$OCP_CLUSTER.$OCP_DOMAIN"
$ export REGISTRY_AUTH_FILE="~/.registry/auths.json"
$ mkdir -p ~/.registry/
$ echo '{"auths":{}}' > ~/.registry/auths.json
$ podman login -u $(oc whoami) -p $(oc whoami -t) ${REGISTRY}
```
The output should be:
```
Login Succeeded!
```

### Logging in to an External Registry
Your instructor will provide you with the name of the external registry. Log in to the registry as follows. Enter the password provided by the instructor:
```bash
$ REGISTRY=<name of registry provided by instructor>
$ podman login -u ${USER} ${REGISTRY}
```

## Configuring an Environment Variable
Create an environment variable for the registry that will be used in this workshop:
```bash
$ echo "export REGISTRY=${REGISTRY}" >> ~/.bashrc
$ echo "export OCP_CLUSTER=${OCP_CLUSTER}" >> ~/.bashrc
$ echo "export OCP_DOMAIN=${OCP_DOMAIN}" >> ~/.bashrc
$ source ~/.bashrc
```



