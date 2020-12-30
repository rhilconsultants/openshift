# Exercise 3 - Working with OC (Extra)

## table of content

  1. Updating the Application
  2. creating a ConfigMap
  3. updating a Deployment with a ConfigMap
  4. crating a secret
  5. updating the Deployment with a Secret

## Application update

Go to our Application Directory :

```bash
$ cd ~/hello-go
```

```bash
$ cat > index.html << EOF
This is our New File
EOF
```

And Now 

Let's update our application code which is in cmd/hello/hello.go with our new Code :

```go
package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

type Page struct {
	Title string
	Body  []byte
}

func loadPage(filename string) (*Page, error) {
	body, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	
	return &Page{Title: filename, Body: body}, nil
}

// HelloServer responds to requests with the given URL path.
func HelloServer(w http.ResponseWriter, r *http.Request) {

	fmt.Fprintf(w, "Hello, you requested: %s\n", r.URL.Path)
	log.Printf("Received request for path: %s", r.URL.Path)
}

func ReadFile(w http.ResponseWriter, r *http.Request) {
	h_workdir , found := os.LookupEnv("HELLO_WORKDIR")
	if !found {
		h_workdir = "/opt/app-root/"
	}

	file_name , f_found := os.LookupEnv("HELLO_FILENAME")
	if !f_found {
		file_name = "index.html"
	}

	h_workdir += "/" + file_name

	p, err := loadPage(h_workdir)

	if err != nil {
        p = &Page{ Title: file_name}
    }

    h_workdir += "index.html"
	fmt.Fprintf(w, "<h1>%s</h1><div>%s</div>", p.Title, p.Body)
}

func main() {
	port, found := os.LookupEnv("GO_PORT")
	if !found {
		port = "8080"
	}

	http.HandleFunc("/api/", HelloServer)
	http.HandleFunc("/readfile/", ReadFile)

	log.Printf("Starting to listen on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
```

We need to rebuild our container

```bash
$ buildah bud -f Dockerfile -t ${REGISTRY}/${NAMESPACE}/hello-go
$ buildah push ${REGISTRY}/${NAMESPACE}/hello-go
```
Now as you can see we change the file a little bit , Now there are 2 paths , one for the API and one for reading our File.

## ConfigMap

Many applications require configuration using some combination of configuration files, command line arguments, and environment variables. These configuration artifacts should be decoupled from image content in order to keep containerized applications portable.

The ConfigMap object provides mechanisms to inject containers with configuration data while keeping containers agnostic of OpenShift Container Platform. A ConfigMap can be used to store fine-grained information like individual properties or coarse-grained information like entire configuration files or JSON blobs.



The ConfigMap API object holds key-value pairs of configuration data that can be consumed in pods or used to store configuration data for system components such as controllers. ConfigMap is similar to secrets, but designed to more conveniently support working with strings that do not contain sensitive information.


First Let's create a ConfigMap in which our application will read from 

```bash
$ oc create configmap index-file --from-file=index.html
configmap/index-file created
```

And Make sure our ConfigMap was created.

```bash
$ oc get configmap
NAME         DATA   AGE
index-file   1      17s
```

Now that our new application is ready and our new file is ready Let's put them all together using our Deployment file

```bash
$ $ cd ~/YAML
$ cat > hello-go-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-go
  namespace: ${NAMESPACE}
spec:
  selector:
    matchLabels:
      app: hello-go
  replicas: 2
  template:
    metadata:
      labels:
        app: hello-go
    spec:
      containers:
        - name: hello-go
          image: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/hello-go
          ports:
            - containerPort: 8080
          env:
          - name: GO_PORT
            value: 8080
          - name: HELLO_WORKDIR
            value: '/opt/app-root/'
          - name: HELLO_FILENAME
            value: 'index.html'
          volumeMounts:
          - name: volume-index-html
            mountPath: /opt/app-root/index.html
            subPath: index.html
      volumes:
      - name: volume-index-html
        configMap:
          name: index-file
          items:
          - key: index.html
            path: index.html
EOF
```

and Apply it :

```bash
$ oc apply -f hello-go-deployment.yaml
```
Now Let's look at our application under the /readfile/ path ... do you see the configmap content ?

Now Let's update the ConfigMap :

```bash
$ oc get configmap index-file -o yaml > index-file.yaml
```

Now let's update the file with the number 2:

```bash
$ sed -i "s/New\ File/Good\ As\ New\ FIle/g" index-file.yaml
```

and now run an update
```bash
$ oc apply -f index-file.yaml
```

Delete the pod and then try the route again ... do you see your change ?

```bash
$ oc get pods -o name | grep hello-go | xargs oc delete
```

## Creating A secret



Some applications need sensitive information, such as passwords and user names, that you do not want developers to have.

As an administrator, you can use Secret objects to provide this information without exposing that information in clear text.


### Understanding secrets



The Secret object type provides a mechanism to hold sensitive information such as passwords, OpenShift Container Platform client configuration files, private source repository credentials, and so on. Secrets decouple sensitive content from the pods. You can mount secrets into containers using a volume plug-in or the system can use secrets to perform actions on behalf of a pod.

Key properties include:

    Secret data can be referenced independently from its definition.

    Secret data volumes are backed by temporary file-storage facilities (tmpfs) and never come to rest on a node.

    Secret data can be shared within a namespace.

First Let's generate the filename in base64

```bash
$ echo 'index.html' | base64 -w0 ; echo
aW5kZXguaHRtbAo=
```

Now we need to create A secret :

```bash
$ cat > file-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: file-secret
data:
  filename: aW5kZXguaHRtbAo=
EOF
```

and apply it :
```bash
$ oc apply -f file-secret.yaml
```

Now all we need to do is to add the relevant lines to our YAML file :
```bash
$ cat > hello-go-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-go
  namespace: ${NAMESPACE}
spec:
  selector:
    matchLabels:
      app: hello-go
  replicas: 2
  template:
    metadata:
      labels:
        app: hello-go
    spec:
      containers:
        - name: hello-go
          image: image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/hello-go
          ports:
            - containerPort: 8080
          env:
          - name: GO_PORT
            value: 8080
          - name: HELLO_WORKDIR
            value: '/opt/app-root/'
          - name: HELLO_FILENAME
            valueFrom:
              secretKeyRef:
                name: file-secret
                key: filename
          volumeMounts:
          - name: volume-index-html
            mountPath: /opt/app-root/index.html
            subPath: index.html
      volumes:
      - name: volume-index-html
        configMap:
          name: index-file
          items:
          - key: index.html
            path: index.html
EOF
```

And apply it for the last time today :
```bash
$ oc apply -f hello-go-deployment.yaml
```

That is it.
Restart the Pods and you are all Done with Exercise 3