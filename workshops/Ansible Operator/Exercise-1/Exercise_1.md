# Exercise 1 - Building and Containerizing a GO Application
## Content:

  - Installing GO LANG (SKIP…)
    - Package Based
    - Source Based
  - Creating a ‘Hello world’ app in Go   
  - Building Hello Go 
  - Containerized Hello Go    
  - Building the container    
  - Running the container   
  - Push to the Registry    
  - Hello Go app summary    
  - Rate Yourself

## Installing GO LANG 

### Package Base
To install Go, e.g. via Homebrew on macOS ( brew install go ), Chocolatey on Windows 

( choco install -y golang ), or via various third-party repositories via apt or yum ; 

as long as you can get a working Go installation, you should be able to compile the application we’ll build.
On your Linux computer:

```bash
# yum install -y golang.x86_64
```
### Source Base

Source Based
The official method of installing Go requires downloading the correct binary source package 

from the Go Downloads page20, then either running the installer (if downloading the macOS 

package or Windows MSI installer), or unpacking the archive into the directory /usr/local/go .

On a typical 64-bit Linux workstation, the process would be: 

```bash
# export VERSION=1.14
```
Download the Go archive.

```bash
# curl -O https://dl.google.com/go/go$VERSION.linux-amd64.tar.gz
```

Verify the SHA256 Checksum (against the downloads page).

```bash
# sha256sum go$VERSION.linux-amd64.tar.gz
```

Extract the tarball into the `/usr/local` directory.

```bash
# sudo tar -C /usr/local -xzf go$VERSION.linux-amd64.tar.gz
```

Add the Go binaries to your $PATH.

```bash
# export PATH=$PATH:/usr/local/go/bin
```

If you want the $PATH changes to persist, make sure to add them to shell profile (e.g. ∼/.profile ).

The above commands should be run as the root user, or via sudo, so the Go installation can operate correctly.

## Creating a ‘Hello world’ app in Go

Go is easy to learn. You can write a main() function, compile, and run your app/

We’re going to write the most basic HTTP request response app, called Hello Go .

The design goal is simple:

  - Run a web server on port ${GO_PORT}.
  - For any request, return the content “Hello, you requested: URL_PATH_HERE”

First, create a new project directory and change into its root:
```bash
# mkdir -p hello-go/cmd/hello
# cd hello-go
```
Inside the hello-go/cmd/hello directory, create a file named hello.go with the following Go code:

    
```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// HelloServer responds to requests with the given URL path.
func HelloServer(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello, you requested: %s\n", r.URL.Path)
	log.Printf("Received request for path: %s", r.URL.Path)
}

func main() {
	port, found := os.LookupEnv("GO_PORT")
	if !found {
		port = "8080"
	}
	handler := http.HandlerFunc(HelloServer)
	log.Printf("Starting to listen on port %s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Could not listen on port %s %v", port, err)
	}
}
```

In the main function, Go’s http.ListenAndServe() listens on the given port, and routes incoming requests through the handler.

Our HelloServer handler responds to any request by printing “Hello, you requested: %s”, with the URL path replacing the %s placeholder. This is not an amazing HTTP server, and 

it doesn’t do a whole lot, but it is a full- fledged Go application, which can now be compiled into a binary.

## Building the Hello Go Application

With the hello.go file saved, run the following command from the project’s root directory:

```bash
# go build cmd/hello/hello.go
```
After a couple seconds, you should see a new **hello** binary file in the project’s root directory.

## Runnng Hello Go
Before we run the **hello** program locally, we will set up a unique port variable based on your USER name offset by 8000, so that our usage does not conflict with other applications running on the same host:

```bash
# export GO_PORT="$(printf 80%02d ${USER#user})"
# echo $GO_PORT
```

Run the application as follows:

```bash
# ./hello
```

Now, **in another terminal (login again with ssh)**, run:
```bash
# export GO_PORT="$(printf 80%02d ${USER#user})"
# curl http://localhost:${GO_PORT}
 ```
You should see the following:
```
Hello, you requested: /
```

And if you curl another path:
```bash
curl http://localhost:${GO_PORT}/test
```
you’ll see:
```
Hello, you requested: /test
```

Amazing! 

You may also note that your original terminal window is logging your curl requests:
```bash
# ./hello
2025/11/12 20:58:00 Starting to listen on port ${GO_PORT}
2025/11/12 20:58:07 Received request for path: /
2025/11/12 20:58:15 Received request for path: /test
```

It’s always nice to have applications log to standard output (stdout) and standard error (stderr), because in the cloud-native world, these logs are easy to route and store centrally. You can press Control + C to exit the Hello Go application.

We’re now going to work on running it in a container, so we can get one step closer to running it in Kubernetes!

## Containerized Hello Go


### Building the Hello Go Application in as a Container Image
Hello Go isn’t very useful if you can only run it locally on your workstation. This app is stateless, it logs to stdout, and it fulfills a single purpose, so it is a perfect fit to containerize for a cloud-native deployment!

Building Go apps in Docker containers is easy. Go maintains a number of images on Docker Hub containing all the necessary tooling to build your app, and all you need to do is copy in the source and run go build.
It’s time to create a Dockerfile to instruct Docker how to build our Hello Go app container image.
Create a Dockerfile in the hello-go project’s root directory, and add the following:
```bash
# cat > Dockerfile << EOF
FROM ubi8/go-toolset as build

WORKDIR /opt/app-root
COPY cmd cmd
RUN CGO_ENABLED=0 go build -ldflags="-w -s" cmd/hello/hello.go
EOF
```

If you’ve worked with Docker before, you might be wondering about the syntax of the first line.
The first line of a Dockerfile should define the base image for the Docker container. Here, we’re building from the golang library image using the ubi8/go-toolset  tag, which will give us the latest version in the Go 1.x series of images, based on Red Hat  Linux. But what about as build ? This portion of the FROM line allows a multi-stage build. If we just built our app inside the ubi8/go-toolset  image, we would end up with at least a 1.21 GB Docker image. For a tiny HTTP server app like Hello Go, that’s a lot of overhead!
Using a multi-stage build, we can build Hello Go in one container (named build using that as build statement), then copy Hello Go into a very small container for deployment.
Append the following to the same Dockerfile to complete the multi-stage build:

```bash
# cat >> Dockerfile << EOF
FROM scratch

COPY --from=build /opt/app-root/hello /bin/hello

EXPOSE 8080
ENTRYPOINT ["/bin/hello"]
EOF
```

Building a stand-alone Go image as above will give us a final container image that’s only a 6 megabytes, which means it will be faster to upload into a container registry, and faster to pull when running it in Kubernetes.

#### What is UBI?


We set the same workdir ( /opt/app-root ) as the build container, and then COPY the binary that
was built ( /opt/app-root/hello ) into the final deployment container.
Finally, we EXPOSE port 8080, as it will be the port our web server listens on, and then
we set the ENTRYPOINT to our hello binary, so Docker will run it as the sole
process in the container when running it with all the default settings.

### Building and Run the Container

Now we can build the container image. Run the following command inside the same
directory as the Dockerfile:
```bash
# buildah bud -f Dockerfile -t hello-go .
```
After a couple minutes (or less if you already had the base images downloaded!), you should be able to see the hello-go container image when you run docker images:
```bash
# podman images
REPOSITORY                                    TAG      IMAGE ID       CREATED       SIZE
localhost/hello-go                            latest   92310a101177   4 days ago    5.43 MB
```

Now we’ll run the container image to make sure Hello Go operates in the container identically to how it operated when run directly.
Running the container
To run the container and expose the internal port to your host, run the command:
```bash
# export GO_PORT="$(printf 80%02d ${USER#user})"
# podman run --name hello-go --rm -p ${GO_PORT}:8080 hello-go
```

After a second or two, the web server should be operational. In another terminal with the environment variable GO_PORT specified, run:
```bash
# export GO_PORT="$(printf 80%02d ${USER#user})"
# curl http://localhost:${GO_PORT}/testing
```

And you should see the following response:
```
Hello, you’ve requested: /testing
```
As well as the logged request in the window where container run was executed.
```
2025/11/12 22:31:00 Starting to listen on port 8080
2025/11/12 22:31:07 Received request for path: /testing
```

To stop and terminate the container, press Ctrl-C in the terminal where you ran
docker/podman run .

Clean up your work
```bash
# podman stop hello-go 
```

## Push to the Registry
First let’s make sure we are logged in to the cluster (login credentials placed in the sheets file under ocp user and ocp password):
```bash
# oc login api.ocp4.infra.local:6443
```

For this exercise, we will use OpenShift's internal registry. We will define an environment variable with the registry's host name:
```bash
# export REGISTRY="$(oc get route/default-route -n openshift-image-registry -o=jsonpath='{.spec.host}')"
```

### Configuring Access to the Registry


Now log in to the registry, providing your username and password:
```bash
# podman login -u unused -p $(oc whoami -t) ${REGISTRY}
```
The output should be:
```
Login Succeeded!
```

### Tag the Application for Our Project
Tag our application:
```bash
# podman tag localhost/hello-go ${REGISTRY}/$(oc project -q)/hello-go
```

Verify that your image was successfully tagged:
```bash
# podman images
REPOSITORY                                   TAG      IMAGE ID       CREATED         SIZE
${REGISTRY}/project-userNN/hello-go    latest   376409b93b2c   3 minutes ago   5.43 MB
```
### Push the Image
Push the image to the registry:
```bash
# podman push ${REGISTRY}/$(oc project -q)/hello-go
```

## Hello Go Application Summary
Many tools in the Kubernetes ecosystem are written in Go. You might not be a master of the Go language after building and running this application in a container, but you at least know the basics, and could even put ‘Go programmer’ on your resumé now (just kidding!).

