# Generate curl statistics 

In some cases during our work over Kubernetes Infrastructure we need to run a response test over HTTP to see how long does the response takes to complete.
for that purpose we need a simple command line tools such as CURL.
In sort , cURL is a command-line tool for getting or sending data including files using URL syntax. Since cURL uses libcurl, it supports every protocol libcurl supports.

## Where to Begin ?

we want the cURL binary available on our Kubernetes/OpenShift environment and for that we need an image that will contain it. Locally Red Hat Provides use with a ubi-minimal image that comes with curl

We need to tell it the format of the output we want to have. The output will go to STDOUT so we do not need persistent storage for this deployment.

## Statistics file

The curl binary can get an argument which points to a statics format file with the “-w” argument.
As stated in the man page :
-w, — write-out <format>
Make curl display information on stdout after a completed transfer. The format is a string that may contain plain text mixed with any number of variables. The format can be specified as a literal “string”, or you can have curl read the format from a file with “@filename” and to tell curl to read the format from stdin you write “@-”.

## Running on Kubernetes

In some cases running the command once it not enough, you want to create a graph out of those statistics , in order to do that we need to run the script in a loop or through Conman Gate Interface Binary (E.G cgi-bin)

### running in a loop

The script is a basically a shell script so we can build a loop with our favorite shell and run the curl command in it.

In our home dir 
```bash
$ mkdir ~/curl-statistics
$ cd ~/curl-statistics
```

Let’s go ahead and create the format file. First create the file named loop_curl_statistics.txt

```bash
$ touch loop_curl_statistics.txt
```

Next give it the following content :

```bash
$ cat > loop_curl_statistics.txt << EOF
     time_namelookup:  %{time_namelookup}s\n
        time_connect:  %{time_connect}s\n
     time_appconnect:  %{time_appconnect}s\n
    time_pretransfer:  %{time_pretransfer}s\n
       time_redirect:  %{time_redirect}s\n
  time_starttransfer:  %{time_starttransfer}s\n
                     ----------\n
          time_total:  %{time_total}s\n
EOF
```

Now let’s use it as a test run :

```bash
$ curl -w "@loop_curl_statistics.txt" -o /dev/null -s "http://google.com/"
```

A good output from out test should be something like :

```bash
     time_namelookup:  0.091651s
        time_connect:  0.152425s
     time_appconnect:  0.000000s
    time_pretransfer:  0.152458s
       time_redirect:  0.000000s
  time_starttransfer:  0.232729s
                     ----------
          time_total:  0.232847s
```

For our example I am going to use BASH scripting :

```bash
$ echo '#!/bin/bash
           
if [[ -z $DESTINATION_URL ]]; then
   echo "No DESTINATION_URL variable was defined"
   exit 0;                                      
fi         
  
if [[ -z $TIME_INTERVAL ]]; then 
    echo "No TIME_INTERVAL variable is set" 
    exit 1;                                 
fi          
  
while true; do
    curl -w "@/opt/app-root/loop_curl_statistics.txt" -o /dev/null -s "$DESTINATION_URL"
    sleep $TIME_INTERVAL                                             
done                    
' > run.sh
```

Now that the script is in place let’s make it executable :

```bash
$ chmod a+x run.sh
```

In our test case we would want to run this loop with in an OpenShift (Or Kubernetes) Cluster to check external service. In order to achieve that we need to run the script in a pod and make sure we give in all the needed environment variables.

In our example we may want to change the loop_curl_statistics.txt file as we go without rebuild the image every time. for that we will create it as a configMap file and make sure it is mounted for our pod deployment.


```bash
$ oc create configmap loop-curl-statistics --from-file=loop_curl_statistics.txt=loop_curl_statistics.txt
```

Now let’s create an image for our Pod to use. We will start with the Containerfile :

```bash
$ cat > Containerfile.loop << EOF
FROM ubi8/ubi-minimal

COPY run.sh /opt/app-root/ 
RUN chmod a+x /opt/app-root/run.sh

ENTRYPOINT ["/opt/app-root/run.sh"]
CMD ["/opt/app-root/run.sh"] 
EOF
```

And let’s go ahead and build the image

```bash
$ buildah bud -f Containerfile.loop -t loop-curl-statistics
STEP 1/5: FROM ubi8/ubi-minimal
Resolved "ubi8/ubi-minimal" as an alias (/etc/containers/registries.conf.d/000-shortnames.conf)
Trying to pull registry.access.redhat.com/ubi8-minimal:latest...
Getting image source signatures
Copying blob dde93efae2ff done  
Copying blob 94249d6f79d2 done  
Copying config 30557e4f1c done  
Writing manifest to image destination
Storing signatures
STEP 2/5: COPY run.sh /opt/app-root/ 
STEP 3/5: RUN chmod a+x /opt/app-root/run.sh
STEP 4/5: ENTRYPOINT ["/opt/app-root/run.sh"]
STEP 5/5: CMD ["/opt/app-root/run.sh"] 
COMMIT curl-statistics
Getting image source signatures
Copying blob 54e42005468d skipped: already exists  
Copying blob 0b911edbb97f skipped: already exists  
Copying blob 9db4ab7518b5 done  
Copying config 7ddc792ffa done  
Writing manifest to image destination
Storing signatures
--> 7ddc792ffa2
Successfully tagged localhost/loop-curl-statistics:latest
7ddc792ffa2144dc2e010527bcaf831fdea89390ace7bac46430000f9952631a
```

Once the process is complete you can make sure you see the image :

```bash
$ podman image list | grep loop-curl-statistics
localhost/loop-curl-statistics                   latest      7ddc792ffa21  13 seconds ago  104 MB
```

Re Tag it and push in to your registry 
```bash
$ podman tag localhost/loop-curl-statistics:latest ${REGISTRY}/loop-curl-statistics:latest
$ podman push ${REGISTRY}/loop-curl-statistics:latest
```

Now that the image and the configMap are in our registry we can go ahead and build our deployment.
First create the following file :

```bash
$ cat > loop-curl-deployment.yaml << EOF 
apiVersion: apps/v1 
kind: Deployment
metadata:
  labels:
    app: loop-curl-statistics
  name: loop-curl-statistics
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loop-curl-statistics
  template:
    metadata:
      labels:
        app: loop-curl-statistics
    spec:
      containers:
      - env:
        - name: DESTINATION_URL
          value: 'https://www.google.com/'
        - name: TIME_INTERVAL
          value: '5' 
        image: ${REGISTRY}/loop-curl-statistics:latest
        imagePullPolicy: Always
        name: loop-curl-statistics
        volumeMounts:
        - mountPath: /opt/app-root/loop_curl_statistics.txt
          name: loop-curl-statistics
          subPath: loop_curl_statistics.txt
      volumes:
      - name: loop-curl-statistics
        configMap:
          defaultMode: 420
          items:
          - key: loop_curl_statistics.txt
            path: loop_curl_statistics.txt
          name: loop-curl-statistics
EOF
```

and deploy it :
```bash
$ oc apply -f loop-curl-deployment.yaml
```

Now to view our statistics we can run the logs command and see the results :
```bash
$ oc logs $(oc get pods -o name | grep loop-curl-statistics)
```
In our example we will use it to display the latency