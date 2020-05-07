
# Exercise 2 - Ansible container 


## Contents

  - Ansible Container
  - Download
  - Image Testing
  - Hello, Ansible!
  - Running the Container
  - Kubernetes Module
  - Running the k8s Ansible modules locally
  - Please select a number for each task    


##Ansible Container

In today’s world it is much easier to just run a container then to install an application on our Laptops , for that reason Red Hat has developed 2 containers for running ansible with the Kubernetes module.

### Download

To obtain the package run the following command  :

    # podman pull registry.infra.local:5000/openshift3/ose-ansible

### Image Testing

Now that we obtain the Image we need , lets run it with a small test run to make sure everything is working properly:

#### Hello, Ansible!

At its most basic, Ansible can be used to run tasks on the same machine running the Ansible playbook, by running against localhost , and telling Ansible this is a “local” connection (Ansible defaults to trying to connect to any host—even localhost —via SSH).
Let’s start off writing a basic playbook, which will run the date command, store its result in a variable, and then print the result in a debug message.
Before writing the playbook, create a file named inventory to tell Ansible how to connect to localhost :

From your Home Directory

    # mkdir ~/ose-ansible && cd ~/ose-ansible
    # cat >> inventory << EOF
    [localhost]
    127.0.0.1 ansible_connection=local
    EOF

Every playbook starts with a play, which is a root level list item, with at least one key, hosts . To run a playbook against the local machine, you can set the following line at the beginning of the playbook, in a new file named main.yaml :

    ---
    - hosts: localhost

When connecting to localhost and running simple automation tasks, you should usually disable Ansible’s fact-gathering functionality. Often this is not needed and can save time in your playbook runs. When it is enabled, Ansible digs through the system and stores tons of environment information in variables before it begins running tasks.
So, to do this, the next line should be: “gather_facts: false”
Next up, we’re going to write our first-ever Ansible task, to run the date command and capture its output:

    tasks:
      - name: Get the current date.
        command: date
        register: current_date
        changed_when: false

The tasks keyword should be on the same level as hosts , etc., and then all the tasks should be in a YAML list under tasks .
It’s best practice to name every task you write in Ansible. This serves two purposes:

  - The name serves as an inline comment describing the task in YAML.
  - The value of the name will be printed in Ansible’s output as the name of the task when it runs.

A name is not strictly required, but it’s a lot easier to debug your playbooks if you name things after what they are doing!
This first task uses Ansible’s command module, which takes the value of the command and runs it. So this would be the equivalent of running the date command on the command line.

The task also registers the returned value (and some other metadata) into a new variable current_date , and because we know running date will never change the state of the host it’s run on, we also add changed_when: false. This helps Ansible keep track of state—later we will use this to our advantage!
Let’s add just one more task that will print the date we saved. 

So far, your entire playbook should look like this:

    # cat > main.yaml << EOF
    ---
    - hosts: localhost
      gather_facts: false

      tasks:
        - name: Get the current date.
          command: date
          register: current_date
          changed_when: false

        - name: Print the Current date.
          debug:
          msg: "{{ current_date.stdout }}"
    EOF

It may not look like this now but if you Copy/Paste the playbook to your terminal , you will see that the indentations are correct.

### Running the Container 

Generate your SSH key to interact with your local machine using ansible. Press `Enter` to approve the passphrase, This command will automatically create your public and private SSH keys.

    # ssh-keygen -N '' -f ~/.ssh/id_rsa -t rsa

Now that we have our files in place lets make sure the ansible container can run with our newly created files:

    # podman run --rm --name ose-ansible -tu `id -u` \
    -v $HOME/.ssh/id_rsa:/opt/app-root/src/.ssh/id_rsa:Z,ro \
    -v $HOME/ose-ansible/inventory:/tmp/inventory:Z,ro  \
    -e INVENTORY_FILE=/tmp/inventory -e OPTS="-v"  \
    -v $HOME/ose-ansible/:/opt/app-root/ose-ansible/:Z,ro \
    -e PLAYBOOK_FILE=/opt/app-root/ose-ansible/main.yaml \
    registry.infra.local:5000/openshift3/ose-ansible

Expected Output: 





    PLAY [localhost] *****************************************************************************************************************************************************************************
    
    TASK [Get the current date.] *****************************************************************************************************************************************************************
    Thursday 23 April 2020  20:05:45 +0000 (0:00:00.159)       0:00:00.159 ******** 
    ok: [127.0.0.1] => {"changed": false, "cmd": ["date"], "delta": "0:00:00.004917", "end": "2020-04-23 20:05:45.917910", "rc": 0, "start": "2020-04-23 20:05:45.912993", "stderr": "", "stderr_lines": [], "stdout": "Thu Apr 23 20:05:45 UTC 2020", "stdout_lines": ["Thu Apr 23 20:05:45 UTC 2020"]}
    
    TASK [Print the Current date.] ***************************************************************************************************************************************************************
    Thursday 23 April 2020  20:05:45 +0000 (0:00:00.413)       0:00:00.572 ******** 
    ok: [127.0.0.1] => {
        "msg": "Hello world!"
    }
    
    PLAY RECAP ***********************************************************************************************************************************************************************************
    127.0.0.1                  : ok=2    changed=0    unreachable=0    failed=0   

## Kubernetes Module

Now that we are able to run ansible from our container let’s switch our focus to the kubernetes module.

### Running the k8s Ansible modules locally

For this example we will create and delete a namespace with the switch of an Ansible variable.
First we need to create a rule for our kubernetes cluster:

    # cd $HOME
    # mkdir ose-openshift && cd ose-openshift

Now we will create a Playbook.yaml file.

    # cat > playbook.yaml << EOF
    ---
    - name: Create a new file named names in the current directory
      hosts: localhost
      roles:
      - Hello-go-role
    EOF

First let’s make sure we are login to the cluster (login credentials placed in the sheets file under ocp user and ocp password):

    # oc login api.ocp4.infra.local:6443

Make sure you are on your project :

    # oc project project-${USER}

Next let’s generate a yaml by creating a config map (change user01 to your user) :


    # touch Dockerfile
    # oc create configmap dockerfile --from-file=$HOME/ose-openshift/Dockerfile -o yaml
    apiVersion: v1
    data:
      Dockerfile: ""
    kind: ConfigMap
    metadata:
      creationTimestamp: "2020-04-21T17:31:51Z"
      name: dockerfile
      namespace: project-${USER}
      resourceVersion: "911597"
      selfLink: /api/v1/namespaces/project-user01/configmaps/dockerfile
      uid: 4b09279e-bd02-4f88-973d-ca58cc353f9a

Make sure you save the YAML output , we will use it in a minute , for now delete the configmap : 

    # oc delete configmap dockerfile

Now we will create the role directory and the Example-role structure:

    # mkdir roles && cd roles
    # ansible-galaxy init Hello-go-role
    - Role Hello-go-role was created successfully

Modify tasks file Example-role/tasks/main.yml to contain the Ansible shown below:


    # cat > Hello-go-role/tasks/main.yml << EOF
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

Build the inventory file for this playbook :

    # cd ..
    # cat >> inventory << EOF
    [localhost]
    127.0.0.1 ansible_connection=local
    EOF

Run playbook.yml, which will execute 'example-role'.

    # podman run --rm --name ose-openshift -tu `id -u` \
    -v $HOME/.ssh/id_rsa:/opt/app-root/src/.ssh/id_rsa:Z,ro \
    -v $HOME/ose-openshift/inventory:/tmp/inventory:Z,ro  \
    -e INVENTORY_FILE=/tmp/inventory -e OPTS="-v" \
    -v $HOME/ose-openshift/:/opt/app-root/ose-ansible/:Z,ro \
    -e PLAYBOOK_FILE=/opt/app-root/ose-ansible/playbook.yaml \
    registry.infra.local:5000/openshift3/ose-ansible

#### ERROR !!

    fatal: [127.0.0.1]: FAILED! => {"changed": false, "msg": \
    "This module requires the OpenShift Python client. Try `pip install openshift`"}

Think about a few minutes and we will pick this up together 

