# Ingress - Traefik

In the previous exercises, you saw that Kubernetes provides service discovery for any services within the cluster. So any pod can reach any service just by using a certain service name or a DNS name - visible only within the cluster. But, what about traffic coming in from outside? Well, Kubernetes has a special object to receive/handle traffic coming in from the internet - called **Ingress**. Ingress is a DNS look-alike and it enables you to define DNS names for the services you want to access from outside the cluster network. 

For example, you have a web server, which you want to reach from the internet by using the DNS name `example.com`, or as `www.example.com`. You may also have a custom application handling bookings from the internet, and the DNS name for this service would be `booking.example.com` . Of-course you can define these services as `type: LoadBalancer`, update your DNS on the internet, and reach them from the internet. For a couple of services it may be ok, but if you have many services, then there would be many *load balancers* you would be creating. Load balancers cost extra on any cloud provider. It is also a hassle to maintain the IP address of each new load-balancer and update various DNS entries in your DNS zone files. 

Natively, Kubernetes provides only the `ingress` object, and it does not come with an ingress controller. It is the user/admin's responsibility to setup a (third-party) ingress controller out of many options available. Popular ingress-controllers are: **Traefik** , **nginx**, **haproxy**, etc. 

In this exercise, we would be using Traefik.

Traefik is a reverse proxy / ingress controller, and it provides an easier way to achieve what is described above. Traefik is an **inggress controller**. It means that it looks for any *ingress* objects inside the cluster, and sets up a frontend-backend maps for them. By using an ingress controller, you do not need to expose all of your services as load-balancers. Instead, you can define all your services as `type: ClusterIP`, with an *ingress* object defined on top of them. Then, you only define the **traefik service** as `type: LoadBalancer`. By doing this it receives/handles traffic coming in from the internet for - say - `example.com`, `www.example.com`, `booking.example.com`, `example.com/dashboard`, etc - and routes them to correct backend applications, on correct ports. 

Traefik takes care of things like load balancing traffic, terminating SSL, auto discovery, tracing, metrics, etc. Full detail about Traefik can be found here: [https://traefik.io/](https://traefik.io/)


There are two main parts of using Traefik:
* The installation/setup - normally performed by the cluster administrator.
* The usage - normally by the users of the cluster (admins and developers - both).


## Setup/install/configure Traefik ingress controller in your Kubernetes cluster:
Installation of Traefik is not really the scope of the Kubernetes training. However, a step by step guide on how to setup Traefik in different types of clusters, is available as separate documents [within this repository](support-files/traefik-setup/traefik-with-https-manual-method).

## Setup ingress/ingressroutes for your application(s):

Its time to setup an ingress or ingressroute for our application. It should be noted that Kubernetes has support for basic `ingress` object built into it. However, for more advance use cases, Traefik provides additional CRDs and one of them is `ingressroute`.

Example of `ingressroute` is shown below.


First, ensure that the DNS being used for your application is pointing to the IP address of your Traefik load-balancer.

```
$ dig +short hello-world.gcp.aclab.me

gcp.aclab.me.
35.192.220.142
```



Then apply the following manifest:


```
$ support-files/hello-world-golang/deployment-svc-ingress.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-golang
  labels:
    app: hello-world-golang
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world-golang
  template:
    metadata:
      labels:
        app: hello-world-golang
    spec:
      containers:
      - name: hello-world-golang
        image: wbitt/hello-world-golang
        ports:
        - containerPort: 4444
        env:
        - name: GREETING
          value: Hello
---


apiVersion: v1
kind: Service
metadata:
  name: hello-world-golang
  labels:
    name: hello-world-golang
    app: hello-world-golang
spec:
  ports:
    - port: 4444
  selector:
    app: hello-world-golang

---

apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: hello-world-golang-http
  namespace: default
spec:
  entryPoints:
    - web
  routes:
  # - match: Host(`hello-world-golang.gcp.aclab.me`) && PathPrefix(`/notls`)
  - match: Host(`hello-world.gcp.aclab.me`)
    kind: Rule
    services:
    - name: hello-world-golang
      port: 4444

---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: hello-world-golang-https
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
  # - match: Host(`hello-world-golang.gcp.aclab.me`) && PathPrefix(`/tls`)
  - match: Host(`hello-world.gcp.aclab.me`)
    kind: Rule
    services:
    - name: hello-world-golang
      port: 4444
  tls:
    certResolver: letsencrypt
```

Create the objects from the above file:

```
$ kubectl apply -f support-files/hello-world-golang/deployment-svc-ingress.yaml 

deployment.apps/hello-world-golang created
service/hello-world-golang created
ingressroute.traefik.io/hello-world-golang-http created
ingressroute.traefik.io/hello-world-golang-https created
```


```
$ curl http://hello-world.gcp.aclab.me
 
Hello world - We like: Light-Green .
```

```
$ curl https://hello-world.gcp.aclab.me

Hello world - We like: Light-Green . 
```

Notice the HTTPS url works without using the `-k` switch with curl, which means the certificate issued to the `ingressroute` for your application is a production certificate from Letsencrypt.

```
$ openssl s_client -showcerts -servername hello-world.gcp.aclab.me -connect hello-world.gcp.aclab.me:443 </dev/null | grep issuer
depth=2 C = US, O = Internet Security Research Group, CN = ISRG Root X1
verify return:1
depth=1 C = US, O = Let's Encrypt, CN = R3
verify return:1
depth=0 CN = hello-world.gcp.aclab.me
verify return:1
issuer=C = US, O = Let's Encrypt, CN = R3
DONE

```


