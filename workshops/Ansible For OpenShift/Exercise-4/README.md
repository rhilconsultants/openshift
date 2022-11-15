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
            image: ${REGISTRY}/${USER}-project/ose-openshift
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