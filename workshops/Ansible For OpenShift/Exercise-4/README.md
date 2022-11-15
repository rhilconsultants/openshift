# Task 4 - Running on OpenShift

For this task we will take everything we build so far and create a deployment that will deploy a Pod , A service and a route. 
Test if the route responses and delete all the resource.

The modules which we are going to use are :

- kubernetes.core.k8s
- kubernetes.core.k8s_info
- ansible.builtin.debug
- ansible.builtin.wait_for
- ansible.builtin.url

First update the run-ansible.sh file and replace :
```bash
if [[ -z "$K8S_AUTH_API_KEY" ]]; then 
  echo "No Kubernetes Authentication key provided (K8S_AUTH_API_KEY environment value)"
else 
  export K8S_AUTH_API_KEY=${K8S_AUTH_API_KEY}
fiif [[ -z "${K8S_AUTH_KUBECONFIG}" ]]; then
   echo "NO K8S_AUTH_KUBECONFIG environment variable configured"
   exit 1
fi
```

**WITH**

```bash
if [[ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]]; then
 K8S_AUTH_API_KEY=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
elif [[ -z "$K8S_AUTH_API_KEY" ]]; then 
  echo "No Kubernetes Authentication key provided (K8S_AUTH_API_KEY environment value)"
else 
  export K8S_AUTH_API_KEY=${K8S_AUTH_API_KEY}
fi
```

And Copy the roles to the image file 
With your favorite editor (VIM obviously) copy/paste the following line to your Dockerfile (at line 7) :

```bash
COPY roles /opt/app-root/
```

and recreate the ose-ansible image :

```bash
$ buildah bud -f Dockerfile -t ${REGISTRY}/${USER}-project/ose-ansible && buildah push ${REGISTRY}/${USER}-project/ose-ansible
```

Now update your registry to use the internal registry :

```bash
$ export REGISTRY="image-registry.openshift-image-registry.svc:5000"
```

### ServiceAccount

We want to control the permissions of the Ansible Playbook in regards to what resources can it create,list and delete so we need to create a new service account and then create a role and a rolebinding to give it the need permissions:

```bash
$ $ oc create sa health-check
```

Now for the we will create the role that will allow the playbook to create a pod , a service and a route so the role should look as such :

Create a new Directory named “YAML”

```bash
$ mkdir YAML
```

With your favorite editor create a new file named “YAML/role.yaml” and add the following content :

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: health-check
rules:
- apiGroups: [""] 
  resources: ["pods"]
  verbs: ["create","get", "watch", "list", "update", "patch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["create","get", "watch", "list", "update", "patch"]
- apiGroups: [""]
  resources: ["routes"]
  verbs: ["create","get", "watch", "list", "update", "patch"]
```

Same step for the rolebinding :

With your favorite editor create a new file named “YAML/rolebinding.yaml” and add the following content :

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: health-check
  namespace: health-check
subjects:
- kind: ServiceAccount
  name: health-check
  namespace: health-check
roleRef:
  kind: Role 
  name: health-check
  apiGroup: rbac.authorization.k8s.io
```

Let’s create all the resources :
```bash
$ oc create -f YAML/role.yaml -f YAML/rolebinding.yaml
```

Here is how the cronjob should look like.  
(we have already created the rest of the components)

```bash
$ cat > cronjob.yaml << EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cron-health-check
spec:
  concurrencyPolicy: Forbid
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          serviceAccountName: health-check
          containers:
          - name: health-check
            image: ${REGISTRY}/${USER}-project/ose-ansible
            env: 
            - name: OPTS 
              value: "-vv"
            - name: HOME
              value: "/opt/app-root/"
            - name: PLAYBOOK_FILE
              value: "/opt/app-root/ansible/playbook.yaml"
            - name: INVENTORY
              value: "/opt/app-root/ansible/inventory"
            - name: DEFAULT_LOCAL_TMP
              value: "/tmp/"
            - name: K8S_AUTH_HOST
              value: $(oc whoami --show-server)
            - name: K8S_AUTH_VALIDATE_CERTS
              value: "false"
            volumeMounts:
            - name: playbook
              mountPath: /opt/app-root/ansible/playbook.yaml
              subPath: playbook.yaml
            - name: inventory
              mountPath: /opt/app-root/ansible/inventory
              subPath: inventory
            - name: cache-volume
              mountPath: /opt/app-root/src
          volumes:
          - name: playbook
            configMap:
              name: playbook
          - name: inventory
            configMap:
              name: inventory
          - name: cache-volume
            emptyDir: {}
EOF
```

recreate the image and the relevant ConfigMap files so the cronjob will work !!!

Once everything is set go ahead and apply it :
```bash
$ oc apply -f cronjob.yaml
```

Good Luck 