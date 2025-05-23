# oc with ksniff
Up until now we have worked on the node which is hosting the POD (A.K.A the underlay) 
but now we want see the traffic going over the POD 2 POD communication. 
For that we can run the debug command from the previous run or we can use [ksniff](https://github.com/eldadru/ksniff).
Ksniff for those among us who don’t know is a plug-in for kubectl/oc  
which enables us to run an interface capture from the pod itself to our running terminal.

## Installing ksniff
The Install process is fairly simple , all we need to do it to download the zip file (the corrent version is 1.6)

```bash
$ cd ~/bin
$ wget https://github.com/eldadru/ksniff/releases/download/v1.6.2/ksniff.zip
```

and then unzip it and install it with the make command :
```bash
$ unzip ksniff.zip
```
> **NOTE!** In case you've downloaded the file to a different directory you need to copy the kubectl-sniff file to the oc directory 
(in our case $HOME/bin/) where the oc binary is located

## Usage (Don't run , just review the options).

```bash
$ oc sniff <POD_NAME> 
            [-n <NAMESPACE_NAME>] 
            [-c <CONTAINER_NAME>] 
            [-i <INTERFACE_NAME>] 
            [-f <CAPTURE_FILTER>] 
            [-o OUTPUT_FILE] 
            [-l LOCAL_TCPDUMP_FILE] 
            [-r REMOTE_TCPDUMP_FILE]
```

* `POD_NAME`: **_Required_**. The name of the kubernetes pod to start capture its traffic.
* `NAMESPACE_NAME`: **_Optional_**. Namespace name. used to specify the target namespace to operate on.
* `CONTAINER_NAME`: **_Optional_**. If omitted, the first container in the pod will be chosen.
* `INTERFACE_NAME`: **_Optional_**. Pod Interface to capture from. If omitted, all Pod's interfaces will be captured.
* `CAPTURE_FILTER`: **_Optional_**. Specify a specific tcpdump capture filter. If omitted no filter will be used.
* `OUTPUT_FILE`: **_Optional_**. If specified, ksniff will redirect tcpdump output to local file instead of wireshark. Use '-' for stdout.
* `LOCAL_TCPDUMP_FILE`: **_Optional_**. If specified, ksniff will use this path as the local path of the static tcpdump binary.
* `REMOTE_TCPDUMP_FILE`: **_Optional_**. If specified, ksniff will use the specified path as the remote path to upload static tcpdump to.

### Piping output to stdout

By default ksniff will attempt to start a local instance of the Wireshark GUI. You can integrate with other tools using the `-o` switch to pipe packet cap data to stdout.

Example using tshark:

```bash
$ oc sniff $(oc get pods | grep minimal | awk '{print $1}') -f 'port 443' -p \
   --tcpdump-image=$REGISTRY/admin-tools --image=$REGISTRY/admin-tools -o - | tshark -r -
```

Run the command in oc debug
```bash
$ oc debug $(oc get pod -o name | grep minimal) --image=${HOST}/${NAMESPACE}/admin-tools
$ curl https://www.google.com
```

Run 
(quit and kill the snifff Pod)

### Save the output to a file

In case we want to save the capture to a file all we need to do is change the "-o -" to "-o filename.pcap"

First we will create a directory and change to it :

```bash
$ mkdir ~/pcap && cd ~/pcap/
```

Now let's run the save command with sniff but this time we will save it to a file :

```bash
$ oc sniff $(oc get pods | grep minimal | grep debug | awk '{print $1}') -f 'port 443' -p --image=$REGISTRY/admin-tools -o google.pcap 
```

One a new session (use tmux).
Run the debug again and try to running curl to google

```bash
$ oc debug $(oc get pod -o name | grep minimal) --image=${HOST}/${NAMESPACE}/admin-tools
$ curl https://www.google.com
```

If you see the google.pcap is bigger the zero then you are good to go (exit the debug and kill the sniff Pod)
(CTRL+C)

And kill the pod
```bash
$ oc get pod | grep ksniff | cut -d " " -f 1 | xargs oc delete pod 
```
Copy the file to your workstation (scp/winscp)

Open it with wireshark

```bash
$ wireshark -r google.pcap
```

Go over the lines a little bit and close it for now .
