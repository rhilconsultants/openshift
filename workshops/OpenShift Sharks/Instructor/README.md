# Instructor AI

once you order the cluster , here are the tasks you need to run.

## create users

as the amount of users you orderd run the following commnad (the exmaple is for 40 users) :

login to bastion with lab-user  


```bash
$ sudo su -
$ for i in {1..40} ; do useradd user$i ; done

```

## Set password
set the passowrd for openshift to all the users :

```bash
$ for i in {1..40} ; do  echo "openshift" | passwd user$i --stdin ; done
```

## New Project

Create a project for each user :
```bash
$ for i in {1..40} ; do  oc new-project user${i}; done
```


## cluster admin permissions

to avoid creating a cluster role and a cluster role binding , just give all the users cluster admins
```bash
$ for i in {1..40} ; do oc adm policy add-cluster-role-to-user cluster-admin user$i; done
```

## Install tools

Install the following tools on the bastion server 
```bash
$ dnf install -y wireshark-cli tcpdump telnet nmap ftp tftp podman skopeo buildah rsync
```
