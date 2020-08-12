# prerequisites

Before we start we need to download the right tools in order to work with Tekton  
The 2 tools are
  - oc - in order to login to the cluster
  - tkn - the tekton cli tool which is been used to easy create objects related to Openshift pipeline

## Downloads
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

Now that we have the 2 tools we need we start using them or ....  
Let's build a container which holds the 2 tools and we are going to use the container to run a pod and connect to is so we will be able to use the tools from it 

First let's create the directory

    # mkdir ~/ubi-pipeline
    # cd ~/ubi-pipeline

Copy the 2 binaries we need to our new directory

    # cp ~/bin/oc ~/bin/tkn .

Now we will craete a simple endless command to run in the background so the image will not fail.

    # cat > run.sh << EOF
    #!/bin/bash
    tail -f /dev/null
    EOF

and we will make it executable 

    # chmod a+x run.sh

Now create a Dockerfile and copy the binaries to the new image

    # cat > Dockerfile << EOF
    FROM ubi8/ubi-minimal
    USER ROOT
    COPY run.sh /opt/root-app/
    COPY tkn oc /usr/bin
    USER 1001
    ENTRYPOINT ["/opt/root-app/run.sh"]
    EOF

Once we've done that we can go ahead and create our image :

    # buildah bud -f Dockerfile -t ubi-pipeline .

set your OpenShift cluster Prefix and you current namespace:

    # export CLUSTER="ocp4.example.com"
    # export NAMESPACE=$(oc project -q)

Now that we have our image we need to TAG it and push it to our registry

    # podman tag localhost/ubi-pipeline default-route-openshift-image-registry.apps.${CLUSTER}/${NAMESPACE}/ubi-pipeline

    # podman push default-route-openshift-image-registry.apps.${CLUSTER}
    (You may need to login before you can push)

All that is left is to create a deployment for our image :

    #cat > deployment.yaml << EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ubi-pipeline
    spec:
      selector:
        matchLabels:
          app: ubi-pipeline
      replicas: 1
      template:
        metadata:
          labels:
            app: ubi-pipeline
        spec:
          containers:
            - name: ubi-pipeline
              image: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/ubi-pipeline
    EOF

And deploy it :

    # oc create -f deployment.yaml

After the deployment we can use the web console to login or use the oc command to get the pod terminal access

    # oc get pods -n $NAMESPACE -o name | grep ubi-pipeline | xargs oc rsh -n $NAMESPACE

Once we are in the Terminal We are ready to Start :)