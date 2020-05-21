# Exercise 1 - Building a GO application
## Content :

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
On your Linux Box :

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

The above commands should be run as the root user, or via sudo , so the Go installation can operate correctly.

## Creating a ‘Hello world’ app in Go

Go is easy to learn. You can write a main() function, compile, and run your app/

We’re going to write the most basic HTTP request response app, called Hello Go .

The design goal is simple:

  - Run a web server on port ${GO_PORT}.
  - For any request, return the content “Hello, you requested: URL_PATH_HERE”

First, create a new project directory, hello-go , with the following directory structure:

```bash
 hello-go/
        cmd/
          hello/
# mkdir -p hello-go/cmd/hello
```

And make sure we set the right variables we need :

```bash
# export USER_NUMBER=`echo $USER | sed 's/user//'`
# export GO_PORT=”80${USER_NUMBER}”
# echo $GO_PORT
```

Now, inside the hello directory, create the file hello.go with the following Go code:

    
```bash
    package main
    import (
            "fmt"
            "log"
            "net/http"
     )

     // HelloServer responds to requests with the given URL path.
     func HelloServer(w http.ResponseWriter, r *http.Request) {
               fmt.Fprintf(w, "Hello, you requested: %s\n", r.URL.Path)
               log.Printf("Received request for path: %s", r.URL.Path)
     }
     func main() {
               var addr string = ":GO_PORT"
               handler := http.HandlerFunc(HelloServer)
               if err := http.ListenAndServe(addr, handler); err != nil {
                        log.Fatalf("Could not listen on port %s %v", addr, err)
               }
     }
```

Change the GO_PORT to you GO_PORT number 

This is all that’s needed to generate an HTTP server responding on port $GO_PORT. In the

main function, Go’s http.ListenAndServe() listens on the given network address

( addr ), and routes incoming requests through the handler ( handler ).

Our HelloServer handler responds to any request by printing “Hello, you requested: %s”, 

with the URL path replacing the %s placeholder. This is not an amazing HTTP server, and 

it doesn’t do a whole lot, but it is a full- fledged Go application, which can now be compiled into a binary.

## Building Hello Go

With the hello.go file saved, run the following command from the project’s root directory:

```bash
# go build cmd/hello/hello.go
```

After a couple seconds, you should see a new hello binary in the project’s root

directory. Run it by typing:

```bash
# ./hello
```

Now, **in another terminal (login again with ssh)** , run curl localhost:${GO_PORT} . You should see something like

the following:

     # curl localhost:${GO_PORT}
     Hello, you requested: /

And if you curl another path, like curl localhost:80${user number}/test, you’ll see:

     # curl localhost:${GO_PORT}/test
     Hello, you requested: /test

Amazing! A couple more hours and we’ll have implemented Apache in Go! You may also 

note that your original terminal window was logging your first curl:

     # ./hello
     2025/11/12 20:58:07 Received request for path: /
     2025/11/12 20:58:15 Received request for path: /test

It’s always nice to have applications log to standard output (stdout) and standard 

error (stderr), because in the cloud-native world, these logs are easy to route and 

store centrally. You can press Control + C to exit the Hello Go app; we’re going to 

work on running it in a container now, so we can get one step closer to running it 

in Kubernetes!

### Containerized Hello Go

First login to the registry

      # podman login registry.infra.local:5000
      Username: myuser
      Password: mypassword
      Login Succeeded!

If we want it to be consistent through this session (change user01 and the password from the file) :

     # REG_SECRET=`echo -n 'myuser:mypassword' | base64 -w0`

And now create and update the ~/.docker/config.json file :

    # mkdir ~/.docker
    # echo '{ "auths": {}}' | jq '.auths += {"registry.infra.local:5000": \
    {"auth": "REG_SECRET","email": "me@working.me"}}' | \
    sed "s/REG_SECRET/$REG_SECRET/" | jq . > ~/.docker/config.json

Hello Go isn’t very useful if you can only run it locally on your workstation. This app is stateless, it logs to stdout, and it fulfills a single purpose, so it is a perfect fit to containerize for a cloud-native deployment!

Building Go apps in Docker containers is easy. Go maintains a number of images on Docker Hub containing all the necessary tooling to build your app, and all you need to do is copy in the source and run go build.
It’s time to create a Dockerfile to instruct Docker how to build our Hello Go app container image.
Create a Dockerfile in the hello-go project’s root directory, and add the following:

    # cat > Dockerfile << EOF
    FROM ubi8/go-toolset as build

    WORKDIR /opt/app-root
    COPY cmd cmd
    RUN go build cmd/hello/hello.go
    EOF

If you’ve worked with Docker before, you might be wondering about the syntax of the first line.
The first line of a Dockerfile should define the base image for the Docker container. Here, we’re building from the golang library image using the ubi8/go-toolset  tag, which will give us the latest version in the Go 1.x series of images, based on Red Hat  Linux. But what about as build ? This portion of the FROM line allows a multi-stage build. If we just built our app inside the ubi8/go-toolset  image, we would end up with at least a 1.21 GB Docker image. For a tiny HTTP server app like Hello Go, that’s a lot of overhead!
Using a multi-stage build, we can build Hello Go in one container (named build using that as build statement), then copy Hello Go into a very small container for deployment.
Add the following to the same Dockerfile to complete the multi-stage build:


    # cat >> Dockerfile << EOF
    FROM ubi8/ubi-minimal

    WORKDIR /opt/app-root
    COPY --from=build /opt/app-root/hello /opt/app-root/hello

    EXPOSE ${GO_PORT}
    ENTRYPOINT ["./hello"]
    EOF

Building on the ubi8/ubi-minimal image will give us a final container image that’s only a 108 megabytes, which means it will be faster to upload into a container registry, and faster to pull when running it in Kubernetes.

#### What is UBI ?


We set the same workdir ( /opt/app-root ) as the build container, and then COPY the binary that
was built ( /opt/app-root/hello ) into the final deployment container.
Finally, we EXPOSE port ${GO_PORT}, since that’s the port our web server listens on, and then
we set the ENTRYPOINT to our hello binary, so Docker will run it as the singular
process in the container when running it with all the default settings.

### Building the container

Now we can build the container image. Run the following command inside the same
directory as the Dockerfile:

     # buildah bud -f Dockerfile -t hello-go .


After a couple minutes (or less if you already had the base images downloaded!), you should be able to see the hello-go container image when you run docker images :

     # podman image list
     REPOSITORY                                    TAG      IMAGE ID       CREATED       SIZE
     localhost/${USER}-hello-go                            latest   92310a101177   4 days ago    116 MB

Now we’ll run the container image to make sure Hello Go operates in the container identically to how it operated when run directly.
Running the container
To run the container and expose the internal port 8180 to your host, run the command:

     # podman run --name hello-go --rm -p ${GO_PORT}:${GO_PORT} hello-go

After a second or two, the web server should be operational. In another terminal, run:

     # curl localhost:${GO_PORT}/testing


And you should see the “Hello, you’ve requested: /testing” response in that window, as well as the logged request in the window where docker/podman run was executed.

     # podman run -d --name hello-go --rm -p ${GO_PORT}:${GO_PORT} hello-go
     2025/11/12 22:31:07 Received request for path: /testing

To stop and terminate the container, press Ctrl-C in the terminal where you ran
docker/podman run .

Clean you work :

     # podman stop hello-go 
     # podman rm hello-go

Push to the Registry
Only 2 more steps remaining , re tag our application :

     # podman tag localhost/hello-go registry.infra.local:5000/${USER}/hello-go 

Verify you image was successfully tagged :

     # podman image list 
     REPOSITORY                                   TAG      IMAGE ID       CREATED         SIZE
     registry.infra.local:5000/userxx/hello-go    latest   376409b93b2c   3 minutes ago   116 MB

And push it to the registry :

     # podman push  registry.infra.local:5000/${USER}/hello-go

Hello Go app summary
Many tools in the Kubernetes ecosystem are written in Go. You might not be a master of the Go language after building and running this app in a container, but you at least know the basics, and could even put ‘Go programmer’ on your resumé now (just kidding!).

