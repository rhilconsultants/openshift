# Gitea
`gitea` is used as the `git` repository for this demo. Install it by running the following commands in a `bash` shell:
Create a project/namespace for `gitea`:
```bash
oc new-project gitea
```
Add privileges for `gitea` (not recommended for production systems):
```bash
oc adm policy add-scc-to-user privileged -z default
oc adm policy add-scc-to-user nonroot -z gitea-memcached
```
Use `helm` to install `gitea`:
```bash
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update
helm install gitea gitea-charts/gitea --set ingress.hosts[0].host=gitea-http-gitea$(oc whoami --show-console | sed "s/.*console-openshift-console//") --set gitea.config.webhook.ALLOWED_HOST_LIST='*' --set gitea.config.webhook.SKIP_TLS_VERIFY=true --set image.pullPolicy=IfNotPresent
```
Create a `route` for `gitea`:
```bash
oc expose service gitea-http
oc get route gitea-http -o jsonpath='{"http://"}{.status.ingress[0].host}{"\n"}'
```
When all pods are in the `Running` status, browse the the URL displayed above and sign into `gitea` using the following credentials:
* user: gitea_admin
* password: r8sA8CPHD9!bt6d

In `gitea` press the pull-down icon at the top right and select `Site Administration`. In the `User Accounts` tab press `Create User Account` and create a user named `demo` with password `demodemo`. Deselect `Require user to change password`. Set the password to: 123456

