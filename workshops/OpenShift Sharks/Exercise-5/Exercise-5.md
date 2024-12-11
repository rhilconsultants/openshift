Debugging latency issues

# Network Latency
In this Exercise We will deploy our carinfo application but the application development complains about latency issues and they are convinced that the latency is originated from OpenShift.

We are going to prove them wrong!!!

# Clear old deployments 

First let's delete the deployments from the last exercise :
```bash
# oc delete deployment loop-curl-statistics
# oc delete deployment ubi-minimal
```

# deploying the application

Our application is composed of 3 tears.
* The database layer
* The backend layer (A.K.A dbapi)
* The front end layer (A.K.A frontend)

Let’s first deploy the database layer. The application is using MariaDB as its database.
The MariaDB uses persistent storage and we will provide it through a PVC.

```bash
# cat << EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-pv-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF
```

Next we will deploy the mariadb 
```bash
# cat << EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mariadb
spec:
  selector:
    matchLabels:
      app: mariadb
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      containers:
      - image: mariadb:latest
        name: mariadb
        env:
        - name: MARIADB_ROOT_PASSWORD
          value: password
        - name: MARIADB_USER
          value: carinfo
        - name: MARIADB_PASSWORD
          value: CarInfoPass
        - name: MARIADB_DATABASE
          value: carinfo
        ports:
        - containerPort: 3306
          name: mariadb
        volumeMounts:
        - name: mariadb-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mariadb-persistent-storage
        persistentVolumeClaim:
          claimName: mariadb-pv-claim
EOF
```

And the service to access the database 

```bash
# cat << EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: mariadb
spec:
  ports:
  - port: 3306
  selector:
    app: mariadb
EOF
```

At this point we have deployed the database layer and now we will move on the backend layer :

First deploy the dbapi :

```bash
# cat << EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: dbapi
  name: dbapi
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dbapi
  template:
    metadata:
      labels:
        app: dbapi
    spec:
      containers:
      - image: quay.io/two.oes/carinfo-dbapi:latest
        name: dbapi
        serviceAccount: default
        serviceAccountName: default
        ports:
        - containerPort: 8080
        env:
        - name: DB_NAME
          value: carinfo
        - name: DB_USER
          value: carinfo
        - name: DB_PASSWORD
          value: CarInfoPass
        - name: SET_DELAY
          value: "yes"
        - name: DB_HOST
          value: mariadb
EOF
```

And the dbapi service :
```bash
# cat << EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dbapi
spec:
  ports:
  - port: 8080
  selector:
    app: dbapi
EOF
```

Now what is left is to deploy the frontend application , its service and route :

```bash
# cat << EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: frontend
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: frontend
    spec:
      containers:
      - image: quay.io/two.oes/carinfo-frontend:latest
        name: carinfo-frontend
        ports:
        - containerPort: 8080
        env:
        - name: DBAPI_URL
          value: "http://dbapi:8080/query"
        - name: PORT
          value: 8080
EOF
```
And the service :

```bash
# cat << EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  ports:
  - name: frontend
    port: 8080
    targetPort: 8080
  - name: frontend-ssl
    port: 8443
    targetPort: 8443
  selector:
    app: frontend
EOF
```
Now let’s create the route and test the application
```bash
# oc create route edge --service=frontend --port=8080 --insecure-policy=Redirect --dry-run=client -o yaml
```

If you approve the way the route is shown then go ahead and create it 
```bash
# oc create route edge --service=frontend --port=8080 --insecure-policy=Redirect
```

## Testing.
The deployment team gave use a way to test the application so let’s go ahead and run the following command :
```bash
# ROUTE=$(echo -n 'https://' && oc get route frontend -o jsonpath='{.spec.host}')
# echo "export ROUTE=${ROUTE}" >> ~/.bashrc
# curl -k -s -H 'Content-Type: application/json' -d '{"Manufacture": "Alfa Romeo","Module": "Jullieta"}' ${ROUTE}/v1 | jq
```

Rememeber the statistics file from the previus exercise ... let's run the same command with it :

```bash
# cd ~/curl-statistics
# curl -w "@loop_curl_statistics.txt" -k -s -H 'Content-Type: application/json' -d '{"Manufacture": "Alfa Romeo","Module": "Jullieta"}' ${ROUTE}/v1 | jq
```
Use the tools we talked about today (oc sniff) to find out where is the issue.

let's generate a pcap file and analyze the pcap file with wireshark.  
Open 3 more session and run the ksniff for each of the pods
  - for the frontend filter port 8080
  - for the dbapi filter port 8080
  - for the database filter port 3306

build a bash script that will run all the commands together to 3 diffrent files.
Now run the curl command again and copy them to wireshark (with scp/winscp)

Good luck 
