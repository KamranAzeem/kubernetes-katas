# Kubernetes health checks

In this document we will cover:
* readinessProbe
* livenessProbe
* startupProbe
* wbitt/k8s-probes-demo with a "troublemaker" tool


## Whats wrong with having no Readiness probes?

Suppose we have a simple deployment.

```
$ cat site-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: witpass-co-uk
  labels:
    app: witpass-co-uk
    
spec:
  selector:
    matchLabels:
      app: witpass-co-uk
  template:
    metadata:
      labels:
        app: witpass-co-uk
    spec:
      containers:
      - name: witpass-co-uk 
        image: witline/witpass-co-uk
          
        ports:
        - name: http 
          containerPort: 80

        resources:
          limits:
            cpu: 50m
            memory: 32Mi
          requests:
            cpu: 10m
            memory: 64Mi
```

We deploy this using kubectl and check it's status. 

```
$ kubectl apply -f site-deployment.yaml


$ kubectl get pods

witpass-co-uk-df8c8cbd8-gnfns   1/1   Running   0  5sec
```

We also check the URL through a browser immediately, and see that it shows **"Bad Gateway"** (502) instead of the normal web page that we expected.

```
$ curl http://witpass.co.uk

Bad Gateway
```

However, a minute later, we see that the site is working:

```
$ curl http://witpass.co.uk

Welcome to WITPASS!
```


So, even though Kubernetes reported the pod as Ready, and Running, the service is not responding as expected. So what is happening?


The container in this example does some "prep-work" before the web-server process (apache) actually started. The prep-work takes somewhere between 20-50 seconds. Any attempt to access the service during the "prep-work" phase results in "Bad Gateway" (Error 502); though, Kubernetes declared the container "Ready/Running" as soon as deployment was created!

Some more explanation before we move on to solving this problem.

## Deployment, service and endpoint:


```
$ kubectl apply -f support-files/health-checks/nginx.yaml 
deployment.apps/nginx created
service/nginx created

```

```
$ kubectl get pods -w
NAME                         READY   STATUS    RESTARTS        AGE
multitool-7f8c7df657-gb942   1/1     Running   2 (4d13h ago)   6d2h

nginx-ccb4668fc-c577j        0/1     Pending   0               0s
nginx-ccb4668fc-c577j        0/1     ContainerCreating   0               0s
nginx-ccb4668fc-c577j        1/1     Running             0               16s
```


```
$ kubectl get svc -w
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   68d

nginx        ClusterIP   10.103.57.243   <none>        80/TCP    0s
```


```
$ kubectl get endpoints -w
NAME         ENDPOINTS           AGE
kubernetes   192.168.49.2:8443   68d

nginx        <none>              0s
nginx        10.244.0.75:80      16s
```


Notice that the pod takes about 16 seconds to be in the Running state. The service `nginx` was created as soon as the pod was in the `ContainerCreating` mode, but gets an update about it's endpoint only after the service is in the `Running` state, which took `16` seconds in the above example.

This means if we would have accessed the service while it was being created, we would have got a "Bad Gateway", or "unreachable" sort of message.

```
$ kubectl exec -it multitool-7f8c7df657-gb942 -- bash

multitool-7f8c7df657-gb942:/# curl -s nginx | grep title

curl: (7) Failed to connect to nginx port 80 after 2 ms: Couldn't connect to server
```



Once it is started and Running, we can access the service and can see that it works.

```
$ kubectl exec -it multitool-7f8c7df657-gb942 -- bash

multitool-7f8c7df657-gb942:/# curl -s nginx | grep title

<title>Welcome to nginx!</title>
```

So, how to make sure that the service is really ready before it is announced as "ready" ? 

## Kubernetes `readinessProbe`:

Readiness probes help Kubernetes know when to start sending traffic to the pod. This probe helps kubernetes to "add" or "remove" this pod from the service in front of it. So, when the probe passes it is added to the service, when it fails at any time in it's life, kubernetes removes it from it's service load balancers.

Restarting a "stuck" container is the job of `livenessProbe`, explained later.

**Note:** Readiness probe runs throughout the life of the container - every "periodSeconds", not just at the container start time!
        
With `readinessProbe`, you only declare the container "Ready" when it is *really ready* to serve requests. A pod may be a single-container, or multi-container, but when `readinessProbe` fails for any single container inside a pod, the entire pod is considered **"Not Ready"**.

Examples:
* Ready: 0/1 or 1/1
* Ready: 0/2 or 1/2 or 2/2


```
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5

          # Retry the probe every X seconds (frequency):
          periodSeconds: 2

          # Number of times this probe can fail ,
          #   before kubernetes gives up and marks the "pod" as "Unready":
          failureThreshold: 30

          # In the case above, the Pod will be marked "Unready",
          #   if the probe does not pass 2 x 30 = 60 seconds.
          successThreshold: 1

```


**Note:** You should not use small values for `periodSeconds`, else your logs will ﬁll up rapidly with useless "probe" entries. This is shown in the code snippet below.


To understand `readinessProbe`, we have a small example which uses a special container image to help understand this concept. The container image has three special `.txt` files we will use with different type of health checks.


First, delete the previous `nginx` deployment.

```
$ kubectl delete -f nginx.yaml 

deployment.apps "nginx" deleted
service "nginx" deleted
```


Create deployment using the file `readiness-simple.yaml`. It looks like this:


```
$ cat readiness-simple.yaml 

apiVersion: apps/v1
kind: Deployment
metadata:
  name: readiness-simple
  labels:
    app: readiness-simple
    
spec:
  selector:
    matchLabels:
      app: readiness-simple
  template:
    metadata:
      labels:
        app: readiness-simple
    spec:
      containers:
      - name: readiness-simple
        image: wbitt/k8s-probes-demo:latest

        env:
        - name: START_DELAY
          value: "30"

        ports:
        - name: http 
          containerPort: 80

        resources:
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 5m
            memory: 20Mi
        readinessProbe:
          httpGet:
            path: /readinesscheck.txt
            port: 80

          initialDelaySeconds: 5

          # Retry the probe every X seconds (frequency):
          periodSeconds: 2

          # Number of times this probe can fail ,
          #   before kubernetes gives up and marks the "pod" as "Unready":
          failureThreshold: 30

          # In the case above, the Pod will be marked "Unready",
          #   if the probe does not pass 2 x 30 = 60 seconds.
          successThreshold: 1

---

apiVersion: v1
kind: Service
metadata:
  name: readiness-simple
  labels:
    app: readiness-simple
spec:
  ports:
    - port: 80
  selector:
    app: readiness-simple
  type: ClusterIP        

```



```
$ kubectl apply -f readiness-simple.yaml

deployment.apps/readiness-simple created
service/readiness-simple created
```


If we access the service within few seconds, the service will not be accessible:

```
$ kubectl exec -it multitool-7f8c7df657-gb942 -- bash

multitool-7f8c7df657-gb942:/# curl readiness-simple

curl: (7) Failed to connect to readiness-simple port 80 after 1 ms: Couldn't connect to server
```


However after about 45 seconds, it works:

```
multitool-7f8c7df657-gb942:/# curl readiness-simple

<h1>24-01-2024_13:39:26 - Kubernetes probes demo - Web service started</h1>
```


Notice that the continer was created in about `1 second`, which is probably the time it took to pull the container image from the docker hub. Then, it started running `12 seconds` after creation, though it was still not **"READY"** until about `43 seconds`. That is when it's related service received the IP address of the running pod as it's endpoint. It took so much time to start, because we introduced a intentional **delay** of `30 seconds` before the nginx process inside the container could be started. While it waited, Kubernetes `readinessProbe` first gave it a grace time of `5 seconds` to start, and when it could not access a certain URL on a certain port, it kept checking it every `2 seconds`. The `30 second` artificial delay eventually was over and the the `readinessProbe` passed, and that in-turn declared the pod container/pod to be healthy. Kubernetes saw this and then used the IP of the container/pod for the endpoint of it's service and everything worked as expected.

The configuration of the `readinessProbe` above will declare the container as "NotReady", if readinessProbe does not succeed for `5s + (2s x 30) = 65s (seconds)`. 

```
$ kubectl get pods -w
NAME                         READY   STATUS    RESTARTS        AGE
multitool-7f8c7df657-gb942   1/1     Running   2 (4d14h ago)   6d3h

readiness-simple-86d5c6486c-87vft   0/1     Pending   0               0s
readiness-simple-86d5c6486c-87vft   0/1     Pending   0               0s
readiness-simple-86d5c6486c-87vft   0/1     ContainerCreating   0               1s
readiness-simple-86d5c6486c-87vft   0/1     Running             0               12s
readiness-simple-86d5c6486c-87vft   1/1     Running             0               43s
```


```
$ kubectl get svc -w

NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   68d

readiness-simple   ClusterIP   10.98.62.211   <none>        80/TCP    0s
```


```
$ kubectl get endpoints -w

NAME         ENDPOINTS           AGE
kubernetes   192.168.49.2:8443   68d

readiness-simple   <none>              0s
readiness-simple                       12s
readiness-simple   10.244.0.80:80      43s
```

Lets delete the deployment, change the `START_DELAY` environment variable to `120 seconds` in the YAML file, and see what happens.


```
$ kubectl delete -f readiness-simple.yaml
deployment.apps "readiness-simple" deleted
service "readiness-simple" deleted
```


```
$ kubectl apply -f readiness-simple.yaml
deployment.apps/readiness-simple created
service/readiness-simple created
```


### More about `readinessProbe`:
* `readinessProbe` has been available in Kubernetes since version `1.0`
* `readinessprobe` runs on the container during its entire lifecycle.
* There are different types of `readinessProbe`:
  * HTTPGet
  * TCPSocket
  * Exec
* Containers needing prep-work before they start serving, should employ `readinessProbe`.
* Use cases: 
  * `Statefulsets` scale one at the time, controlled by readiness. When no readiness probes are
present, it will scale really fast, and might break the application. e.g. Scaling Atlassian Confluence from 2 to 5 replicas. 
  * Same is true for increasing replicas of a `deployment`, or upgrading deployments. If no readiness probes are configured, you risk exposing a service with "non-ready" endpoints.


Examples of different types of `readinessprobe`:

```
readinessProbe:
  httpGet:
    path: /healthy
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```


```
readinessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 5
  periodSeconds: 5
```


```
readinessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

Reference: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

