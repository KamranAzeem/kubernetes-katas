This exercise/kata covers:

* Pod creation / deletion
* Deployments
* Logging into the pods/containers
* Viewing logs of the pods/containers

# Pods and Deployments:

A **Pod** (*not container*) is the basic building-block/worker-unit in Kubernetes. *Normally* a pod is a part of a **Deployment**. 

## Creating pods using 'run' command:
We start by creating our first deployment. Normally people will run an nginx container/pod as first example o deployment. You can surely do that. But, we will run a different container image as our first exercise. The reason is that it will work as a multitool for testing and debugging throughout this course. Besides it too runs nginx! 


Here is the command to do it:

```
kubectl run multitool  --image=wbitt/network-multitool
```

You should be able to see the following output:

```
$ kubectl run multitool --image=wbitt/network-multitool 
pod/multitool created
```

This command creates a pod named multitool, starts the pod using this docker image (wbitt/network-multitool).

List of pods:
```
$ kubectl get pods
NAME                         READY     STATUS    RESTARTS   AGE
multitool                    1/1       Running   0          3m
```

Delete the pod:

```
$ kubectl  delete pod multitool 
pod "multitool" deleted
```

When you delete a pod (which is not a member of a deployment), it is not recreated.

Next, create a deployment. A deployment in-turn creates a replicaset, which in-turn creates the pod(s). 

```
$ kubectl create deployment multitool  --image=wbitt/network-multitool
deployment.apps/multitool created
```

List of pods:

```
$ kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
multitool-67879794bc-h2lmb   1/1     Running   0          2m32s
```

List of deployments:
```
$ kubectl get deployments
NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
multitool   1         1         1            1           3m
```

List of replicasets:

```
$ kubectl get replicasets
NAME                   DESIRED   CURRENT   READY   AGE
multitool-67879794bc   1         1         1       3m18s
```

If you kill / delete the pod (or if it dies or crashes), Kubernetes will recreate it automatically. This is the "Kubernetes Promise" fulfilled.

```
$ kubectl delete pod multitool-67879794bc-h2lmb 
pod "multitool-67879794bc-h2lmb" deleted


$ kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
multitool-67879794bc-khw6j   1/1     Running   0          3s
```

To check how the internals of a deployment looks like, you can always use the `describe` command:

```
$ kubectl describe deployment multitool

Name:                   multitool
Namespace:              default
CreationTimestamp:      Wed, 17 Jan 2024 11:52:19 +0100
Labels:                 app=multitool
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=multitool
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=multitool
  Containers:
   network-multitool:
    Image:        wbitt/network-multitool
    Port:         <none>
    Host Port:    <none>
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
OldReplicaSets:  <none>
NewReplicaSet:   multitool-67879794bc (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  25m   deployment-controller  Scaled up replica set multitool-67879794bc to 1
```

Lets setup another pod, a traditional nginx deployment, with a specific version - `1.7.9`. 


Setup an nginx deployment with nginx:1.7.9
```
kubectl create deployment nginx  --image=nginx:1.7.9
```

You get another deployment and a replicaset as a result of above command, shown below, so you know what to expect:

```
$ kubectl get pods,deployments,replicasets
NAME                            READY     STATUS    RESTARTS   AGE
po/multitool-3148954972-k8q06   1/1       Running   0          25m
po/nginx-1480123054-xn5p8       1/1       Running   0          14s

NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/multitool   1         1         1            1           25m
deploy/nginx       1         1         1            1           14s

NAME                      DESIRED   CURRENT   READY     AGE
rs/multitool-3148954972   1         1         1         25m
rs/nginx-1480123054       1         1         1         14s
```


## Alternate / preffered way to deploy pods:
You can also use the `nginx-simple-deployment.yaml` file to create the same nginx deployment. The file is in suport-files directory of this repo. However before you execute the command shown below, note that it will try to create a deployment with the name **nginx**. If you already have a deployment named **nginx** running, as done in the previous step, then you will need to delete that first.

Delete the existing deployment using the following command:
```
$ kubectl get deployments
NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
multitool   1         1         1            1           32m
nginx       1         1         1            1           7m

$ kubectl delete deployment nginx
deployment "nginx" deleted
```

Now you are ready to proceed with the example below:

```
$ kubectl create -f nginx-simple-deployment.yaml 
deployment "nginx" created
```


The contents of `nginx-simple-deployment.yaml` are as follows:
```
$ cat nginx-simple-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```


Verify that the deployment is created:
```
$ kubectl get deployments
NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
multitool   1         1         1            1           59m
nginx       1         1         1            1           36s
```


Check if the pods are running:
```
$ kubectl get pods
NAME                         READY     STATUS    RESTARTS   AGE
multitool-3148954972-k8q06   1/1       Running   0          1h
nginx-431080787-9r0lx        1/1       Running   0          40s
```

## Deleting a pod, the kubernetes promise of resilience:

Before we move forward, lets see if we can delete a pod, and if it comes to life automatically:
```
$ kubectl delete pod nginx-431080787-9r0lx 
pod "nginx-431080787-9r0lx" deleted
```

As soon as we delete a pod, a new one is created, satisfying the desired state by the deployment, which is - it needs at least one pod running nginx. So we see that a **new** nginx pod is created (with a new ID):
```
$ kubectl get pods
NAME                         READY     STATUS              RESTARTS   AGE
multitool-3148954972-k8q06   1/1       Running             0          1h
nginx-431080787-tx5m7        0/1       ContainerCreating   0          5s

(after few more seconds)

$ kubectl get pods
NAME                         READY     STATUS    RESTARTS   AGE
multitool-3148954972-k8q06   1/1       Running   0          1h
nginx-431080787-tx5m7        1/1       Running   0          12s
```

## Creating a standalone pod:
Often times you will need to simply create a pod, without making it a member of a deployment or anything else. For those instances, here is how you would create a standalone pod.

```
apiVersion: v1
kind: Pod
metadata:
  name: standalone-nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
```

Save the above few lines of code as a yaml file, and use `kubectl create -f <filename>` to create this pod.

```
$ kubectl create -f support-files/standalone-nginx-pod.yaml 
pod "standalone-nginx-pod" created

$ kubectl get pods
NAME                   READY     STATUS    RESTARTS   AGE
standalone-nginx-pod   1/1       Running   0          4s
$
```

The example above will work with container images, which have some sort of daemon/service process running as their entrypoint. If you want to run something which does not have a **service process** in the container image, you can pass it a custom command, such as shown below: 

```
apiVersion: v1
kind: Pod
metadata:
  name: standalone-busybox-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'echo Hello Kubernetes! && sleep 3600']

```
The above code will create a pod, which will go into a sleep for 3600 seconds ( one hour), and will exit (die) silently. Good to know for troubleshooting/diagnostics.

```
$ kubectl create -f support-files/standalone-busybox-pod.yaml 
pod "standalone-busybox-pod" created
$

$ kubectl get pods
NAME                     READY     STATUS    RESTARTS   AGE
standalone-busybox-pod   1/1       Running   0          30s
$
```

PS. I have an excellent multitool for network (and container) troubleshooting. It is called `wbitt/network-multitool`, and it runs nginx web server, eliminating a need to pass any custom commands. You can run it like this:

```
$ kubectl create deployment multitool --image wbitt/network-multitool
```


## Exec into the pod/container:
Just like `docker exec`, you can `exec` into a kubernetes pod/container by using `kubectl exec`. This is a good way to troubleshoot any problems. All you need is the name of the pod (and container name - in case it is a multi-container pod). 

You can `exec` into the pod like so:

```
[kamran@kworkhorse ~]$ kubectl exec -it standalone-busybox-pod -- /bin/sh

/ # 
```

You can do a lot of troubleshooting after you exec (log) into the pod:
```
[kamran@kworkhorse ~]$ kubectl exec -it standalone-busybox-pod -- /bin/sh

/ # ls -l
total 16
drwxr-xr-x    2 root     root         12288 Feb 14 18:58 bin
drwxr-xr-x    5 root     root           360 Mar  8 12:51 dev
drwxr-xr-x    1 root     root            66 Mar  8 12:51 etc
drwxr-xr-x    2 nobody   nogroup          6 Feb 14 18:58 home
dr-xr-xr-x  127 root     root             0 Mar  8 12:51 proc
drwx------    1 root     root            26 Mar  8 12:55 root
dr-xr-xr-x   13 root     root             0 Mar  7 10:49 sys
drwxrwxrwt    2 root     root             6 Feb 14 18:58 tmp
drwxr-xr-x    3 root     root            18 Feb 14 18:58 usr
drwxr-xr-x    1 root     root            17 Mar  8 12:51 var

/ # nslookup yahoo.com
Server:		10.32.0.10
Address:	10.32.0.10:53

Non-authoritative answer:
Name:	yahoo.com
Address: 2001:4998:c:1023::4
Name:	yahoo.com
Address: 2001:4998:44:41d::4
/ # exit
$
```

An example of network-multitool: 
```
$ kubectl run multitool --image=wbitt/network-multitool 
deployment.apps "multitool" created

$ kubectl get pods
NAME                         READY     STATUS    RESTARTS   AGE
multitool-5558fd48d4-lggqg   1/1       Running   0          12s
standalone-busybox-pod       1/1       Running   0          13m
standalone-nginx-pod         1/1       Running   0          22m
$
```

```
$ kubectl exec -it multitool-5558fd48d4-lggqg -- /bin/bash

bash-4.4# dig +short yahoo.com
98.137.246.8
98.137.246.7
72.30.35.10
98.138.219.231
72.30.35.9
98.138.219.232
bash-4.4# 


bash-4.4# dig +short kubernetes.default.svc.cluster.local
10.32.0.1

bash-4.4# 
```


## Logs:
Logs can be very helpful in troubleshooting why a certain pod/container is not behaving the way you expect it to. You can check logs of the pods by using `kubectl logs [-f] <pod-name>`. E.g. to watch the logs of the nginx pod, you can do the following:

```
$ kubectl logs standalone-nginx-pod
10.200.2.4 - - [08/Mar/2019:13:15:18 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.61.1" "-"
$
```
The above example shows, that the nginx web service in this pod was accessed by a client with an IP `10.200.2.4` . 



## Accessing the pods:
Now the question comes, How can we access nginx webserver at port 80 in this pod? For now we can do it from within the cluster. First, we need to know the IP address of the nginx pod. We use the `-o wide` parameters with the `get pods` command:

```
$ kubectl get pods -o wide
NAME                         READY     STATUS    RESTARTS   AGE       IP             NODE
multitool-3148954972-k8q06   1/1       Running   0          1h        100.96.2.31    ip-172-20-60-255.eu-central-1.compute.internal
nginx-431080787-tx5m7        1/1       Running   0          12m       100.96.1.148   ip-172-20-49-54.eu-central-1.compute.internal
```

**Bonus info:** The IPs you see for the pods (e.g. 100.96.2.31) are private IPs and belong to something called *Pod Network*, which is a completely private network inside a Kubernetes cluster, and is not accessible from outside the Kubernetes cluster.

Now, we `exec` into our multitool, as shown below and use the `curl` command from the pod to access nginx service in the nginx pod:

```
$ kubectl exec -it multitool-3148954972-k8q06 -- bash

bash-4.4# curl -s 100.96.1.148 | grep h1
<h1>Welcome to nginx!</h1>
```

We accessed the nginx webserver in the nginx pod using another (multitool) pod in the cluster, because at this point in time the nginx web-service (running as pod) is not accessible through a *service*. Services are explained separately.


This concludes the exercise!

------------------

## Useful commands

```
    kubectl config get-contexts
    kubectl config use-context minikube
    kubectl version
    kubectl cluster-info
    kubectl get nodes
    kubectl get pods
    kubectl get all
    kubectl describe pod
    kubectl get events --sort-by=.metadata.creationTimestamp
    kubectl api-resources # kubectl 1.11+
    kubectl api-versions
```

Cheatsheat: [https://kubernetes.io/docs/reference/kubectl/cheatsheet/](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
