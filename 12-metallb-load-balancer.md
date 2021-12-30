# Metallb - Load Balancer for bare-metal:

It is expected that your Kubernetes cluster is up and running.

## Ensure that you have helm installed on your work computer:

```
$ helm version
version.BuildInfo{Version:"v3.2.0", GitCommit:"e11b7ce3b12db2941e90399e874513fbd24bcb71", GitTreeState:"clean", GoVersion:"go1.13.10"}
```



## Add Metallb helm repository:

```
helm repo add metallb https://metallb.github.io/metallb
```

## Setup values.yaml file:

```
$ vi support-files/metallb-values.yaml

configInline:
  address-pools:
   - name: default
     protocol: layer2
     addresses:
     - 10.240.0.100-10.240.0.200
``` 


## Create a dedicated namespace:

```
$ kubectl create namespace metallb
namespace/metallb created
```

## Install metallb using `values.yaml` file:

```
$ helm install metallb metallb/metallb --namespace metallb -f support-files/metallb-values.yaml 
NAME: metallb
LAST DEPLOYED: Thu Oct 28 16:16:36 2021
NAMESPACE: metallb
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
MetalLB is now running in the cluster.
LoadBalancer Services in your cluster are now available on the IPs you
defined in MetalLB's configuration:

config:
  address-pools:
  - addresses:
    - 10.240.0.100-10.240.0.200
    name: default
    protocol: layer2

To see IP assignments, try `kubectl get services`.
```


## Verify:

```
$ helm list --all-namespaces=true
NAME   	NAMESPACE	REVISION	UPDATED                                 	STATUS  	CHART         	APP VERSION
metallb	metallb  	1       	2021-10-28 16:16:36.801969827 +0200 CEST	deployed	metallb-0.10.3	v0.10.3    
```


**Note:** Below, the daemonset shows two (2) instances, because there were total of two worker nodes active at this point in time.

```
$ kubectl --namespace=metallb get all
NAME                                     READY   STATUS    RESTARTS   AGE
pod/metallb-controller-dbdc8b7db-n57l7   1/1     Running   0          47s
pod/metallb-speaker-7prwh                1/1     Running   0          47s
pod/metallb-speaker-k9tq4                1/1     Running   0          47s

NAME                             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/metallb-speaker   2         2         2       2            2           kubernetes.io/os=linux   47s

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/metallb-controller   1/1     1            1           47s

NAME                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/metallb-controller-dbdc8b7db   1         1         1       47s
```


## Create a service for an application - `--type=LoadBalancer`:

```
$ kubectl get pods
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          8m
```


```
$ kubectl expose pod nginx --port 80 --type LoadBalancer
service/nginx exposed
```

```
$ kubectl get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)        AGE
kubernetes   ClusterIP      10.32.0.1      <none>         443/TCP        4h42m
nginx        LoadBalancer   10.32.108.93   10.240.0.100   80:30025/TCP   5s
```

## Verify:
From local computer, access the load-balancer IP address.

```
$ curl -s 10.240.0.100 | grep title
<title>Welcome to nginx!</title>
```


Hurray! It works!

