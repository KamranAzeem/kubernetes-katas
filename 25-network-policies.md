# Network policies:

Network policies only work on supported CNI. 

We already have a `whoami` deployment with a service and ingress running in a test cluster.
```
$ kubectl -n dev get pods -o wide
NAME                      READY   STATUS    RESTARTS     AGE   IP           NODE                         NOMINATED NODE   READINESS GATES
whoami-79684c5dcc-4mphl   1/1     Running   1 (9d ago)   9d    10.200.0.5   pserver1.dgh.witpass.co.uk   <none>           <none>
```

```
$ kubectl -n dev get ingress
NAME                   CLASS     HOSTS                      ADDRESS         PORTS     AGE
whoami-http-redirect   traefik   whoami.dgh.witpass.co.uk   192.168.0.241   80        8d
whoami-https           traefik   whoami.dgh.witpass.co.uk   192.168.0.241   80, 443   7d16h
```

```
$ curl https://whoami.dgh.witpass.co.uk
Hostname: whoami-79684c5dcc-4mphl
IP: 127.0.0.1
IP: ::1
IP: 10.200.0.5
IP: fe80::6cd2:1dff:fe22:2d27
RemoteAddr: 10.200.0.28:45796
GET / HTTP/1.1
Host: whoami.dgh.witpass.co.uk
User-Agent: curl/8.0.1
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 88.90.185.188
X-Forwarded-Host: whoami.dgh.witpass.co.uk
X-Forwarded-Port: 443
X-Forwarded-Proto: https
X-Forwarded-Server: traefik-8466cf8974-wrdqs
X-Real-Ip: 88.90.185.188
```

**Note:** If you don't have something with an ingress in your test cluster, simply create a `whoami` deployment in the `dev` namespace. In this case, ignore the steps in this document that either mention ingress, or traffic coming from outside the cluster. For the sake of this exercise, a simple `whoami` deployment is enough.

```
$ kubectl -n dev create deployment whoami --image=docker.io/traefik/whoami
```


Next, create and apply the network policy shown below:

```
$ cat support-files/network-policies/network-policy-whoami-dev-ingress-egress.yaml 
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: whoami-ingress-and-egress-rules
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: whoami
  policyTypes:
  - Ingress
  - Egress

  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: multitool
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring

  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
    ports:
    - protocol: "TCP"
      port: 80
    - protocol: "TCP"
      port: 443
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - port: 53
      protocol: "TCP"
    - port: 53
      protocol: "UDP"

  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: prod
    ports:
    - protocol: "TCP"
      port: 5432
    - protocol: "TCP"
      port: 3306

```


```
$ kubectl  -n dev apply -f network-policy-whoami-dev-ingress-egress.yaml

networkpolicy.networking.k8s.io/whoami-ingress-and-egress-rules created
```


```
$ kubectl -n dev get networkpolicies
NAME                                      POD-SELECTOR   AGE
whoami-ingress-and-egress-rules           <none>         15s
```

Use `kubectl describe` to understand how the policy looks like. This helps fix defects/bugs/errors in network policy.

```
$ kubectl -n dev describe networkpolicy whoami-ingress-and-egress-rules

Name:         whoami-ingress-and-egress-rules
Namespace:    dev
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     app=whoami
  Allowing ingress traffic:
    To Port: <any> (traffic allowed to all ports)
    From:
      PodSelector: app=multitool
    ----------
    To Port: <any> (traffic allowed to all ports)
    From:
      NamespaceSelector: kubernetes.io/metadata.name=kube-system
    ----------
    To Port: <any> (traffic allowed to all ports)
    From:
      NamespaceSelector: kubernetes.io/metadata.name=monitoring
  Allowing egress traffic:
    To Port: 80/TCP
    To Port: 443/TCP
    To:
      IPBlock:
        CIDR: 0.0.0.0/0
        Except: 169.254.169.254/32
    ----------
    To Port: 53/TCP
    To Port: 53/UDP
    To:
      NamespaceSelector: kubernetes.io/metadata.name=kube-system
    ----------
    To Port: 5432/TCP
    To Port: 3306/TCP
    To:
      NamespaceSelector: kubernetes.io/metadata.name=prod

  Policy Types: Ingress, Egress
```


To verify that the network policy works as expected, lets access the  `whoami` ingress/service/pod in kubernetes:

```
$ curl https://whoami.dgh.witpass.co.uk
Hostname: whoami-79684c5dcc-4mphl
IP: 127.0.0.1
IP: ::1
IP: 10.200.0.5
IP: fe80::6cd2:1dff:fe22:2d27
RemoteAddr: 10.200.0.28:53744
GET / HTTP/1.1
Host: whoami.dgh.witpass.co.uk
User-Agent: curl/8.0.1
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 88.90.185.188
X-Forwarded-Host: whoami.dgh.witpass.co.uk
X-Forwarded-Port: 443
X-Forwarded-Proto: https
X-Forwarded-Server: traefik-8466cf8974-wrdqs
X-Real-Ip: 88.90.185.188
```

It works. Good!

Create a deployment with the name `multitool` in the `dev` namespace. Kubernetes will automatically assign it a label `app: multitool`.

```
$ kubectl -n dev create deployment multitool --image=wbitt/network-multitool
deployment.apps/multitool created
```

Then, access the `whoami` service in `dev` namespace using this newly-created `multitool` pod. It should work, because the network policy assigned/applied to the `whoami` pod allows connection from the pods from the same ( `dev` ) namespace, where the pods have the label `app: multitool`.

```
$ kubectl -n dev exec multitool-7f8c7df657-w8659 -- curl -s 10.200.0.5

Hostname: whoami-79684c5dcc-4mphl
IP: 127.0.0.1
IP: ::1
IP: 10.200.0.5
IP: fe80::6cd2:1dff:fe22:2d27
RemoteAddr: 10.200.0.48:53128
GET / HTTP/1.1
Host: 10.200.0.5
User-Agent: curl/8.2.1
Accept: */*
```



Now, create a new multitool deployment with a different name `mytool` in the `dev` namespace. Kubernetes will automatically assign it a label `app: mytool`.

```
$ kubectl -n dev create deployment mytool --image=wbitt/network-multitool

deployment.apps/mytool created
```

Try accessing the `whoami` service running in `dev` namespace using this newly-created `mytool` pod. It should fail because the `mytool` pod **does not** have the `app: multitool` label. 

```
$ kubectl -n dev exec mytool-769fb4dd48-kd7vb -- curl -s 10.200.0.5

command terminated with exit code 7
```

This concludes the exercise.
