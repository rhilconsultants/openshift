# Building the image

I like to be prepared and have all the tools I need with me when I am debugging , for that I will use a centos:8 base 
image and install some CLI tools (even if some of them do not make sense).
first we need to build a small daemon to run in the background when the pod is running.

```bash
# mkdir ~/admin-tools
# cd ~/admin-tools
```

We will build that small daemon first with a simple bush script :

```bash
# cat > run.sh << EOF
#!/bin/bash
tail -f /dev/null
EOF
```

Make sure it is an executable :
```bash
# chmod a+x run.sh
```

And now we need to build the image With A Dockerfile should look like this :
```bash
# cat > Containerfile << EOF
FROM quay.io/centos/centos:stream
MAINTAINER Red Hat Israel "Back to ROOT!!!!"
USER root

RUN dnf install -y curl tcpdump nmap-ncat wireshark-cli && dnf clean all
WORKDIR /opt/app-root/
COPY run.sh .
RUN gpasswd -a 1001 wireshark
USER nobody

ENTRYPOINT ["/opt/app-root/run.sh"]
RUN ["/opt/app-root/run.sh"]
EOF
```

(this procedure will work with ubi8 and local repository as well):
```bash
# buildah bud -f Dockerfile -t admin-tools
```

Obtain your namespace
```bash
# NAMESPACE=$(oc project -q)
```

Now we need to push the image to a registry which is available:
```bash
# HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
# REGISTRY="${HOST}/${NAMESPACE}"
# podman tag localhost/admin-tools ${REGISTRY}/admin-tools
```

Let’s login to the registry:
```bash
# podman login -u $(oc whoami) -p (oc whoami -t) $HOST
```

And push the image to the registry
```bash
# podman push ${HOST}/${NAMESPACE}/admin-tools
````

Once the process is complete we can use this image on the node we want to debug.
Running the image
Before we run the command we need to see on which IP address the node is listening on:
```bash
# oc get nodes -o wide
```

The Server IP should be on the Internal IP column so we can catch it with a simple grep and awk command with the node we want to debug:
```bash
# oc get nodes -o wide | grep <node> | awk '{print $6}'
```

Save the output a side (we will need it later).
Now we can run the debug with our new image :

```bash
# oc debug node/<node> --image=${HOST}/${NAMESPACE}/admin-tools
````

we can look interfaces with a simple ip command :
```bash
# ip addr show | grep -B2 <IP Address>
```

Now that we have the interface name we can start running the network debug on that interface.
```bash
# tshark -i <interface> 'tcpdump filgters'
```
