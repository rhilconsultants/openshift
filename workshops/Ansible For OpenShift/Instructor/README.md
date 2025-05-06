# Lab Configuration

The Following Page is for the Instractor to set up the Lab

**Logging to the Lab and switch to root**

## Install The Following Packages

### EPEL Packages
```bash
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
```

Now Install the relevant packages:
```bash
dnf install -y jq openssl podman p7zip httpd-tools curl wget rlwrap nmap telnet ftp tftp\
 openldap-clients tcpdump wireshark-cli buildah xorg-x11-xauth tmux net-tools nfs-utils skopeo make 
```

To enable Ansible with Kubernetes
```bash
# dnf install -y http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/ansible-core-2.12.2-3.el8.x86_64.rpm \
  http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/python38-resolvelib-0.5.4-5.el8.noarch.rpm
# dnf intall -y ansible.noarch
```

Install the Kubernetes module :
```bash
# pip3 install kubernetes==12.0.1
```

### Users Management

Create a user for the Manager

```bash
# export ADMIN_USER="" #set the admin username
```

Create a group for the admins users if you need more then one :
```bash
# groupadd admins
# useradd -g admins -G wireshark,disk,wheel ${ADMIN_USER}
```

Add the group to the soduers file
```bash
# echo '%admins         ALL=(ALL)       NOPASSWD: ALL' >> /etc/sudoers
```

Copy the kubeconfig from root to the user manager
```bash
cp -R /root/.kube/ /home/${ADMIN_USER}/
chown ${ADMIN_USER}:admins -R /home/${ADMIN_USER}/.kube/
```

Create a tmux file for each of the users :

```bash
# for num in {1..20};do
useradd user${num}
echo 'openshift' | passwd --stdin user${num} 
cat > /home/user${num}/.tmux.conf << EOF
unbind C-b
set -g prefix C-a
bind -n C-Left select-pane -L
bind -n C-Right select-pane -R
bind -n C-Up select-pane -U
bind -n C-Down select-pane -D
bind C-Y set-window-option synchronize-panes
EOF
chown user${num}:user${num} /home/user${num}/.tmux.conf
done
```

Now make sure the users are admin on thier namespace :
```bash
# for num in {1..20};do
oc new-project user${num}-project
oc adm policy add-role-to-user admin user${num} -n user${num}-project
done
```

Extact the CA from OpenShift to a file :

```bash
# oc -n openshift-authentication  \
rsh `oc get pods -n openshift-authentication -o name | head -1 `  cat /run/secrets/kubernetes.io/serviceaccount/ca.crt > \
/etc/pki/ca-trust/source/anchors/opentls.crt
# update-ca-trust extract
```

