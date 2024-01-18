# Replicas and Rolling update:

## Create Deployment

Recreate the nginx deployment that we did earlier:

```
$ kubectl create deployment nginx --image=nginx:1.7.9
```

And, expose the pod using a service of type LoadBalancer or NodePort (remember that it might take a few minutes for the cloud infrastructure to deploy the load balancer, i.e. the
external IP might be shown as `pending`):

```
$ kubectl expose deployment nginx --port 80 --type LoadBalancer
```

Note down the loadbalancer IP from the services command:

```
$ kubectl get services
```

In case, you are doing this excercise on your local kubernetes clsuter (minikube, kubeadm, etc), then you can simply expose this service as NodePort and use the worker-node-name/IP:nodeport to achieve the same.

```
$ kubectl expose deployment nginx --port 80 --type NodePort
```

```
$ kubectl get services
NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.32.0.1     <none>        443/TCP        1h
nginx        NodePort    10.32.254.6   <none>        80:30900/TCP   7m
$ 
```


Increase the replicas to four:

```
$ kubectl scale deployment nginx --replicas=4
```

From another terminal on your machine check (using load balancer IP) which version is currently running and to see changes when rollout is happening:

```
$ while true; do  curl -sI 35.205.60.1  | grep Server; sleep 2; done
```

On local kubernetes cluster (minikube), it would be:
```
$ while true; do  curl -sI minikube-ip:30900  | grep Server; sleep 1; done
```


## Update Deployment

Rollout an update to  the image:

```
$ kubectl set image deployment nginx nginx=nginx:1.9.1 --record
```

Check the rollout status:

```
$ kubectl rollout status deployment nginx
```

Investigate rollout history:

```
$ kubectl rollout history deployment nginx
```

Try rolling out other image version by repeating the `set image` command from
above.  Suggested image versions are 1.12.2, 1.13.12, 1.14.1, 1.15.2.

Try also rolling out a version that does not exist:

```
$ kubectl set image deployment nginx nginx=nginx:100.200.300 --record
```

what happened - do the curl operation still work?  Investigate the running pods with:

```
$ kubectl get pods
```
You should see `ImagePullBackOff` under STATUS of some of the pods. 


## Undo Update

The rollout above using a non-existing image version caused some pods to be
non-functioning. Next, we will undo this faulty deployment. First, investigate
rollout history:

```
$ kubectl rollout history deployment nginx
```

Undo the rollout and restore the previous version:

```
$ kubectl rollout undo deployment nginx
```

Investigate the running pods:

```
$ kubectl get pods
```

## Clean up

Delete deployments and services as follow:

```
$ kubectl delete deployment nginx
$ kubectl delete service nginx
```
