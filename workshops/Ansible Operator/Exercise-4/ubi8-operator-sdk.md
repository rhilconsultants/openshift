# UBI Container with operator-sdk

Create a base directory for our container :

    # cd $HOME && mkdir ubi8-operator-sdk && cd ubi8-operator-sdk

Now build a small bash script with a loop

    # cat > run.sh << EOF
    #!/bin/bash
    tail -f /dev/null
    EOF

Now make is executable :

    # chmod a+x run.sh

Copy the operator-sdk to the current directory

    # cp ${HOME}/bin/operator-sdk .

And Now create the Dockerfile :

    # cat > Dockerfile << EOF
    FROM ubi8/ubi-minimal
    MAINTAINER me@working.me

    USER root
    WORKDIR /opt/app-root/

    COPY run.sh .
    COPY operator-sdk /usr/bin/

    CMD ["/opt/app-root/run.sh"]
    EOF

Run the build :

    # buildah bud -f Dockerfile -t ubi8/ubi-operator-sdk .

Now we can use the operator-sdk from the container :

    #  podman run -d --rm --name operator-sdk -v \
    ${HOME}/ubi8-operator-sdk:/opt/app-root/src:Z,rw ubi8/ubi-operator-sdk

Now login to the pod :

    # podman exec -it operator-sdk /bin/bash

And you Are good to go 

(you can run the same process with the oc command and use it to manage your namespace)

