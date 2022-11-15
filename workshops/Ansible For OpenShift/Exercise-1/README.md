# Exercise 1

## Hello, Ansible!

### First Playbook

At its most basic, Ansible can be used to run tasks on the same machine running the Ansible playbook, by running against localhost, and telling Ansible this is a “local” connection (Ansible defaults to trying to connect to any host—even localhost —via SSH).
Let’s start off writing a basic playbook, which will run the date command, store its result in a variable, and then print the result in a debug message.
Before writing the playbook, create a file named inventory to tell Ansible how to connect to localhost:

#### Inventory File
From your Home Directory
```bash
$ mkdir ~/ose-ansible && cd ~/ose-ansible
$ cat >> inventory <<EOF
[localhost]
127.0.0.1 ansible_connection=local ansible_host=localhost ansible_python_interpreter=/usr/bin/python3
EOF
```

#### the Playbook

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
```bash
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

#### Running the Playbook

Now Let's Run the Ansible playbook to see the Results :
```bash
$ ansible-playbook -i inventory main.yaml
```

The output should show you the current date and time 

#### Second Playbook

Ansible comes with a big packages of build-in modules. After we builded the first playbook Let's add another task which will stop the run for 5 seconds and will continue after the time period ends.

between the 2 exsiting tasks add the following lines :

```yaml
- name: Sleep for 5 seconds and continue with play
  ansible.builtin.wait_for:
    timeout: 5
```

now run the playbook again and check if it waits 5 seconds before it finishes.
```bash
$ ansible-playbook -i inventory main.yaml
```

#### Open Task (third playbook)

take the playbook we have just created and turn into an Ansible role!

**HINT**
first create the role by running the following command :

```bash
$ ansible-galaxy init --init-path roles time-date
```

#### Cleanup 

We will not use this playbook any more so let's do a quick cleanup :
```bash
$ rm -f *
```
