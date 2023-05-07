Debugging latency issues

# Curl with TLS
In this Exercise We will use our curl image from our previous exercise and run Curl with an https connection.
during the run we will use a SSL key log file to save the key session. During the run we will create a network capture and use the SSH key log file in wireshark the see the capture in clear text.

## Modifying the deployment

in order to tell curl to save the SSL key log file we will setup an environment variable to save the key and where to save it.
as implied the variable name is SSLKEYLOGFILE and the value is the destination file.

In our deployment we will add those to the 'env' section :

```YAML
apiVersion: apps/v1 
kind: Deployment
metadata:
  labels:
    app: loop-curl-statistics
  name: loop-curl-statistics
spec:
  ...
    spec:
      containers:
      - env:
        - name: DESTINATION_URL
          value: 'https://www.google.com/'
        - name: TIME_INTERVAL
          value: '5' 
        - name: SSLKEYLOGFILE
          value: '/tmp/curlssl.key'
          ...
```

let's run the "oc edit" command to modify the YAML file :

```bash
$ oc get deployment | grep curl | cut -d " " -f 1 | xargs oc edit deployment
``` 

## Tapping

We will now use the ksniff module to create a PCAP file in regards to our curl container:
```bash
# oc sniff $(oc get pods | grep curl | awk '{print $1}') -f 'port 443' -p --image=$REGISTRY/admin-tools -o ~/pcap/google-ssl.pcap
```
Let's give it 10 seconds and stop the "oc sniff" command. (and kill the pod)

```bash
$ oc get pod | grep ksniff | cut -d " " -f 1 | xargs oc delete pod
```

## Traffic Analysis

### Load the SSL Log Key

First we need to copy the curlssl.key file from the container using "oc rsync"

### On OpenShift

#### rsync must be installed

The oc rsync command uses the local rsync tool if present on the client machine and the remote container.

If rsync is not found locally or in the remote container, a tar archive is created locally and sent to the container where the tar utility is used to extract the files. If tar is not available in the remote container, the copy will fail.

The tar copy method does not provide the same functionality as oc rsync. For example, oc rsync creates the destination directory if it does not exist and only sends files that are different between the source and the destination.
 

On WireShark go the preferences and in the Protocol Section search for SSL (TLS in a the new versions)
and set the SSL key log file : 

First let's get the pod name into a variable :
```bash
$ POD_NAME=$(oc get pods | grep curl | cut -d " " -f 1)
```

Now we will use the "oc rsync" to copy the ssl key we have create earlier :

```bash
$ oc rsync ${POD_NAME}:/tmp/curlssl.key ~/pcap/ 
```

## Local Desktop

Copy the 2 files to your local machine.

Now that we have the PCAP we can go ahead to wireshark and open it.

```
wireshark --> File --> Open (Select the google-ssl.pcap file)
```

And Set the SSL key with the following steps :

```
wireshark --> Edit/File/Option --> Preferences --> Protocol --> TLS/SSL
```

Now you should see the traffic in clear text.
