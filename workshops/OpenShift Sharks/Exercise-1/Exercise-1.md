# Building the image

I like to be prepared and have all the tools I need with me when I am debugging , for that I will use a centos:8 base 
image and install some CLI tools (even if some of them do not make sense).
first we need to build a small daemon to run in the background when the pod is running.

If you haven't already , make sure you configure the OCP_DOMAIN environment Variable is set
(from the workshop page Copy/Paste the Bastion Domain)

```bash
$ export OCP_DOMAIN="sandboxXXX.opentlc.com"
```

## Building the Images

```bash
$ mkdir ~/admin-tools
$ cd ~/admin-tools
```

We will build that small daemon first with a simple bush script :

```bash
$ cat > run.sh << EOF
#!/bin/bash
tail -f /dev/null
EOF
```

Make sure it is an executable :
```bash
$ chmod a+x run.sh
```

And now we need to build the image With A Dockerfile should look like this :
```bash
$ cat > Containerfile << EOF
FROM quay.io/centos/centos:stream9

MAINTAINER Red Hat Israel "Back to ROOT!!!!"
USER root

RUN dnf install -y iproute iputils tcpdump nmap-ncat wireshark-cli && dnf clean all
WORKDIR /opt/app-root/
COPY run.sh .
RUN useradd -u 1001 -g wireshark user
USER 1001

ENTRYPOINT ["/opt/app-root/run.sh"]
EOF
```

(this procedure will work with ubi8 and local repository as well):

```bash
# Option 1:
$ buildah bud -f Containerfile -t admin-tools

# Option 2:
$ podman build -f Containerfile -t admin-tools

```

Create a new namespace:
```bash
$ oc new-project admin-tools
```

Obtain your namespace
```bash
$ NAMESPACE=$(oc project -q) && echo $NAMESPACE
```

Now we need to push the image to a registry which is available:
```bash
$ HOST="default-route-openshift-image-registry.apps.cluster-${GUID}.${GUID}.${OCP_DOMAIN}"
$ REGISTRY="${HOST}/${NAMESPACE}"
$ echo $REGISTRY
$ podman tag localhost/admin-tools ${REGISTRY}/admin-tools
$ podman images | grep ${REGISTRY}/admin-tools
```

save everything to bashrc
```bash
$ echo "export NAMESPACE=$NAMESPACE" >> ~/.bashrc
$ echo "export HOST=$HOST" >> ~/.bashrc
$ echo "export REGISTRY=$REGISTRY" >> ~/.bashrc
```

Let’s login to the registry:
```bash
$ podman login -u $(oc whoami) -p $(oc whoami -t) $HOST
```

And push the image to the registry
```bash
$ podman push ${REGISTRY}/admin-tools
```

Once the process is complete we can use this image on a POD we want to debug.


Running the Pod

We will build a very small image to run as a Pod :

```bash

$ cat > Containerfile.minimal << EOF
FROM ubi9/ubi-minimal

WORKDIR /opt/app-root/
COPY run.sh /opt/app-root/run.sh
USER nobody

ENTRYPOINT ["/opt/app-root/run.sh"]
EOF
```

Let's build the Image 
```bash
$ buildah bud -f Containerfile.minimal -t ${REGISTRY}/ubi-minimal && buildah push ${REGISTRY}/ubi-minimal 
```

Now let's create the deployment :
```bash
$ oc create deployment ubi-minimal --image=${REGISTRY}/ubi-minimal --dry-run=client -o yaml
```
And apply it 
```bash
$ oc create deployment ubi-minimal --image=${REGISTRY}/ubi-minimal 
``` 

Before we move on to the debug let's see if we can run the "ip addr" command from the container.  
Let's run rsh to the container
```bash
$ oc rsh $(oc get pods -o name | grep ubi-minimal)
```

Now run the command :
```bash
$ ip addr 
$ exit
```

If you are getting an error (and you are) then that means that it can't find the ip binary in the container (because there is none)

Now let's try running the command in debug mode with our new image :

```bash
$ oc debug $(oc get pod -o name | grep minimal) --image=${HOST}/${NAMESPACE}/admin-tools
````

Once you are in debug mode you can see the IP of the Pod and run the tools we installed on it.

```bash
$ ip addr show
```

Now we can exit the debug mode :
```bash
$ exit
```

