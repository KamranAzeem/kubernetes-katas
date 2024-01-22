# Traefik setup using manual method:

Complete (but non-intuitive) example at: [https://doc.traefik.io/traefik/user-guides/crd-acme/](https://doc.traefik.io/traefik/user-guides/crd-acme/)


## Step 1: Create service Account
```
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: default
  name: traefik-ingress-controller
```

Or, 

```
$ kubectl apply -f support-files/traefik-setup/traefik-with-https-manual-method/00-traefik-service-account.yaml
```

## Step 2: Install CRD which contain definitions for various midlewares:

```
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```

## Step 3: Install RBAC so Traefik can work properly and utilize these CRDs:

```
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml
```

## Step 4: Deploy Traefik application and service:

**Note:** The first time you setup Traefik, you should (must) use the Staging server of the ACME compliant certificate authority - letsencrypt in this case - so that if there are any problems in the setup , then you are not blocked by rate limitations imposed by the certificate provider.

The argument/configuration setting (shown below) in the Traefik deployment file is currently configured to use staging server.

```
  - --certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory
```

This will be updated later.


```
$ kubectl apply -f 02-traefik-deployment-https.yaml 
deployment.apps/traefik created
```

```
$ kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
multitool-57c687d47f-5qztx   1/1     Running   0          25h
traefik-7f8dbd5578-gwfqk     1/1     Running   0          11s
```

Traefik logs:
```
$ kubectl logs -f traefik-7f8dbd5578-gwfqk

time="2024-01-22T12:02:48Z" level=info msg="Configuration loaded from flags."
```

## Step 5: Create service for Traefik - type LoadBalancer:

Traefik application will have a service that will be of type LoadBalancer.

```
$ kubectl apply -f 03-traefik-service-https.yaml
```

Check the service:

```
$ kubectl get svc
NAME                  TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)                                     AGE
kubernetes            ClusterIP      10.64.0.1     <none>           443/TCP                                     3d2h
traefik-web-service   LoadBalancer   10.64.4.188   35.192.220.142   80:30763/TCP,443:31574/TCP,8080:31290/TCP   2d13h
```

Make a note of the public IP of the load-balancer, which is `35.192.220.142` . You will need this IP address when you adjust the DNS settings for your applications in their respective DNS zone records.

```
$ kubectl apply -f 05-example-app-ingressroute.yaml 
ingressroute.traefik.io/whoami-http created
ingressroute.traefik.io/whoami-https created
```


## Step 6: Deploy an example application:

First, adjust the public IP address of the DNS name you want to use for your application with the correct public IP address.

```
$ dig +short whoami.gcp.aclab.me
gcp.aclab.me.
35.192.220.142
```

Once you see that the IP address is correct, you can proceed with deployment of your application and it's `ingress` (or `ingressroute`) definitions.


```
$ kubectl apply -f 04-example-app-deployment-https.yaml
```


```
$ kubectl apply -f 05-example-app-ingressroute.yaml
```

Check the ingressroute objects:

```
$ kubectl get ingressroute.traefik.io
NAME           AGE
whoami-http    19m
whoami-https   19m
```


### Traefik logs:

As soon as you create the ingressroute for your example app, you would see it appearing in the traefik logs.

```
[kamran@kworkhorse ~]$ kubectl logs -f traefik-7f8dbd5578-gwfqk
time="2024-01-22T12:02:48Z" level=info msg="Configuration loaded from flags."


10.60.1.1 - - [22/Jan/2024:12:03:25 +0000] "GET /.well-known/acme-challenge/o079k_XZgnG_h9oD-z35C-L_KShmhleyMJRBJvqMXjo HTTP/1.1" 200 87 "-" "-" 1 "acme-http@internal" "-" 0ms
10.60.1.1 - - [22/Jan/2024:12:03:35 +0000] "GET /.well-known/acme-challenge/o079k_XZgnG_h9oD-z35C-L_KShmhleyMJRBJvqMXjo HTTP/1.1" 200 87 "-" "-" 2 "acme-http@internal" "-" 0ms
10.60.1.1 - - [22/Jan/2024:12:03:35 +0000] "GET /.well-known/acme-challenge/o079k_XZgnG_h9oD-z35C-L_KShmhleyMJRBJvqMXjo HTTP/1.1" 200 87 "-" "-" 3 "acme-http@internal" "-" 0ms
10.60.1.1 - - [22/Jan/2024:12:05:27 +0000] "GET / HTTP/1.1" 404 19 "-" "-" 4 "-" "-" 0ms
10.60.1.1 - - [22/Jan/2024:12:05:47 +0000] "GET /favicon.ico HTTP/1.1" 404 19 "-" "-" 5 "-" "-" 0ms
10.60.1.1 - - [22/Jan/2024:12:05:48 +0000] "GET /robots.txt HTTP/1.1" 404 19 "-" "-" 6 "-" "-" 0ms
10.60.1.1 - - [22/Jan/2024:12:05:48 +0000] "GET /sitemap.xml HTTP/1.1" 404 19 "-" "-" 7 "-" "-" 0ms
10.60.1.1 - - [22/Jan/2024:12:06:39 +0000] "GET / HTTP/1.1" 404 19 "-" "-" 8 "-" "-" 0ms
10.60.1.1 - - [22/Jan/2024:12:15:22 +0000] "POST /cgi-bin/luci/;stok=/locale?form=country HTTP/1.1" 404 19 "-" "-" 9 "dashboard@internal
```

## Verify the application's ingress is working properly:

Check both HTTP and HTTPS endpoints.

Check HTTP:

```
$ curl http://whoami.gcp.aclab.me

Hostname: whoami-76c79d59c8-n6jmz
IP: 127.0.0.1
IP: 10.60.1.7
RemoteAddr: 10.60.1.18:47718
GET / HTTP/1.1
Host: whoami.gcp.aclab.me
User-Agent: curl/8.0.1
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 10.60.1.1
X-Forwarded-Host: whoami.gcp.aclab.me
X-Forwarded-Port: 80
X-Forwarded-Proto: http
X-Forwarded-Server: traefik-7f8dbd5578-gwfqk
X-Real-Ip: 10.60.1.1
```


Check HTTPS:
```
$ curl https://whoami.gcp.aclab.me
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

```
$ curl -k https://whoami.gcp.aclab.me
Hostname: whoami-76c79d59c8-n6jmz
IP: 127.0.0.1
IP: 10.60.1.7
RemoteAddr: 10.60.1.18:42068
GET / HTTP/1.1
Host: whoami.gcp.aclab.me
User-Agent: curl/8.0.1
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 10.60.1.1
X-Forwarded-Host: whoami.gcp.aclab.me
X-Forwarded-Port: 443
X-Forwarded-Proto: https
X-Forwarded-Server: traefik-7f8dbd5578-gwfqk
X-Real-Ip: 10.60.1.1
```

Check the SSL certificate. It should be from Letsencrypt Staging server:

```
$ openssl s_client -showcerts -servername whoami.gcp.aclab.me -connect whoami.gcp.aclab.me:443 </dev/null | grep issuer

depth=2 C = US, O = (STAGING) Internet Security Research Group, CN = (STAGING) Pretend Pear X1
verify error:num=20:unable to get local issuer certificate
verify return:1
depth=1 C = US, O = (STAGING) Let's Encrypt, CN = (STAGING) Artificial Apricot R3
verify return:1
depth=0 CN = whoami.gcp.aclab.me
verify return:1
issuer=C = US, O = (STAGING) Let's Encrypt, CN = (STAGING) Artificial Apricot R3
Verification error: unable to get local issuer certificate
Verify return code: 20 (unable to get local issuer certificate)
DONE
    Verify return code: 20 (unable to get local issuer certificate)
```


## Change LetsEncrypt certificate issuer from Staging to Production:

In the Traefik deployment file `02-traefik-deployment-https.yaml`, 

change:

```
--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory

```

to:

```
--certificatesresolvers.letsencrypt.acme.caserver=https://acme-v02.api.letsencrypt.org/directory
```

, and redeploy Traefik:

```
$ kubectl delete -f 02-traefik-deployment-https.yaml 
deployment.apps "traefik" deleted
```

```
$ kubectl apply -f 02-traefik-deployment-https.yaml 
deployment.apps/traefik created
```


The ingressroutes and other custom resources are not required to be redeployed. Traefik will get new "production" certificates for existing ingressroutes.

```
$ kubectl logs -f traefik-769f6587f8-fxjhb 

time="2024-01-22T14:00:59Z" level=info msg="Configuration loaded from flags."
10.60.1.1 - - [22/Jan/2024:14:01:03 +0000] "GET /.well-known/acme-challenge/qbApNCADUdaKBgt4l1HDVi1xMX3VkZZQQ80RTDB2TdQ HTTP/1.1" 200 87 "-" "-" 1 "acme-http@internal" "-" 0ms
10.60.1.1 - - [22/Jan/2024:14:01:03 +0000] "GET /.well-known/acme-challenge/qbApNCADUdaKBgt4l1HDVi1xMX3VkZZQQ80RTDB2TdQ HTTP/1.1" 200 87 "-" "-" 2 "acme-http@internal" "-" 0ms
10.60.1.1 - - [22/Jan/2024:14:01:03 +0000] "GET /.well-known/acme-challenge/qbApNCADUdaKBgt4l1HDVi1xMX3VkZZQQ80RTDB2TdQ HTTP/1.1" 200 87 "-" "-" 3 "acme-http@internal" "-" 0ms
```


## Verify that the application's ingress routes are now using production SSL certificates:


HTTP:

```
$ curl http://whoami.gcp.aclab.me

Hostname: whoami-76c79d59c8-n6jmz
IP: 127.0.0.1
IP: 10.60.1.7
RemoteAddr: 10.60.1.19:48594
GET / HTTP/1.1
Host: whoami.gcp.aclab.me
User-Agent: curl/8.0.1
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 10.60.1.1
X-Forwarded-Host: whoami.gcp.aclab.me
X-Forwarded-Port: 80
X-Forwarded-Proto: http
X-Forwarded-Server: traefik-769f6587f8-fxjhb
X-Real-Ip: 10.60.1.1
```

HTTPS: (Notice it works without `-k`) 

```
$ curl https://whoami.gcp.aclab.me

Hostname: whoami-76c79d59c8-n6jmz
IP: 127.0.0.1
IP: 10.60.1.7
RemoteAddr: 10.60.1.19:48594
GET / HTTP/1.1
Host: whoami.gcp.aclab.me
User-Agent: curl/8.0.1
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 10.60.1.1
X-Forwarded-Host: whoami.gcp.aclab.me
X-Forwarded-Port: 443
X-Forwarded-Proto: https
X-Forwarded-Server: traefik-769f6587f8-fxjhb
X-Real-Ip: 10.60.1.1
```


Check the SSL certificate. It should be from Letsencrypt production server. (It does not say staging).

```
$ openssl s_client -showcerts -servername whoami.gcp.aclab.me -connect whoami.gcp.aclab.me:443 </dev/null | grep issuer

depth=2 C = US, O = Internet Security Research Group, CN = ISRG Root X1
verify return:1
depth=1 C = US, O = Let's Encrypt, CN = R3
verify return:1
depth=0 CN = whoami.gcp.aclab.me
verify return:1
issuer=C = US, O = Let's Encrypt, CN = R3
DONE
```

