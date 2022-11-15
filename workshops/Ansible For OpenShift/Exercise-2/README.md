# Exercise 2

## Ansible Kubernetes Module
In This Exercise we will learn about the Ansible kubernetes Module.

The 3 way we are going to work with the module are :

- kubernetes.core.k8s
- kubernetes.core.k8s_info
- kubernetes.core.k8s_exec

### kubernetes.core.k8s Synopsis

- Use the Kubernetes Python client to perform CRUD operations on K8s objects.
- Pass the object definition from a source file or inline. See examples for reading files and using Jinja templates or vault-encrypted files.
- Access to the full range of K8s APIs.
- Authenticate using either a config file, certificates, password or token.
- Supports check mode.

### kubernetes.core.k8s_info Synopsis

- Use the Kubernetes Python client to perform read operations on K8s objects.
- Access to the full range of K8s APIs.
- Authenticate using either a config file, certificates, password or token.
- Supports check mode.
- This module was called k8s_facts before Ansible 2.9. The usage did not change.

### kubernetes.core.k8s_exec Synopsis

- Use the Kubernetes Python client to execute command on K8s pods.

## Running the Module

For the first exercise let's create a playbook that uses the kubernetes module to create our namespace
(Login to OpenShift if you haven't done so already!)

First let's recreate our inventory file :
```bash
$ cd ~/ose-ansible
$ cat >> inventory <<EOF
[localhost]
127.0.0.1 ansible_connection=local ansible_host=localhost ansible_python_interpreter=/usr/bin/python3
EOF
```

### Adding a Pod
and now we will create our mail.yaml playbook file to create our Pod :
```bash
$ cat > main.yaml << EOF
---
- name: Deploy the user application in our namespace
  hosts: localhost

  tasks:
  - name: create A Pod in our userspace
    kubernetes.core.k8s:
      definition:
        apiVersion: v1
        kind: Pod
        metadata:
          namespace: "{{ user_project }}"
          name: monkey-app 
          labels: 
            app: monkey-app
        spec:
          containers:
          - name: monkey-app
            image: quay.io/two.oes/monkey-app:latest
            ports:
            - containerPort: 8080
      state: present
EOF
```

**NOTE**

Note that we did not provide a name for our namespace but a variable which we are going to define in our inventory file.  

Add the following to our inventory file :
```bash
$ cat >> inventory <<EOF
[localhost:vars]
user_project=${USER}-project
EOF
```

Now when we run the ansible playbook the namespace will be created with the name we provide in our "user_project" variable.

Run the playbook :
```bash
$ ansible-playbook -i inventory main.yaml
```
Let's check if the Pod is running :
```bash
$ oc get pods
```

Now that we have a pod running we would like to add A route and a service :

### Adding a Service 

```bash
$ cat >> main.yaml << EOF

  - name: create A Service in our userspace
    kubernetes.core.k8s:
      definition:
      ( complete the next part on your own )
EOF
```

And run the ansible playbook again :

```bash
$ ansible-playbook -i inventory main.yaml
```

Now we have a pod and a service
```bash
$ oc get pods,svc
```

### Adding a Route
To make the service accessable from the outside we would create a route :

```bash
$ cat >> main.yaml << EOF

  - name: creating a route for our Monkey app
    kubernetes.core.k8s:
      definition:
        apiVersion: route.openshift.io/v1
        kind: Route
        metadata:
          name: monkey-app
          namespace: "{{ user_project }}"
        spec:
          port:
            targetPort: 8080
          to:
            kind: Service
            name: monkey-app
            weight: 100
          wildcardPolicy: None
      state: present
EOF
```

and run the ansible playbook once again :

```bash
$ ansible-playbook -i inventory main.yaml
```

Let's see that we have everything in place :
```bash
$ oc get pods,svc,route
```

Now test our results let's greb the route and run an API query with curl to see if everything is in place :

```bash
$ ROUTE=$(echo -n 'http://' && oc get route monkey-app -o jsonpath='{ .spec.host }'
$ curl -H "Content-Type: application/json" ${ROUTE}/api/?says=banana
```

### Create the Role

Now that we have everything in place let's take everything , create a role and switch it to a role.

First we need to create the role 
```bash
$ ansible-galaxy init --init-path roles monkey-app
```

#### Role templates :

When we create a role the commands creates for us a set of libraries that are helping us figure what goes where.  
Once we ran the command we would want to take the Pod, Servive and route YAML configuration and pass it to a template so we can call the template upon usage.

Create a new file named pod.yaml.j2 and input the Pod configuation to it :
```bash
$ cat > roles/monkey-app/templates/pod.yaml.j2 << EOF
apiVersion: v1
kind: Pod
metadata:
  name: monkey-app 
  labels: 
    app: monkey-app
spec:
  containers:
  - name: monkey-app
    image: quay.io/two.oes/monkey-app:latest
    ports:
    - containerPort: 8080
EOF
```

Now modify the main.yml file which is located in the tasks directory.
```bash
$ cat > roles/monkey-app/tasks/main.yml << EOF
- name: set the monkey app Pod to present
  kubernetes.core.k8s:
    state: "{{ status }}"
    definition: "{{ lookup('template', 'pod.yaml.j2') | from_yaml }}"
    namespace: "{{ namespace }}"
EOF
```

Now do the same for both the service and the route.  
Once you complete it modify the playbook main.yaml file to referance the role :

```bash
$ cat > main.yaml << EOF
---
- name: Run the hellogo image
  hosts: localhost
  roles:
  - monkey-app
EOF
```

As you can see the state referce to a status variable. Under the defaults directory there is a file named main.yml which holds all the defaults with the variable and it's value

Let's modify the main.yml file :
```bash
$ cat >> roles/monkey-app/defaults/main.yml << EOF
status: present
EOF
```

Now run the playbook again (nothing should change ):
```bash
$ ansible-playbook -i inventory main.yaml
```

Now Let's change the status from "present" to "absent" and see what will happened (Do not try this at home)
```bash
$ ansible-playbook -i inventory main.yaml
```

Everything got deleted !!!

Change it back to present and run the playbook again so we will have resources to work with :)

### kubernetes.core.k8s_info module

Up until now we only used the kubernetes.core.k8s module for create/delete our resource.With the kubernetes.core.k8s_info module we can query then
and register the output into a variable.

Let's create a new directory under our home directory named "ose-info" and create a new playbook from there

From your Home Directory
```bash
$ mkdir ~/ose-info && cd ~/ose-info
$ cat >> inventory <<EOF
[localhost]
127.0.0.1 ansible_connection=local ansible_host=localhost ansible_python_interpreter=/usr/bin/python3
EOF
```

Now let's create a playbook file with the k8s_info module :
```bash
$ cat > main.yaml << EOF
---
- hosts: localhost
  gather_facts: false

  tasks:
  - name: getting the route
    kubernetes.core.k8s_info:
      api_version: v1
      kind: Route
      name: monkey-app
      namespace: ${USER}-project
    register: route_url

  - name: printing the route
    ansible.builtin.debug:
      msg: "{{ route_url.resources[0].spec.host }}"
EOF
```

Now let's run it and see the route host being printed at the end of the playbook.
```bash
$ ansible-playbook -i inventory main.yaml
```

### kubernetes.core.k8s_exec module

**(Open Task)**
In this exercise deploy a new Pod with the ubi8/ubi-minimal image and run an "echo" command once the pod is running
the Task should look as follow :
```bash
- name: Execute a echo command
  kubernetes.core.k8s_exec:
    namespace: ${USER}-project
    pod: my-minimal
    command: echo "hello world"
```

Good Luck !!!