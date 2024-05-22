# Service Discovery and Loadbalancing
In almost every Kubernetes cluster, there is an addon called CoreDNS (previously KubeDNS), which provides service discovery within the cluster, using DNS mechanism. Every time a *service* is created in kubernetes cluster, it is registered in CoreDNS with the name of the service, it's ClusterIP. e.g. `nginx.default.svc.cluster.local` . There will be more on this later. Each service will have a name, a clusterIP, and also the list of backends linked with this service. 

The kubernetes *service* also acts as an internal load balancer, when the service has more than one endpoints. e.g. A nginx deployment can have four replicas. When exposed as a service, the service will have four endpoints, which are the IP addresses of the pods. When this service is accessed by a client (a pod or any other process), the service does load balancing between these endpoints. A service and it's endpoints are shown below:


```
$ kubectl create deployment nginx --image=nginx:1.9 --replicas=4

$ kubectl get deployments
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
nginx     4/4     4            4           5m14s

$ kubectl expose deployment nginx --port=80

$ kubectl get svc
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.109.0.1     <none>        443/TCP   9d
nginx        ClusterIP   10.109.2.103   <none>        80/TCP    16s


$ kubectl get svc
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.109.0.1     <none>        443/TCP   9d
nginx        ClusterIP   10.109.2.103   <none>        80/TCP    16s

$ kubectl get endpoints
NAME         ENDPOINTS                                               AGE
kubernetes   10.154.0.10:443                                         9d
nginx        10.44.1.21:80,10.44.2.19:80,10.44.2.20:80 + 1 more...   31s
```

## Types of a kubernetes service:
To access the actual process/service inside any given pod (e.g. nginx web service), we need to *expose* the related deployment as a kubernetes *service*. We have three main ways of exposing the deployment , or in other words, we have three ways to define a *service*. We can access these three types of services in three different ways. The three types of services are:

* ClusterIP
* NodePort
* LoadBalancer

### Service type: ClusterIP
Lets expose the deployment as a service - type=ClusterIP:

```
$ kubectl expose deployment nginx --port 80 --type ClusterIP
service "nginx" exposed
```

Check the list of services:

```
$ kubectl get services
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   100.64.0.1       <none>        443/TCP   2d
nginx        ClusterIP   100.70.204.237   <none>        80/TCP    4s
```

Notice, there are two services listed here. The first one is named **kubernetes**, which is the default service created (automatically) when a kubernetes cluster is created for the first time. It does not have any EXTERNAL-IP. This service is not our focus right now.

The service in focus is nginx, which does not have any external IP, nor does it say anything about any other ports except 80/TCP. This means it is not accessible over internet, but we can still access it from within cluster , using the service IP, not the pod IP. Lets see if we can access this service from our multitool.

```
[root@multitool-3148954972-k8q06 /]# curl -s 100.70.204.237 | grep h1
<h1>Welcome to nginx!</h1>
[root@multitool-3148954972-k8q06 /]# 
```

It worked! 


You can also access the same service using it's DNS name:

```
[root@multitool-3148954972-k8q06 /]# curl -s nginx.default.svc.cluster.local  | grep h1
<h1>Welcome to nginx!</h1>
[root@multitool-3148954972-k8q06 /]# 
```

You can also use the `describe` command to describe any Kubernetes object in more detail. e.g. we use `describe` to see more details about our nginx service:

```
$ kubectl describe service nginx
Name:              nginx
Namespace:         default
Labels:            app=nginx
Annotations:       <none>
Selector:          app=nginx
Type:              ClusterIP
IP:                100.70.204.237
Port:              <unset>  80/TCP
TargetPort:        80/TCP
Endpoints:         100.96.1.148:80
Session Affinity:  None
Events:            <none>
```

**Additional notes about the Cluster-IP:**
* The IPs assigned to services as Cluster-IP are from a different Kubernetes network called *Service Network*, which is a completely different network altogether. i.e. it is not connected (nor related) to pod-network or the infrastructure network. Technically it is actually not a real network per-se; it is a labelling system, which is used by Kube-proxy on each node to setup correct iptables rules. (This is an advanced topic, and not our focus right now).
* No matter what type of service you choose while *exposing* your deployment, Cluster-IP is always assigned to that particular service.
* Every service has end-points, which point to the actual pods service as a backend of a particular service.
* As soon as a service is created, and is assigned a Cluster-IP, an entry is made in Kubernetes' internal DNS against that service, with this service name and the Cluster-IP. e.g. `nginx.default.svc.cluster.local` would point to `100.70.204.237` . 


### Service type: NodePort

Our nginx service is still not reachable from outside, so now we re-create this service as NodePort.

```
$ kubectl get svc
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   100.64.0.1       <none>        443/TCP   17h
nginx        ClusterIP   100.70.204.237   <none>        80/TCP    15m
```

```
$ kubectl delete svc nginx
service "nginx" deleted
```

```
$ kubectl expose deployment nginx --port 80 --type NodePort
service "nginx" exposed
```

```
$ kubectl get svc
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   100.64.0.1     <none>        443/TCP        17h
nginx        NodePort    100.65.29.172  <none>        80:32593/TCP   8s
```

Notice that we still don't have an external IP, but we now have an extra port `32593` for this pod. This port is a **NodePort** exposed on the worker nodes. So now, if we know the IP of our nodes, we can access this nginx service from the internet. First, we find the public IP of the nodes:
```
$ kubectl get nodes -o wide
NAME                                            STATUS    ROLES     AGE       VERSION        EXTERNAL-IP     OS-IMAGE                             KERNEL-VERSION   CONTAINER-RUNTIME
gke-dcn-cluster-35-default-pool-dacbcf6d-3918   Ready     <none>    17h       v1.8.8-gke.0   35.205.22.139   Container-Optimized OS from Google   4.4.111+         docker://17.3.2
gke-dcn-cluster-35-default-pool-dacbcf6d-c87z   Ready     <none>    17h       v1.8.8-gke.0   35.187.90.36    Container-Optimized OS from Google   4.4.111+         docker://17.3.2
```

Even though we have only one pod (and two worker nodes), we can access any of the node with this port, and it will eventually be routed to our pod. So, lets try to access it from our local work computer:

```
$ curl -s 35.205.22.139:32593 | grep h1
<h1>Welcome to nginx!</h1>
```

It works!

### Service type: LoadBalancer
So far so good; but, we do not expect the users to know the IP addresses of our worker nodes. It is not a flexible way of doing things. So we re-create the service as `type=LoadBalancer`. The type LoadBalancer is only available for use, if your k8s cluster is setup in any of the public cloud providers, GCE, AWS, etc.

```
[demo@kworkhorse exercises]$ kubectl delete svc nginx
service "nginx" deleted
```

```
$ kubectl expose deployment nginx --port 80 --type LoadBalancer
service "nginx" exposed
```

```
$ kubectl get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP      100.64.0.1     <none>        443/TCP        17h
nginx        LoadBalancer   100.69.15.89   <pending>     80:31354/TCP   5s
```

In few minutes of time the external IP will have some value instead of the word 'pending' . 
```
$ kubectl get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP      100.64.0.1     <none>        443/TCP        17h
nginx        LoadBalancer   100.69.15.89   35.205.60.29  80:31354/TCP   5s

```

Now, we can access this service without using any special port numbers:
```
[demo@kworkhorse exercises]$ curl -s 35.205.60.29 | grep h1
<h1>Welcome to nginx!</h1>
[demo@kworkhorse exercises]$
```

**Additional notes about LoadBalancer:**
* A service defined as LoadBalancer will still have some high-range port number assigned to it's main service port, just like NodePort. This has a clever purpose, but is an advance topic and is not our focus at this point.


## High Availability / Load balancing

To prove that multiple pods of the same deployment provide high availability, we do a small exercise. To visualize it, we need to run a small web server which could return us some unique content when we access it. We will use our trusted multitool for it. Lets run it as a separate deployment and access it from our local computer.

```
$ kubectl create deployment simplewebserver --image=wbitt/network-multitool
deployment.apps/simplewebserver created

$ kubectl scale deployment simplewebserver --replicas=4
deployment.apps/simplewebserver scaled
```

```
$ kubectl get pods
$ kubectl get pods
NAME                              READY   STATUS    RESTARTS   AGE
multitool-67879794bc-khw6j        1/1     Running   0          102m
simplewebserver-f758df4b7-mbb58   1/1     Running   0          6s
simplewebserver-f758df4b7-mvcpl   1/1     Running   0          6s
simplewebserver-f758df4b7-q976d   1/1     Running   0          118s
simplewebserver-f758df4b7-swpbq   1/1     Running   0          6s
```

Lets create a service for this deployment as a type=LoadBalancer:


**Note:** The service of type LoadBalancer is only used to be able to access this service from the internet. This load balancing feature is built into all three service types.

```
$ kubectl expose deployment simplewebserver --port=80 --type=LoadBalancer
service/simplewebserver exposed
```

Verify the service and note the public IP address:

```
$ kubectl get services
NAME              TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)        AGE
kubernetes        ClusterIP      10.109.0.1    <none>           443/TCP        3y248d
simplewebserver   LoadBalancer   10.109.6.56   34.105.211.152   80:31519/TCP   48s
```

Query the service, so we know it works as expected:

```
$ curl -s 34.105.211.152 | grep IP

WBITT Network MultiTool (with NGINX) - simplewebserver-f758df4b7-q976d - 10.44.1.33 - HTTP: 80 , HTTPS: 443 . (Formerly praqma/network-multitool)
```

Next, setup a small bash loop on your local computer to curl this IP address, and get it's IP address.

```
$ while true; do sleep 1; curl -s 34.105.211.152; done

WBITT Network MultiTool (with NGINX) - simplewebserver-f758df4b7-swpbq - 10.44.2.27 - HTTP: 80 , HTTPS: 443 . (Formerly praqma/network-multitool)
WBITT Network MultiTool (with NGINX) - simplewebserver-f758df4b7-q976d - 10.44.1.33 - HTTP: 80 , HTTPS: 443 . (Formerly praqma/network-multitool)
WBITT Network MultiTool (with NGINX) - simplewebserver-f758df4b7-mbb58 - 10.44.1.34 - HTTP: 80 , HTTPS: 443 . (Formerly praqma/network-multitool)
WBITT Network MultiTool (with NGINX) - simplewebserver-f758df4b7-swpbq - 10.44.2.27 - HTTP: 80 , HTTPS: 443 . (Formerly praqma/network-multitool)
WBITT Network MultiTool (with NGINX) - simplewebserver-f758df4b7-swpbq - 10.44.2.27 - HTTP: 80 , HTTPS: 443 . (Formerly praqma/network-multitool)
WBITT Network MultiTool (with NGINX) - simplewebserver-f758df4b7-swpbq - 10.44.2.27 - HTTP: 80 , HTTPS: 443 . (Formerly praqma/network-multitool)
^C
```

Or:

```
$ while true; do sleep 2; curl -s 34.105.211.152 | cut -d\- -f 5; done
 10.44.1.33 
 10.44.1.33 
 10.44.1.33 
 10.44.2.28 
 10.44.1.33 
 10.44.2.28 
 10.44.1.33 
 10.44.1.33 
 10.44.2.27 
 10.44.1.34 
```

We see that when we query the LoadBalancer IP, it is giving us result/content from all four containers. 

Now, if we kill three out of four pods, the service should still respond, without timing out. We let the loop run in a separate terminal, and kill three pods of this deployment from another terminal.

```
$ kubectl delete pod simplewebserver-f758df4b7-mbb58 simplewebserver-f758df4b7-mvcpl simplewebserver-f758df4b7-q976d 
pod "simplewebserver-f758df4b7-mbb58" deleted
pod "simplewebserver-f758df4b7-mvcpl" deleted
pod "simplewebserver-f758df4b7-q976d" deleted

```

Immediately check the other terminal for any failed curl commands or timeouts.

```
 10.44.2.29 
 10.44.2.29 
 10.44.2.29 
 10.44.2.27 
 10.44.2.29 
 10.44.1.36 
 10.44.2.29 
 10.44.2.27 
 10.44.2.29 
 10.44.1.35 
 10.44.2.29 
```

We notice that no curl command failed, and actually we have started seeing new IPs. Why is that? It is because, as soon as the pods are deleted, the deployment sees that it's desired state is four pods, and there is only one running, so it immediately starts three more to reach that desired state. And, while the pods are in process of starting, one surviving pod takes the traffic.

```
$ kubectl get pods
NAME                              READY   STATUS    RESTARTS   AGE
multitool-67879794bc-khw6j        1/1     Running   0          129m
simplewebserver-f758df4b7-4cqg6   1/1     Running   0          84s
simplewebserver-f758df4b7-sq8fp   1/1     Running   0          84s
simplewebserver-f758df4b7-swpbq   1/1     Running   0          27m
simplewebserver-f758df4b7-vdfjg   1/1     Running   0          84s
```

This clearly shows Kubernets provides us High Availability, using multiple replicas of a pod.

## Clean up

Delete deployments and services as follow:

```
kubectl delete deployment simplewebserver
kubectl delete deployment multitool
kubectl delete service simplewebserver
```
