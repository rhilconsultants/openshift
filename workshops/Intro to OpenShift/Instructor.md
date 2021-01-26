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

### SSH Keys

The SSH keys are stored in the spreadsheet file the student had provided their ssh keys.
we need to create a CSV and load it to an sqlite database and then use the database to create a key
for each user.

#### download the CSV file 

A simple task indeed , all we need to do is to open the file in google spreadsheet and click on "File --> Download --> Comma-separated value"
then give the file a simple filename like users.csv

copy the file to the bastion :
```bash
# scp users.csv <your-daomain>@bastion.${GUID}.example.opentlc.com:/tmp/
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