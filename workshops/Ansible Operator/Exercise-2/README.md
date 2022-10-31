
# Exercise 2 - Ansible Container 


## Contents
   
* Ansible Container
  * Log in to OpenShift
  * Download the ose-ansible Image
  * Ansible Image Testing
  * Running the Container 
  * Ansible Kubernetes Module
  * Running the k8s Ansible Modules Locally



## Ansible Container

In today’s world it is much easier to just run a container then to install an application on our laptops, for that reason Red Hat has developed a container for running Ansible with the Kubernetes module.

### Ansible Image Testing

Now that we obtain the image that we need, let's run it with a small test run to make sure everything is working properly:

#### Hello, Ansible!

At its most basic, Ansible can be used to run tasks on the same machine running the Ansible playbook, by running against localhost, and telling Ansible this is a “local” connection (Ansible defaults to trying to connect to any host—even localhost —via SSH).
Let’s start off writing a basic playbook, which will run the date command, store its result in a variable, and then print the result in a debug message.
Before writing the playbook, create a file named inventory to tell Ansible how to connect to localhost:

From your Home Directory
```bash
$ mkdir ~/ose-ansible && cd ~/ose-ansible
$ cat >> inventory <<EOF
[localhost]
127.0.0.1 ansible_connection=local ansible_host=localhost ansible_python_interpreter=/usr/bin/python3
EOF
```
Every playbook starts with a play, which is a root level list item, with at least one key, hosts. To run a playbook against the local machine, you can set the following line at the beginning of the playbook:
```yaml
---
- hosts: localhost
```
When connecting to localhost and running simple automation tasks, you should usually disable Ansible’s fact-gathering functionality. Often this is not needed and can save time in your playbook runs. When it is enabled, Ansible digs through the system and stores tons of environment information in variables before it begins running tasks.
So, to do this, the next line should be:
```yaml
gather_facts: false
```

Next up, we’re going to write our first-ever Ansible task, to run the date command and capture its output. the task is as follows:
```yaml
tasks:
  - name: Get the current date.
    command: date
    register: current_date
    changed_when: false
```
The tasks keyword should be on the same level as hosts, etc., and then all the tasks should be in a YAML list under tasks.
It’s best practice to name every task you write in Ansible. This serves two purposes:

  - The name serves as an inline comment describing the task in YAML.
  - The value of the name will be printed in Ansible’s output as the name of the task when it runs.

A name is not strictly required, but it’s a lot easier to debug your playbooks if you name things after what they are doing!
This first task uses Ansible’s command module, which takes the value of the command and runs it. So this would be the equivalent of running the date command on the command line.

The task also registers the returned value (and some other metadata) into a new variable current_date, and because we know running date will never change the state of the host it’s run on, we also add changed_when: false. This helps Ansible keep track of state. Later we will use this to our advantage!
Let’s add just one more task that will print the date we saved. 

The playbook can be created by running the following command:
```yaml
$ cat > main.yaml << EOF
---
- hosts: localhost
  gather_facts: false

  tasks:
    - name: Get the current date.
      command: date
      register: current_date
      changed_when: false

    - name: Print the Current date.
      debug: msg="{{ current_date.stdout }}"
EOF
```

### Create an ose-ansible Image

We are going to create a New Image of ose-ansible by building an image with the appropriate package along with a small shell script to define the variables and run the playbook 

Now Create a shell script :
```bash
$ echo '#!/bin/bash

if [[ -z "$INVENTORY" ]]; then
  echo "No inventory file provided (environment value INVENTORY)"
  INVENTORY=/etc/ansible/hosts
else
  export INVENTORY=${INVENTORY}
fi

if [[ -z "$OPTS" ]]; then
  echo "no OPTS option provided (OPTS environment value)"
else
  export OPTS=${OPTS}

fi 

if [[ -z $"$PLAYBOOK_FILE" ]]; then
  echo "No Playbook file provided... exiting"
  exit 1
else
   ansible-playbook $PLAYBOOK_FILE
fi' > run-ansible.sh
```

Make it As executable :

```bash
$ chmod a+x run-ansible.sh
```

#### the Dockerfile 

Let’s create a new Dockerfile and edit it:
```bash
FROM python:3.8-slim

# RUN adduser --disabled-password -u 1001 --home /opt/app-root/ slim

ENV HOME=/opt/app-root/ \
    PATH="${PATH}:/root/.local/bin"
RUN mkdir -p /opt/app-root/src
COPY run-ansible.sh /usr/bin/

RUN pip install pip --upgrade
RUN pip install ansible 

LABEL \
        name="openshift/ose-ansible" \
        summary="OpenShift's installation and configuration tool" \
        description="A containerized ose-openshift image to let you run playbooks" \
        url="https://github.com/openshift/openshift-ansible" \
        io.k8s.display-name="openshift-ansible" \
        io.k8s.description="A containerized ose-openshift image to let you run playbooks on OpenShift" \
        io.openshift.expose-services="" \
        io.openshift.tags="openshift,install,upgrade,ansible" \
        com.redhat.component="aos3-installation-container" \
        version="v4" \
        release="8" \
        architecture="x86_64" \
        atomic.run="once" \
        License="GPLv2+" \
        vendor="Slim" \
        io.openshift.maintainer.product="OpenShift Container Platform" \
        io.openshift.build.commit.id="f65cc700d2483fd9a485a7bd6cd929cbb111111" \
        io.openshift.build.source-location="https://github.com/openshift/openshift-ansible"

WORKDIR /opt/app-root/

ENTRYPOINT [ "/usr/bin/run-ansible.sh" ]
CMD [ "/usr/bin/run-ansible.sh" ]
```
Build the container:

```bash
$ buildah bud -f Dockerfile -t ${REGISTRY}/${USER}/ose-ansible .
```

If everything went well, you should see the new image in your registry:
```bash
$ podman images
```

### Running the Container 

Now that we have our files in place lets make sure the Ansible container can run with our newly created files:
```bash
$ podman run --rm --name ose-ansible -tu `id -u` \
-v ${HOME}/ose-ansible/inventory:/tmp/inventory:Z,ro  \
-e INVENTORY_FILE=/tmp/inventory \
-e OPTS="-v"  \
-v ${HOME}/ose-ansible/:/opt/app-root/ose-ansible/:Z,ro \
-e PLAYBOOK_FILE=/opt/app-root/ose-ansible/main.yaml \
${REGISTRY}/${USER}/ose-ansible
```
Expected Output: 

    PLAY [localhost] *****************************************************************************************************************************************************************************
    
    TASK [Get the current date.] *****************************************************************************************************************************************************************
    Thursday 23 April 2020  20:05:45 +0000 (0:00:00.159)       0:00:00.159 ******** 
    ok: [127.0.0.1] => {"changed": false, "cmd": ["date"], "delta": "0:00:00.004917", "end": "2020-04-23 20:05:45.917910", "rc": 0, "start": "2020-04-23 20:05:45.912993", "stderr": "", "stderr_lines": [], "stdout": "Thu Apr 23 20:05:45 UTC 2020", "stdout_lines": ["Thu Apr 23 20:05:45 UTC 2020"]}
    
    TASK [Print the Current date.] ***************************************************************************************************************************************************************
    Thursday 23 April 2020  20:05:45 +0000 (0:00:00.413)       0:00:00.572 ******** 
    ok: [127.0.0.1] => {
        "msg": "Thu Apr 23 20:05:45 UTC 2020"
    }
    
    PLAY RECAP ***********************************************************************************************************************************************************************************
    127.0.0.1                  : ok=2    changed=0    unreachable=0    failed=0   

## Ansible Kubernetes Module

Now that we are able to run Ansible from our container let’s switch our focus to the Ansible Kubernetes module (k8s).

### Running the k8s Ansible Modules Locally

For this example we will create and delete a namespace with the switch of an Ansible variable.
First we need to create a rule for our Kubernetes cluster:
```bash
$ mkdir ~/ose-openshift && cd ~/ose-openshift
```

Now we will create a playbook.yaml file.
```yaml
$ cat > playbook.yaml <<EOF
---
- name: Run the hellogo image
  hosts: localhost
  roles:
  - Hello-go-role
EOF
```

Now we will create the role directory generate skeleton files:
```bash
$ mkdir roles
$ ansible-galaxy init --init-path roles Hello-go-role
```
The output should be:
```
- Role Hello-go-role was created successfully
```

Modify tasks file Hello-go-role/tasks/main.yml to contain the Ansible shown below:
```yaml
$ cat > roles/Hello-go-role/tasks/main.yml <<EOF
---
- name: set a configmap to test credentials 
  k8s:
    definition:
      apiVersion: v1
      data:
        Dockerfile: ""
      kind: ConfigMap
      metadata:
        name: dockerfile
        namespace: project-${USER}
EOF
```

Build the inventory file for this playbook:
```bash
$ cat >> inventory <<EOF
[localhost]
127.0.0.1 ansible_connection=local
EOF
```

Run playbook.yml, which will execute 'Hello-go-role':
```bash
$ podman run --rm --name ose-openshift -tu `id -u` \
-v $HOME/ose-openshift/inventory:/tmp/inventory:Z,ro  \
-e INVENTORY_FILE=/tmp/inventory \
-e OPTS="-v" \
-v $HOME/ose-openshift/:/opt/app-root/ose-ansible/:Z,ro \
-e PLAYBOOK_FILE=/opt/app-root/ose-ansible/playbook.yaml \
${REGISTRY}/${USER}/ose-ansible
```

#### ERROR !!
Whoops! The output will be similar to the following:
```
fatal: [127.0.0.1]: FAILED! => {"changed": false, "error": "No module named kubernetes", "msg": "Failed to import the required Python library (openshift) on 5601abe6115c's Python /usr/bin/python. Please read module documentation and install in the appropriate location. If the required library is installed, but Ansible is using the wrong Python interpreter, please consult the documentation on ansible_python_interpreter"}
```

What is the root cause of this error? We'll discuss a solution in the next section.

