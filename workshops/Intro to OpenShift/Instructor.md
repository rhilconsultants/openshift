# Instructor's Page

## Table of content

1. build the users namespaces 
2. add users to the bastion
3. create an ssh key for the users
4. Create the go-toolset image


### Building the namespaces

First Let's create a namespace for each user 

Make sure you are root before to continue :

```bash
# sudo su -
```

now let's create a namespace for each user and give the user root permissions:

```bash
# for int in {1..30}; do
oc new-project user${int}-project
done
```

Now we will run the same loop and give the users admin permissions on the namespace :

```bash
# for int in {1..30}; do
oc adm policy add-role-to-user admin user${int} -n user${int}-project
done
```

### creating bastion users

after the namespaces and the users have been created we can create the users on the bastion

```bash
# for int in {1..30}; do
useradd user${int}
done
```

### SSH Keys/ Reset passwords

The SSH keys are stored in the spreadsheet file the student had provided their ssh keys.
we need to create a CSV and load it to an sqlite database and then use the database to create a key
for each user.

To reset the passwords for all the users 

```bash
# for int in {1..30}; do
echo 'openshift' | passwd --stdin user${int}
done
```

### (IN case there is A class spreadsheet) - download the CSV file 

A simple task indeed , all we need to do is to open the file in google spreadsheet and click on "File --> Download --> Comma-separated value"
then give the file a simple filename like users.csv

copy the file to the bastion :
```bash
# scp users.csv <user-login>@bastion.${GUID}.example.opentlc.com:/tmp/
```

Now (as root) install sqlite
```bash
# dnf intall -y sqlite
```

#### Generate the sqlite Database

and create a new database file
```bash
# sqlite3 users.sq3
```

Next we will set the mode to csv
```bash
.mode csv
```

and import the file:
```bash
.import /tmp/users.csv users
```

we can look at the schema of the table to see it was created correctly 
```bash
.schema users
```

now quit.
```bash
.quit
```

#### Create the users SSH keys

And create a new bash script that will update all the users :
```bash
# cat > users-update.sh << EOF
echo 'select username,"SSH Public KEY" from users;' | sqlite3 users.sq3 | while read LINE; do

OCP_USER=$(echo $LINE | awk -F\| '{print $1}')
USER_KEY=$(echo $LINE | awk -F\| '{print $2}')

if [[ ! -z ${USER_KEY} ]]; then

        if [[ ! -d /home/${OCP_USER}/.ssh/ ]]; then
                mkdir /home/${OCP_USER}/.ssh/
        else
                echo "directory /home/${OCP_USER}/.ssh/ already exists"
        fi

        echo ${USER_KEY} > /home/${OCP_USER}/.ssh/authorized_keys
        chown -R ${OCP_USER}:${OCP_USER} /home/${OCP_USER}/.ssh/
        chmod 700 /home/${OCP_USER}/.ssh/
        chmod 600 /home/${OCP_USER}/.ssh/authorized_keys
fi

done
EOF
```

give execute permission and run the script :
```bash
# chmod a+x users-update.sh && ./users-update.sh
```

All the users should be able to login with their given username.

## Create the go-toolset image

First download the image from registry.redhat.io
```bash
# podman login registry.redhat.io
```

And download the image
```bash
# podman pull ubi8/go-toolset
```

Now create a new project and make it public 
```bash
# oc new-project ubi8
# oc adm policy add-role-to-group system:image-puller system:authenticated -n ubi8
# oc adm policy add-role-to-user admin user1 -n ubi8
```

Login with the user1 credentials
```bash
# export UUID=""
# export SANDBOX=""
# touch ~/.kube/user1.config
# export KUBECONFIG="/root/.kube/user1.config"
# oc login --user user1 --password openshift --server=https://api.cluster-${UUID}.${UUID}.${SANDBOX}.opentlc.com
# podman login -u $(oc whoami) -p $(oc whoami -t) ${REGISTRY}
```

Now Tag it to the interanl directory
```bash 
# export REGISTRY="default-route-openshift-image-registry.apps.cluster-${UUID}.${UUID}.${SANDBOX}.opentlc.com"
# podman tag registry.redhat.io/ubi8/go-toolset ${REGISTRY}/ubi8/go-toolset
```

The final steps is to push it 
```bash
# podman push ${REGISTRY}/ubi8/go-toolset
```

