------

## Setup NFS server on physical host:

```
[root@kworkhorse ~]# mkdir k8s-nfs-storageclass
```

```
[root@kworkhorse ~]# vi /etc/exports

/home/nfsshare/k8s-nfs-storageclass *(rw,no_root_squash)
```

Enable & start NFS service on the host:
```
[root@kworkhorse ~]# systemctl enable nfs-server
Created symlink /etc/systemd/system/multi-user.target.wants/nfs-server.service → /usr/lib/systemd/system/nfs-server.service.

[root@kworkhorse ~]# systemctl start nfs-server
```

Verify:
```
[root@kworkhorse ~]# exportfs -v

/home/nfsshare/k8s-nfs-storageclass
		<world>(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,no_root_squash,no_all_squash)

```


## (IGNORE) - Create a storageclass.yaml file:

```
$ cat support-files/nfs-default-storageclass.yaml

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true" 
  name: nfs-storage
provisioner: example.com/external-nfs
parameters:
  server: "10.240.0.1"
  path: "/home/nfsshare/k8s-nfs-storageclass"
  readOnly: "false"
``` 


Create the storageclass:
```
$ kubectl apply -f support-files/nfs-default-storageclass.yaml 

storageclass.storage.k8s.io/nfs-storage created
```


Verify:

```
$ kubectl get storageclass

NAME                    PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-storage (default)   example.com/external-nfs   Delete          Immediate           false                  22s
```

Ideally, the pods and pvc controllers should see the new storageclass set as "default". But there will another problem with this setup. i.e. The PVC will wait for admin intervention.


## Deploy NFS subdir external provisioner:

Reference: [https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)

```
$ helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
```

You can examine the values from this chart:

```
$ helm show values nfs-subdir-external-provisioner/nfs-subdir-external-provisioner
replicaCount: 1
strategyType: Recreate

image:
  repository: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner
  tag: v4.0.2
  pullPolicy: IfNotPresent
imagePullSecrets: []

nfs:
  server:
  path: /nfs-storage
  mountOptions:
  volumeName: nfs-subdir-external-provisioner-root
  # Reclaim policy for the main nfs volume
  reclaimPolicy: Retain

# For creating the StorageClass automatically:
storageClass:
  create: true

  # Set a provisioner name. If unset, a name will be generated.
  # provisionerName:

  # Set StorageClass as the default StorageClass
  # Ignored if storageClass.create is false
  defaultClass: false

  # Set a StorageClass name
  # Ignored if storageClass.create is false
  name: nfs-client

  # Allow volume to be expanded dynamically
  allowVolumeExpansion: true

  # Method used to reclaim an obsoleted volume
  reclaimPolicy: Delete

  # When set to false your PVs will not be archived by the provisioner upon deletion of the PVC.
  archiveOnDelete: true

  # If it exists and has 'delete' value, delete the directory. If it exists and has 'retain' value, save the directory.
  # Overrides archiveOnDelete.
  # Ignored if value not set.
  onDelete:

  # Specifies a template for creating a directory path via PVC metadata's such as labels, annotations, name or namespace.
  # Ignored if value not set.
  pathPattern:

  # Set access mode - ReadWriteOnce, ReadOnlyMany or ReadWriteMany
  accessModes: ReadWriteOnce

  # Storage class annotations
  annotations: {}

leaderElection:
  # When set to false leader election will be disabled
  enabled: true

## For RBAC support:
rbac:
  # Specifies whether RBAC resources should be created
  create: true

# If true, create & use Pod Security Policy resources
# https://kubernetes.io/docs/concepts/policy/pod-security-policy/
podSecurityPolicy:
  enabled: false

# Deployment pod annotations
podAnnotations: {}

## Set pod priorityClassName
# priorityClassName: ""

serviceAccount:
  # Specifies whether a ServiceAccount should be created
  create: true

  # Annotations to add to the service account
  annotations: {}

  # The name of the ServiceAccount to use.
  # If not set and create is true, a name is generated using the fullname template
  name:

resources: {}
  # limits:
  #  cpu: 100m
  #  memory: 128Mi
  # requests:
  #  cpu: 100m
  #  memory: 128Mi

nodeSelector: {}

tolerations: []

affinity: {}

# Additional labels for any resource created
labels: {}
```


If you want, you can build a values file, and adjust it:
```
$ helm show values nfs-subdir-external-provisioner/nfs-subdir-external-provisioner > support-files/nfs-provisioner_values.yaml
```

At the moment, we can use command line switches to change certain values of this chart, as shown below. This eliminates the need for a values file. In production environments (or in general) it is a good practice to contain configuration in a values file, and not pass it on the command line.

```
$ helm install nfs-provisioner \
    nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=10.240.0.1 \
    --set nfs.path=/home/nfsshare/k8s-nfs-storageclass \
    --set storageClass.name=nfs-storage \
    --set storageClass.defaultClass=true \
    --namespace=kube-system

```

Actual run:
```
$ helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

"nfs-subdir-external-provisioner" has been added to your repositories
```


```
$ helm install nfs-provisioner \
    nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=10.240.0.1 \
    --set nfs.path=/home/nfsshare/k8s-nfs-storageclass \
    --set storageClass.name=nfs-storage \
    --set storageClass.defaultClass=true \
    --namespace=kube-system

NAME: nfs-provisioner
LAST DEPLOYED: Fri Oct 29 13:09:25 2021
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Now, you will see a new/additional storageclass:

```
$ kubectl get storageclass

NAME                    PROVISIONER                                                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-storage (default)   cluster.local/nfs-provisioner-nfs-subdir-external-provisioner   Delete          Immediate           true                   2m38s
```


Test:

```
$ cat support-files/nfs-test-claim.yaml 
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-claim
spec:
  storageClassName: nfs-client
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Mi
```


```
$ kubectl apply -f support-files/nfs-test-claim.yaml
 
persistentvolumeclaim/test-claim created
```

```
$ kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE

test-claim   Bound    pvc-06cad08d-f2ff-4e10-ae6e-d0d800e9a2c4   10Mi       RWX            nfs-storage    5s

```

On the NFS server:

```
[root@kworkhorse ~]# ls -l /home/nfsshare/k8s-nfs-storageclass/
total 4
drwxrwxrwx 2 root root 4096 Oct 28 22:01 default-test-claim-pvc-5ec45fe0-c194-4455-9aad-777916a00184
```



## Set a storageclass as "default":

You can set a certain storageClass as default, while ensuring that there can be only one default storageClass at any given time. If you have multiple storageClass-es, then you can manipulate as shown below.

First unset old storageclass as "default":

```
$ kubectl patch storageclass test-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```


Then set the new one as default:

```
$ kubectl patch storageclass nfs-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

storageclass.storage.k8s.io/nfs-storage patched
```

Verify:
```
[kamran@kworkhorse kubernetes-katas]$ kubectl get storageclass
NAME                   PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-storage (default)   cluster.local/nfs-subdir-external-provisioner   Delete          Immediate           true                   13m
test-storage            example.com/external-nfs                        Delete          Immediate           false                  17m
[kamran@kworkhorse kubernetes-katas]$ 
```

This should work.
