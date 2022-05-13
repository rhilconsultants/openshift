# portcheck

A simple Pod that get API POST request with port type and number with a target's IP address and checks if the destination port is available 


## Getting started

There are a few ways of using the tool , I will try to go over all the posibilities for both connected and disconnected environment. 

#### Environment Variables

Both packages has environment variables :

##### portcheck

  * PORT_NUMBER - set the number of port portcheck will open a listening socket on 

##### Spearedge

  * PORT_NUMBER - set the number of port spearedge will open a listening socket on 
  * INTERVAL_TIME - the number of seconds before spearedge will check the new Pod IP Address (Default : 10)
  * DST_NAMESPACE - the Namespace name on which the portcheck pod will be deployed (Need to setup the role an rolebinding accordingly)
  * POD_IMAGE - the the portcheck pod image to use when deploying the POD (this option is very useful for disconnected environments)

### Connected environment

For a Connected Environment you can use the portcheck tool directly (with a deamonset deployment) or you can use it with spearedge which allows you to set one which host the Pod will be created and run the test from.



#### Steps 

The first step is to clone the git repository :

    # git clone https://gitlab.com/two.oes/portcheck.git

And now create the namespce for our pods 

    # kubectl create ns port-check

Next we can go to Deployment and then we can do one of the 2

##### Only portcheck

To run portcheck alone all we need to do is to deploy the daemonset , the reason that this is a daemonset is that we want to make sure the test is available from all the nodes (the workers).  

To Deploy the daemonset all we need to do is to run :

    # kubectl apply -f portcheck/Deployment/portcheck-daemonset.yaml

And then Apply the Service :

    # kubectl apply -f portcheck/Deployment/portcheck-svc.yaml

In order for the service to be availble from outside of the cluster we need to create a route/ingress resource :

    # kubectl apply -f portcheck/Deployment/portcheck-route.yaml

And That is it !!!  
If you want to test it you can use the on of my test scripts :

    # export MY_URL="<the route URL>"
    # export REMOTE_HOST="<Remote FQDN>/portcheck"
    # export REMOTE_PROTO=tcp
    # export DST_PORT="<port number>"
    # ./portcheck/test/test_portcheck.sh

I recommand testing it with both an Open port and a closed one to see the different results


##### Using spearedge 

Speardge is a service that listen (as portcheck) to remote port , remote host and protocol but it also expect a hostname for one of the worker of the cluster.
The main Idea is to tell it on which node (worker) should the Pod sprone up and then run a test from that node.
In case we want to know which nodes are available on the cluster we can run a listnodes request 

In order to deploy it first we need to deploy the role , role binding and the service account for spearedge :

For the listnodes option :

    # kubectl apply -f portcheck/Deployment/clusterRole-listNodes.yaml
    # kubectl apply -f portcheck/Deployment/clusterRoleBinding.yaml
    # kubectl apply -f portcheck/Deployment/serviceaccount.yaml

And to allow it to create the portcheck pod :

    # kubectl apply -f portcheck/Deployment/role-pods.yaml
    # kubectl apply -f portcheck/Deployment/rolePodBinding.yaml

Now we need to deploy the deployment :

    # kubectl apply -f portcheck/Deployment/spearedge-deployment.yaml

And the Service

    # kubectl apply -f portcheck/Deployment/spearedge-svc.yaml

Same as for the portcheck deployment , we need to expose the service for out of the cluster :

    # kubectl apply -f portcheck/Deployment/spearedge-route.yaml


Now you can list the nodes in the cluster :

    # curl -s https://$(oc get route spearedge -o jsonpath='{.spec.host}')/listnodes

Select on of the nodes and run the test :

    # export MY_URL="https://$(oc get route spearedge -o jsonpath='{.spec.host}')/checkport"
    # export REMOTE_HOST="<Remote host>"
    # export DST_PORT="<Destination Port>"
    # export OCP_HOSTNAME="<one of the cluster workers>"
    # export REMOTE_PROTO=tcp
    # ./test/test_spearedge.sh

If you want to use it with a Web interface for delegation you can write it and just run the POST request from A web form


### Disconnected environment

For Disconnected environment we can do a few steps.

First save the 2 images:

    # podman save registry.gitlab.com/two.oes/portcheck/portcheck -o portcheck.tar
    # podman save registry.gitlab.com/two.oes/portcheck/spearedge -o spearedge.tar

Now you can take it (with the git repository) to the disconnected environment 

#### What to change ?

##### Only Portcheck

For portcheck only just update the image referance in the portcheck-daemonset.yaml file

##### Using spearedge

In the spearedge deployment you can change the image reference and change the environment variable that points to the portcheck
Image which it needs to pull.


Have Fun !!!
