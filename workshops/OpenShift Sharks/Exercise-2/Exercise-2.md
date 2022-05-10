# oc with ksniff
Up until now we have worked on the node which is hosting the POD (A.K.A the underlay) 
but now we want see the traffic going over the POD 2 POD communication. 
For that we can run the debug command from the previous run or we can use ksniff/.
Ksniff for those among us who don’t know is a plug-in for kubectl/oc (and oc) 
which enables us to run an interface capture from the pod itself to our running terminal.


## Installing ksniff
The Install process is fairly simple , all we need to do it to download the zip file (the corrent version is 1.6)

```bash
# cd ~/bin/
# wget https://github.com/eldadru/ksniff/releases/download/v1.6.2/ksniff.zip
```

and then unzip it and install it with the make command :
```bash
# unzip ksniff.zip
```
NOTE!
In case you've downloaded the file to a different directory You need to copy the kubectl-sniff file to the oc directory 
(in our case $HOME/bin/) where the oc binary is located

## Usage 

```bash
oc sniff <POD_NAME> [-n <NAMESPACE_NAME>] [-c <CONTAINER_NAME>] [-i <INTERFACE_NAME>] [-f <CAPTURE_FILTER>] [-o OUTPUT_FILE] [-l LOCAL_TCPDUMP_FILE] [-r REMOTE_TCPDUMP_FILE]
```

* POD_NAME: Required. the name of the kubernetes pod to start capture it's traffic.
* NAMESPACE_NAME: Optional. Namespace name. used to specify the target namespace to operate on.
* CONTAINER_NAME: Optional. If omitted, the first container in the pod will be chosen.
* INTERFACE_NAME: Optional. Pod Interface to capture from. If omitted, all Pod interfaces will be captured.
* CAPTURE_FILTER: Optional. specify a specific tcpdump capture filter. If omitted no filter will be used.
* OUTPUT_FILE: Optional. if specified, ksniff will redirect tcpdump output to local file instead of wireshark. Use '-' for stdout.
* LOCAL_TCPDUMP_FILE: Optional. if specified, ksniff will use this path as the local path of the static tcpdump binary.
* REMOTE_TCPDUMP_FILE: Optional. if specified, ksniff will use the specified path as the remote path to upload static tcpdump to.

Piping output to stdout

By default ksniff will attempt to start a local instance of the Wireshark GUI. You can integrate with other tools using the -o - flag to pipe packet cap data to stdout.

Example using tshark:

```bash
# oc sniff <pod-name> -f "port 8080" -o - | tshark -r -
```

