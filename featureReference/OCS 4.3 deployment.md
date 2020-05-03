#
OCS 4.3 on OCP 4.3 Deployment

This document follows the video 
```
All Things Data: State of Container Storage, Deeper Dive Part 1
```  or
```
Using Local Disks on VMware with OpenShift Container Storage
```
##
1) Add Local storage to workers machines״
Go to properties of Virtual machines that will host OCS 4.3 (mainly workers VMs, at least 3 Machines will be part of OCS 4.3) and add additional disks
1 x 200-500GB per each VM, depending on your needs) for block storage
1 x 10GB disk for mon services
“##2) Create storage and allow access to OpenShift״
Create project local-storage
Go to Administration -> Namespace openshift-storage (see DEPLOYING OPENSHIFT CONTAINER STORAGE). 
Label is set to 'openshift.io/cluster-monitoring=true'
Clone the Git project https://github.com/dmoessne/ocs-disk-gather
 “```bash# oc create -f ocs-disk-gatherer.yaml```”
 “```bash# oc get po -o wide```”
 “```bash# oc logs ocs-disk-gatherer-NAME```”
OUTPUT
 Install local-storage operator 
Create file local-storage-block-byid.yaml using in the disk names received from the logs command (here you need to put IDs of big disks for block usage):
“```bash# vi local-storage-block-byid.yaml
apiVersion: local.storage.openshift.io/v1
kind: LocalVolume
metadata:
  name: local-block
  namespace: local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
	      - key: cluster.ocs.openshift.io/openshift-storage
	        operator: In
	        values:
	        - ""
  storageClassDevices:
    - storageClassName: localblock
    volumeMode: Block
    devicePaths:
      - /dev/disk/by-id/scsi-36000c29c38c0649dfab5681bf508924a
      - /dev/disk/by-id/scsi-36000c29ad2be38b4b9f8165938122198
      - /dev/disk/by-id/scsi-36000c29f31a150858d09b15dcc8a3c67
   	 
# oc create -f local-storage-block-byid.yaml```”
Create file mon-local-storage-byid.yaml using in the disk names received from the logs command 
(here you need to put IDs of 10G disks for mon usage):
“```bash# vi mon-local-storage-byid.yaml
apiVersion: local.storage.openshift.io/v1
kind: LocalVolume
metadata:
  name: localfile
  namespace: local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
        - key: cluster.ocs.openshift.io/openshift-storage
          operator: In
          values:
          - ""
  storageClassDevices:
    - storageClassName: localfile
      volumeMode: Filesystem
      devicePaths:
        - /dev/disk/by-id/scsi-36000c29fd7b94d2251d5e0781203385d
        - /dev/disk/by-id/scsi-36000c29f91efeedbac478f32b48f25e5
        - /dev/disk/by-id/scsi-36000c2924b744720965fc190ff34aa8f
   	 
# oc create -f mon-local-storage-byid.yaml```”
   
“```bash# oc project local-storage```”
“```bash# oc get sc
NAME         	PROVISIONER                	AGE
localblock   	kubernetes.io/no-provisioner   8m19s
localfile      kubernetes.io/no-provisioner   8m15s
thin (default)   kubernetes.io/vsphere-volume   3d10h```”
“```bash# oc get csv
NAME                                     	DISPLAY     	VERSION           	REPLACES   PHASE
local-storage-operator.4.3.10-202003311428   Local Storage   4.3.10-202003311428          	Succeeded```”
“```bash# oc get pods,pv
NAME                                      	 READY   STATUS	RESTARTS   AGE
pod/local-block-local-diskmaker-4f9vq       	1/1 	Running   0      	8m27s
pod/local-block-local-diskmaker-cshtb       	1/1 	Running   0      	8m27s
pod/local-block-local-diskmaker-mssgb       	1/1 	Running   0      	8m27s
pod/local-block-local-provisioner-2krss     	1/1 	Running   0      	8m27s
pod/local-block-local-provisioner-8zlv5   	  1/1 	Running   0      	8m27s
pod/local-block-local-provisioner-tqhzt     	1/1 	Running   0      	8m27s
pod/local-storage-operator-566ff7dcc5-6xpvk   1/1 	Running   0      	8m40s
 
NAME                             	CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS  	CLAIM   STORAGECLASS   REASON   AGE
persistentvolume/local-pv-382a9822   400Gi  	 RWO          	Delete       	Available       	localblock          	7m53s
persistentvolume/local-pv-56c3545d   400Gi  	 RWO          	Delete       	Available       	localblock          	7m53s
persistentvolume/local-pv-6fee4458   400Gi     RWO          	Delete       	Available       	localblock          	8m14s
persistentvolume/local-pv-562a9834   10Gi  	   RWO         	  Delete       	Available       	localfile           	7m53s
persistentvolume/local-pv-6fc3545s   10Gi      RWO         	  Delete       	Available       	localfile           	7m53s
persistentvolume/local-pv-6dee446g   10Gi    	 RWO        	  Delete       	Available       	localfile           	8m14s```”
“##3) Create OpenShift Container Storage"
Projects: Openshift-storage
    - install OpenShift Container Storage operator
    
“```bash# watch oc get csv
    
# oc project openshift-storage
# oc get pods
NAME                                  	 READY   STATUS	RESTARTS   AGE
lib-bucket-provisioner-69cc6f86dd-t65jr   1/1 	Running   0      	4m1s
noobaa-operator-6666bdf4d7-4bh24      	  1/1 	Running   0      	3m57s
ocs-operator-565b5449b-dc4cg            	1/1 	Running   0      	3m57s
rook-ceph-operator-86944dbc94-df8pf     	1/1 	Running   0      	3m57s```”
    
    - create storage cluster via CLI
    
“```bash# vi cluster-service-VMware.yaml
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: ocs-storagecluster
  namespace: openshift-storage
spec:
  manageNodes: false
  monPVCTemplate:
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 1
      storageClassName: localfile
      volumeMode: Filesystem
  storageDeviceSets:
  - count: 1
    dataPVCTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1
        storageClassName: localblock
        volumeMode: Block
    name: ocs-deviceset
    placement: {}
    portable: false
    replica: 3
    resources: {}

# oc create -f cluster-service-VMware.yaml```”
    
“```bash# oc get pods
NAME                                            	READY  STATUS RESTARTS   AGE
csi-cephfsplugin-7gxjw                           	3/3 	Running   0      	4m53s
csi-cephfsplugin-h4nnw                          	3/3 	Running   0      	4m53s
csi-cephfsplugin-provisioner-5f59d5c66c-5m7xx     5/5 	Running   0      	4m52s
csi-cephfsplugin-provisioner-5f59d5c66c-grtfj     5/5 	Running   0      	4m53s
csi-cephfsplugin-sd7pn                      	    3/3 	Running   0      	4m54s
csi-rbdplugin-k9d5r                         	    3/3 	Running   0      	4m54s
csi-rbdplugin-pbdc8                         	    3/3 	Running   0      	4m54s
csi-rbdplugin-provisioner-8455c459bb-22nhm  	    5/5 	Running   0      	4m52s
csi-rbdplugin-provisioner-8455c459bb-9xrs7  	    5/5 	Running   0      	4m54s
csi-rbdplugin-zfnd2                         	    3/3 	Running   0      	4m54s
lib-bucket-provisioner-69cc6f86dd-t65jr     	    1/1 	Running   0      	26m
noobaa-operator-6666bdf4d7-4bh24                	1/1 	Running   0      	26m
ocs-operator-565b5449b-dc4cg                	    0/1 	Running   0      	26m
rook-ceph-mon-a-canary-8b446db96-vdbzb      	    0/1 	Pending   0      	46s
rook-ceph-operator-86944dbc94-df8pf         	    1/1 	Running   0      	26m```”

In this stage some pods may be in pending status. You can check by several ways what is the cause of issue:
“```bash# oc describe pod < name of pending pod >
# oc logs < name of pending pod >```”
Go to console→ projects→ openshift-storage, go to workloads → pods, find the problematic pod and look for the reason. 
Mostly the reason will be Unschedulable and it means that you are short in resources, some additional resources increasing for VMs 
hosting OCS 4.3 will help to overcome the issue. Rule of thumb can be between 10 and 12 vCPU per VM hosting OCS4.3, and between 20 and 24 GB of Memory.
At the end of the process you should see the next output:

“```bash# oc get pods,pv,svc,route
NAME                                                                  READY   STATUS    RESTARTS   AGE
pod/csi-cephfsplugin-lsf55                                            3/3     Running     6        23h
pod/csi-cephfsplugin-pmh6q                                            3/3     Running     6        23h
pod/csi-cephfsplugin-provisioner-5f59d5c66c-kv26q                     5/5     Running    36        23h
pod/csi-cephfsplugin-provisioner-5f59d5c66c-xk2rh                     5/5     Running    27        19h
pod/csi-cephfsplugin-x2dtt                                            3/3     Running     6        23h
pod/csi-rbdplugin-p52xq                                               3/3     Running     6        23h
pod/csi-rbdplugin-provisioner-8455c459bb-mmkjc                        5/5     Running    37        23h
pod/csi-rbdplugin-provisioner-8455c459bb-rlnjp                        5/5     Running    19        19h
pod/csi-rbdplugin-pt4d4                                               3/3     Running     6        23h
pod/csi-rbdplugin-vz6jp                                               3/3     Running     6        23h
pod/lib-bucket-provisioner-7764685dd7-wplvg                           1/1     Running     2        23h
pod/noobaa-core-0                                                     1/1     Running     3        23h
pod/noobaa-db-0                                                       1/1     Running     0        23h
pod/noobaa-endpoint-cf6d88549-gvgvh                                   1/1     Running     1        23h
pod/noobaa-operator-74d8955f74-vf9p8                                  1/1     Running    42        23h
pod/ocs-operator-6c84f6cd7f-9gl5j                                     1/1     Running     2        23h
pod/rook-ceph-crashcollector-482609e55f8cd70b9f8607f102b9ea0a-qjdgg   1/1     Running     0        19h
pod/rook-ceph-crashcollector-bdabcefd814f99adb77b50fe9df63050-kzgkd   1/1     Running     2        23h
pod/rook-ceph-crashcollector-f9fc418f43343c7b67c6df3930af083f-5whcq   1/1     Running     2        23h
pod/rook-ceph-drain-canary-482609e55f8cd70b9f8607f102b9ea0a-6589628   1/1     Running     0        19h
pod/rook-ceph-drain-canary-bdabcefd814f99adb77b50fe9df63050-55mrhb2   1/1     Running     2        23h
pod/rook-ceph-drain-canary-f9fc418f43343c7b67c6df3930af083f-56npjdr   1/1     Running     2        23h
pod/rook-ceph-mds-ocs-storagecluster-cephfilesystem-a-5f7df85dvjzfh   1/1     Running     0        19h
pod/rook-ceph-mds-ocs-storagecluster-cephfilesystem-b-5f4fcb84m8xjn   1/1     Running     0        23h
pod/rook-ceph-mgr-a-6dfbd8868b-8hczg                                  1/1     Running     0        19h
pod/rook-ceph-mon-a-799b6dcd9-r2f4f                                   1/1     Running     0        19h
pod/rook-ceph-mon-b-7f78456c66-4g9fw                                  1/1     Running     2        23h
pod/rook-ceph-mon-c-6596544447-4hjzk                                  1/1     Running     2        23h
pod/rook-ceph-operator-6b45d64bc-5jq59                                1/1     Running    38        23h
pod/rook-ceph-osd-0-666bcbd9f6-k2l22                                  1/1     Running     0        19h
pod/rook-ceph-osd-1-8d78bd76-ldhfc                                    1/1     Running     2        23h
pod/rook-ceph-osd-2-55db58f6b-bnzm6                                   1/1     Running     2        23h
pod/rook-ceph-osd-prepare-ocs-deviceset-0-0-gf49v-22lkm               0/1     Completed   0        23h
pod/rook-ceph-osd-prepare-ocs-deviceset-2-0-xst9j-8ttkn               0/1     Completed   0        23h
pod/rook-ceph-rgw-ocs-storagecluster-cephobjectstore-a-5d669b949lvd   1/1     Running     2        23h
 
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                       STORAGECLASS                  REASON   AGE
persistentvolume/local-pv-382a9822                          400Gi      RWO            Delete           Bound    openshift-storage/ocs-deviceset-2-0-xst9j   localblock                             23h
persistentvolume/local-pv-56c3545d                          400Gi      RWO            Delete           Bound    openshift-storage/ocs-deviceset-1-0-x4qjj   localblock                             23h
persistentvolume/local-pv-5922bc                            10Gi       RWO            Delete           Bound    openshift-storage/rook-ceph-mon-b           localfile                              23h
persistentvolume/local-pv-5ee82fce                          10Gi       RWO            Delete           Bound    openshift-storage/rook-ceph-mon-c           localfile                              23h
persistentvolume/local-pv-6fee4458                          400Gi      RWO            Delete           Bound    openshift-storage/ocs-deviceset-0-0-gf49v   localblock                             23h
persistentvolume/local-pv-c84e572f                          10Gi       RWO            Delete           Bound    openshift-storage/rook-ceph-mon-a           localfile                              23h
persistentvolume/pvc-a8be2a0d-f381-4a66-915e-03c5b3cd4a9e   50Gi       RWO            Delete           Bound    openshift-storage/db-noobaa-db-0            ocs-storagecluster-ceph-rbd            23h
 
 
NAME                                                       TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                    AGE
service/csi-cephfsplugin-metrics                           ClusterIP      172.30.88.221    <none>        8080/TCP,8081/TCP                                          23h
service/csi-rbdplugin-metrics                              ClusterIP      172.30.100.241   <none>        8080/TCP,8081/TCP                                          23h
service/noobaa-db                                          ClusterIP      172.30.140.123   <none>        27017/TCP                                                  23h
service/noobaa-mgmt                                        LoadBalancer   172.30.211.238   <pending>     80:32396/TCP,443:31331/TCP,8445:32572/TCP,8446:30694/TCP   23h
service/rook-ceph-mgr                                      ClusterIP      172.30.171.33    <none>        9283/TCP                                                   23h
service/rook-ceph-mon-a                                    ClusterIP      172.30.105.126   <none>        6789/TCP,3300/TCP                                          23h
service/rook-ceph-mon-b                                    ClusterIP      172.30.241.252   <none>        6789/TCP,3300/TCP                                          23h
service/rook-ceph-mon-c                                    ClusterIP      172.30.238.73    <none>        6789/TCP,3300/TCP                                          23h
service/rook-ceph-rgw-ocs-storagecluster-cephobjectstore   ClusterIP      172.30.71.249    <none>        80/TCP                                                     23h
service/s3                                                 LoadBalancer   172.30.252.12    <pending>     80:30119/TCP,443:30871/TCP,8444:32006/TCP                  23h
 
NAME                                   HOST/PORT                                                                PATH   SERVICES      PORT         TERMINATION   WILDCARD
route.route.openshift.io/noobaa-mgmt   noobaa-mgmt-openshift-storage.apps.ocp43-test.sales.lab.tlv.redhat.com          noobaa-mgmt   mgmt-https   reencrypt     None
route.route.openshift.io/s3            s3-openshift-storage.apps.ocp43-test.sales.lab.tlv.redhat.com                   s3            s3-https     reencrypt     None```”

"##How to change default Storage class from thin to RBD"
“```bash# oc patch storageclass ocs-storagecluster-ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
 
# oc patch storageclass thin -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
 
[root@installer ocs-disk-gather]# oc get sc
NAME                                    PROVISIONER                             AGE
localblock                              kubernetes.io/no-provisioner            25h
localfile                               kubernetes.io/no-provisioner            24h
ocs-storagecluster-ceph-rbd (default)   openshift-storage.rbd.csi.ceph.com      24h
ocs-storagecluster-cephfs               openshift-storage.cephfs.csi.ceph.com   24h
openshift-storage.noobaa.io             openshift-storage.noobaa.io/obc         24h
thin                                    kubernetes.io/vsphere-volume            5d16h```”

That’s all. Enjoy your OCS 4.3 Cluster

"##Tests to check your RBD and FileFS"

Go to projects →  Create project stg-tests
“```bash# oc project stg-tests
# oc patch storageclass ocs-storagecluster-ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
 
#oc create -f - <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rbd-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ocs-storagecluster-ceph-rbd
EOF```”
 
“```bash# oc create -f - <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  name: csirbd-demo-pod
spec:
  containers:
   - name: web-server
     image: nginx
     volumeMounts:
       - name: mypvc
         mountPath: /var/lib/www/html
  volumes:
   - name: mypvc
     persistentVolumeClaim:
       claimName: rbd-pvc
       readOnly: false
EOF```”
 
“```bash# oc rsh csirbd-demo-pod lsblk -l | grep rbd1```”

“```bash# oc create -f - <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-pvc
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: ocs-storagecluster-cephfs
EOF```”
 
“```bash# oc create -f - <<EOF 
---
apiVersion: v1
kind: Pod
metadata:
  name: csicephfs-demo-pod-a
spec:
  containers:
   - name: web-server-a
     image: nginx
     volumeMounts:
       - name: mypvc
         mountPath: /var/lib/www/html
  volumes:
   - name: mypvc
     persistentVolumeClaim:
       claimName: cephfs-pvc
       readOnly: false
---
apiVersion: v1
kind: Pod
metadata:
  name: csicephfs-demo-pod-b
spec:
  containers:
   - name: web-server-b
     image: nginx
     volumeMounts:
       - name: mypvc
         mountPath: /var/lib/www/html
  volumes:
   - name: mypvc
     persistentVolumeClaim:
       claimName: cephfs-pvc
       readOnly: false
EOF```”
 
“```bash# oc rsh csicephfs-demo-pod-a df -h | grep /var/lib/www/html
# oc rsh csicephfs-demo-pod-b df -h | grep /var/lib/www/html
# oc rsh csicephfs-demo-pod-b df -h | grep /var/lib/www/html```”

"##Troubleshooting tools and tips".

Sometimes you need to repeat the deployment of LSO and OCS4.3 operators. One of best practices is to remove all resources from local-storage and openshift-storage projects and projects itself. If your project will remain in “Terminating” status after deleting it we created some script that can help to overcome this issue.


“```bash# vim terminating.sh
#run this before running the script
##
kubectl proxy --port=8080 &
##

oc get projects |grep Terminating |awk '{print $1}' > mylist
filename='mylist'
while read p; do
    echo $p
    oc get namespace $p -o json |grep -v "kubernetes" > $p.json
done < $filename
#!/bin/bash
kubectl proxy http://127.0.0.1:8080 &&
filename='mylist'
while read p; do
    curl -k -H "Content-Type: application/json" -X PUT --data-binary @$p.json localhost:8080/api/v1/namespaces/$p/finalize;
done < $filename```”

“```bash# chmod 755 terminating.sh
./terminating.sh
# oc projects```”

If your PVs will remain in “Terminating” status after deleting it we created some script that can help to overcome this issue.

“```bash# vim pvterminating.sh
#run this before running the script
##
kubectl proxy --port=8080 &
##

# oc get pv |grep Terminating |awk '{print $1}' > mylist
filename='mylist'
while read p; do
    echo $p
    oc get pv $p -o json |grep -v "kubernetes" > $p.json
done < $filename
#!/bin/bash
kubectl proxy http://127.0.0.1:8080 &&
filename='mylist'
while read p; do
    kubectl patch pvc $p -p '{"metadata":{"finalizers":null}}';
done < $filename```”

“```bash# chmod 755 pvterminating.sh
./pvterminating.sh
# oc get pv```”

Additional way to detect devices IDs that will be in usage by OCS 4.3 from the server itself by running the next command:
“```bash# ls -l /dev/disk/by-id/ | grep scsi | grep sd[b,c]```”

How to check if your Worker node has a relevant role: (OCS4.3 doing this labeling, but sometimes it not functioning properly):

“```bash# oc  get nodes 
# oc describe node <NodeName> | grep storage
                    cluster.ocs.openshift.io/openshift-storage=```”

If you didn’t received this label for the node that hosting OCS 4.3 you can run the next command:

“```bash# oc label node <NodeName> cluster.ocs.openshift.io/openshift-storage=''```”
 
