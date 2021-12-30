# Kubernetes environmenet variables, Secrets and Config-maps:

This exercise is targeted towards both developers and system administrators. Most of the time developers are interested in passing certain types of secrets to the containers, such as usernames, passwords, API keys, etc. Similarly most of the time system administrators are interested in passing configuration files, keys, certificate files, etc to the containers. So this exercise has something for both situations.


## A simple .js application:
Our [secrets demo app](support-files/secrets-demo-app/secrets-demo-app.js) requires values for `API URL` and `API_Key` variables. Here is what our application looks like initially:

```
$ cat support-files/secrets-demo-app/secrets-demo-app.js 
var http = require('http');
var server = http.createServer(function (request, response) {
  const API_URL = 'https://api.example.com';
  const API_KEY = 'abc-123-456-789-xyz';
  response.write(`Found API URL: ${API_URL}\n`);
  response.write(`Found API Key: ${API_KEY}\n`);
  response.write(`Proceeding to run the application ... \n`);
  response.end(`\n`);
});
server.listen(3000);
```

Notice, we have hard-coded the values for `API_URL` and `API_KEY` :

```
const API_URL = 'https://api.example.com';
const API_KEY = 'abc-123-456-789-xyz';
```

Run the app on a plain docker host, using `docker run`:

```
$ cd support-files/secrets-demo-app

$ docker build . -t local/secrets-demo-app

$ docker run -p 3000:3000 -d local/secrets-demo-app

$ curl localhost:3000
Found API URL: https://api.example.com
Found API Key: abc-123-456-789-xyz
Proceeding to run the application ... 

```

In the example above, the two variables are hard-coded into the application. At least one of these (`API_KEY`) is a sensitive variable. If we keep this code like this, the sensitive information will be saved into the file, and eventually reach the git repository, and after that it is visible to the entire world - if the repo is public. Even if the repo is not public, the code will be part of git history forever, and anyone having access to the git repo can extract this sensitive information from the git commit history. 

It is not only the sensitivity of the variables that makes this a bad piece of code. The `API_URL` variable is not sensitive in nature. However, if the URL changes in future, then we would need to modify the code; and, if it is container image, we would need to rebuild the container image; and, .... You get the point.


So a better way is to set these as *Environment Variables* and let the application load these from the process's environment, which it gets from the underlying OS. 

The first step to fixing it, would be to make sure that our variables get their values from the process's environment. So, we change the application code like this:

```
  const API_URL = process.env.API_URL;
  const API_KEY = process.env.API_KEY;
```

Lets create a Docker container for this app and pass these values as environment variables in the Dockerfile:

```
$ cat support-files/secrets-demo-app/Dockerfile

FROM node:alpine
EXPOSE 3000
ENV API_URL https://api.example.com
ENV API_KEY abc-123-456-789-xyz
COPY secrets-demo-app.js .
ENTRYPOINT ["node", "secrets-demo-app.js"]
```

Run the app on a plain docker host, using `docker run`:

```
$ cd support-files/secrets-demo-app

$ docker build . -t local/secrets-demo-app

$ docker run -p 3000:3000 -d local/secrets-demo-app

$ curl localhost:3000
Found API URL: https://api.example.com
Found API Key: abc-123-456-789-xyz
Proceeding to run the application ... 

```

OK, the application still works as expected. We have containerized the app, but we have moved the problem from one file to another. Now the values of these variables are stored in the  `Dockerfile` which is still part of the application code, and will be stored in the git repository. 

So now, the best way is to pass these variables from OS environment. For that we remove the two `ENV` lines from `Dockerfile`, so it looks like this:

```
$ cat support-files/secrets-demo-app/Dockerfile

FROM node:alpine
EXPOSE 3000
COPY secrets-demo-app.js .
ENTRYPOINT ["node", "secrets-demo-app.js"]
```

Kill the previous running container, build a new one and then start it.

```
$ docker kill 8cb3fce946a1

$ docker build . -t local/secrets-demo-app

$ docker run \
    -e API_URL=https://api.example.com \
    -e API_KEY=def-123-456-789-uvw  \
    -p 3000:3000 \
    -d local/secrets-demo-app


$ curl localhost:3000
Found API URL: https://api.example.com
Found API Key: def-123-456-789-uvw
Proceeding to run the application ... 

```

## Run the app as a deployment in Kubernetes:

The Docker container for the application shown above is available as `wbitt/k8s-secrets-demo-app` - from DockerHub.

Lets run this Docker container image as a deployment in our Kubernetes cluster. We can run that in our Kubernetes cluster by using the [the basic deployment file](support-files/secrets-demo-app/basic-deployment.yml). Here is what the deployment file looks like:

```
$ cat support-files/secrets-demo-app/basic-deployment.yml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-secrets-demo
spec:
  replicas: 1

  selector:
    matchLabels:
      name: k8s-secrets-demo

  template:
    metadata:
      labels:
        name: k8s-secrets-demo
    spec:
      containers:
      - name: secrets-demo-app
        image: wbitt/k8s-secrets-demo-app
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
        env:
        - name: API_URL
          value: https://api.example.com
        - name: API_KEY
          value: def-333-444-555-jkl

```

Notice the ENV variables and their values are part of the `deployment.yaml` file, which is the problem we are trying to avoid, but, we will get there. Lets run it:

```
$ kubectl apply -f support-files/secrets-demo-app/basic-deployment.yml
deployment.apps/k8s-secrets-demo created
```

Expose the deployment on a nodeport. Remember that this application runs on port `3000`.

```
$ kubectl get deployments
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
k8s-secrets-demo   1/1     1            1           87s
multitool          1/1     1            1           42d


$ kubectl expose deployment k8s-secrets-demo --type=NodePort
service/k8s-secrets-demo exposed

$ kubectl get services
NAME               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
k8s-secrets-demo   NodePort    10.111.187.198   <none>        3000:30848/TCP   28s
kubernetes         ClusterIP   10.96.0.1        <none>        443/TCP          42d
```

Lets access this service and see what we get:

```
$ curl 192.168.50.67:30848
Found API URL: https://api.example.com
Found API Key: def-333-444-555-jkl
Proceeding to run the application ... 
```

Good. It is working. Next we will pass sensitive environment variables through Kubernetes "secrets", and non-sensitive variables as "configmap".

### kubernetes secrets and configmaps:

Let's create the API key as a kubernetes **secret**. Kubernetes supports different kinds of pre-configured secrets, but for now we'll use the `generic` type.


```
$ kubectl create secret generic api-key --from-literal=API_KEY=ghi-123-444-555-mno
secret/api-key created
```


Since the value stored in API_URL variable is not necessarily sensitive information, it can be created as **configmap** object:

```
$ kubectl create configmap api-url --from-literal=API_URL=https://api.example.com
configmap/api-url created
```

**Note:** Kubernetes does not allow underscore in the names of the objects it creates. Only lowercase letters (a-z), numbers (0-9) and hyphen (-) are allowed.

Now run `kubectl get secrets,configmap` to see if these objects are created:

```
$ kubectl get secrets,configmaps
NAME                         TYPE                                  DATA   AGE
secret/api-key               Opaque                                1      6m59s
secret/default-token-7rn6k   kubernetes.io/service-account-token   3      42d

NAME                         DATA   AGE
configmap/api-url            1      80s
configmap/kube-root-ca.crt   1      42d

```

Now, investigate the secret by using the kubectl describe command. You will notice that the actual value of API_KEY is not shown.
```
$ kubectl describe secret api-key
Name:         api-key
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
API_KEY:  19 bytes
```

To see the contents of the API_KEY variable in this secret, use the following command. You will notice, that the value is not what you specified when you created this secret. It is different because it is encoded with base64.

```
$ kubectl get secret api-key -o yaml
apiVersion: v1
data:
  API_KEY: Z2hpLTEyMy00NDQtNTU1LW1ubw==
kind: Secret
metadata:
  creationTimestamp: "2021-12-30T13:17:17Z"
  name: api-key
  namespace: default
  resourceVersion: "227176"
  uid: dea7643e-3578-4ac2-ac88-e7ebc5f0ac0f
type: Opaque
```

To extract the actual decoded value of the API_KEY, copy the encoded string and pass it through `base64 -d`, and you will see the actual value which you provided to this variable when you created this secret.

```
$ echo Z2hpLTEyMy00NDQtNTU1LW1ubw== | base64 -d

ghi-123-444-555-mno
```

If you examine the configMap api-url, you will see the value of this variable directly in the output.

```
$ kubectl describe configmap api-url
Name:         api-url
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
API_URL:
----
https://api.example.com

BinaryData
====

Events:  <none>
```

Another way to view the contents of config map is to use `kubectl get ... -o yaml`:

```
$ kubectl get configmap api-url -o yaml
apiVersion: v1
data:
  API_URL: https://api.example.com
kind: ConfigMap
metadata:
  creationTimestamp: "2021-12-30T13:22:56Z"
  name: api-url
  namespace: default
  resourceVersion: "227413"
  uid: ce97b8b2-9c14-4f48-acee-dbc0ea9ff896
```

## Update the deployment to use secret and configmap:

Now we change the Kubernetes deployment file to use the secrets. For this exercise , a separate  file is created as `support-files/secrets-demo-app/final-deployment.yml`.

Change the env section, from:

```
        env:
        - name: API_URL
          value: https://api.example.com
        - name: API_KEY
          value: def-333-444-555-jkl
```

to this:

```
        env:

        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: api-url
              key: API_URL

        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: api-key
              key: API_KEY
```

After you have edited the older deployment file (or used the already prepared one `support-files/secrets-demo-app/final-deployment.yml`), you need to apply the new version of the file by using: 

```
$ kubectl apply -f support-files/secrets-demo-app/final-deployment.yml
```

Access the application again over nodeport, using curl and see if you get the correct output. You should now see the variables being loaded from configmap and secret respectively.

```
$ curl 192.168.50.67:30848
Found API URL: https://api.example.com
Found API Key: ghi-123-444-555-mno
Proceeding to run the application ... 
```

#### What happens when the values of variables inside secrets and configmaps change?
Pods are not recreated automatically when serets or configmaps change. After you change the secrets and config maps values, you need to restart the pods which are using those secrets and config maps. 

You can simply delete the configmap and secret and create a new one,using the following command, or use the fancy command shown next.

```
$ kubectl delete configmap api-url

$ kubectl delete secret api-key
```

Here is the fancy way of changing/updating an existing secret and config map:

```
$ kubectl create configmap api-url --from-literal=API_URL=https://api.example.net -o yaml --dry-run=client | kubectl replace -f -

configmap/api-url replaced

$ kubectl create secret generic api-key --from-literal=API_KEY=klm-333-444-555-pqr -o yaml --dry-run=client | kubectl replace -f -

secret/api-key replaced
```

Then delete the existing pod, so it's recreated with the new/updated configmap and secret:

```
$ kubectl delete pod k8s-secrets-demo-6d579d7d9-w99wg
pod "k8s-secrets-demo-6d579d7d9-w99wg" deleted
```

Once new instance of the pod is running, access it using curl again to see the updated values.

```
$ curl 192.168.50.67:30848
Found API URL: https://api.example.net
Found API Key: klm-333-444-555-pqr
Proceeding to run the application ... 
```

## Multiple environment variables in a single secret:
If you want, you can store multiple variables and their values in a single secret. In this example, we can store both API_URL and API_KEY in a single kubernetes secret. Since both variables will be stored in a secret, we don't need to create a separate configmap for API_URL.

We create it like this:

```
$ kubectl create secret generic demo-app-credentials \
    --from-literal=API_KEY=ghi-123-444-555-mno \
    --from-literal=API_URL=https://api.example.com
```

Then replace the `env` section of the deployment:

```
        env:
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: api-url
              key: API_URL
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: api-key
              key: API_KEY
```

with this:

```
        env:
        - name: API_URL
          valueFrom:
            secretKeyRef:
              name: demo-app-credentials
              key: API_URL
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: demo-app-credentials
              key: API_KEY
```

You can examine the secret using the same tools as before. This time you see that there are two items in one secret.

```

[$ kubectl describe secret demo-app-credentials
Name:         demo-app-credentials
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
API_KEY:  19 bytes
API_URL:  23 bytes
```

```
$ kubectl get secret demo-app-credentials -o yaml
apiVersion: v1
data:
  API_KEY: Z2hpLTEyMy00NDQtNTU1LW1ubw==
  API_URL: aHR0cHM6Ly9hcGkuZXhhbXBsZS5jb20=
kind: Secret
metadata:
  creationTimestamp: "2021-12-30T14:00:02Z"
  name: demo-app-credentials
  namespace: default
  resourceVersion: "229034"
  uid: e6901fe9-51e3-4288-ba8f-51487c0f31af
type: Opaque
```

```
$ echo aHR0cHM6Ly9hcGkuZXhhbXBsZS5jb20= | base64 -d

https://api.example.com

$ echo Z2hpLTEyMy00NDQtNTU1LW1ubw== | base64 -d

ghi-123-444-555-mno
```


------

You can also try to setup a simple wordpress pod/deployment to experiment with secrets.

----------

## nginx web-server on SSL - uses secrets (as files) and configmaps (as files):
This example is more suited for system administrators. In this example, we want to run nginx web-server, which listens on port 443, by using some self-signed SSL certificates. This involves:

* providing SSL certificates to nginx pods, and,
* providing a custom nginx configuration, so the pods know how to use these certificates and what port to listen on.

To achieve these objectives, we will create SSL certs as secrets, and a custom nginx configuration as configmap, and use them in our deployment.


Generate self signed certs:
```
$ support-files/generate-self-signed-certs.sh
```
This will create two `tls.*` files in the current directory.


Create  (tls type) secret for nginx using these two files:

```
$ kubectl create secret tls nginx-certs \
    --cert=tls.crt \
    --key=tls.key
```

Examine the secret you just created:
```
$ kubectl describe secret nginx-certs
```

```
$ kubectl get secret nginx-certs -o yaml
```


Create a custom configuration nginx: (check support-files/  directory)

```
$ cat support-files/nginx-connectors.conf
server {
    listen       80;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}

server {
    listen       443;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    ssl on;
    ssl_certificate /certs/tls.crt;
    ssl_certificate_key /certs/tls.key;
}
```


```
$ kubectl create configmap nginx-config \
    --from-file=support-files/nginx-connectors.conf
```

Examine the configmap you just created:

```
kubectl describe configmap nginx-config
```

```
kubectl get configmap nginx-config -o yaml
```


Create a nginx deployment with SSL support using the secret and config map you created in the previous steps (above):

```
$ cat support-files/nginx-ssl.yaml 
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
      volumes:
      - name: certs-volume
        secret:
          secretName: nginx-certs
      - name: config-volume
        configMap:
          name: nginx-config
      containers:
      - name: nginx
        image: nginx:1.15.1
        ports:
        - containerPort: 443
        - containerPort: 80
        volumeMounts:
        - mountPath: /certs
          name: certs-volume
        - mountPath: /etc/nginx/conf.d
          name: config-volume
```


```
kubectl create -f support-files/nginx-ssl.yaml
```

You should be able to see nginx running. Expose it as a service and `curl` it from your computer. You can also `curl` it through the multitool pod from within the cluster without exposing it as a service.




