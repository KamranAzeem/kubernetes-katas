# HowTo - Use External Secrets Operator (ESO) with GCP Secret Manager

## Preparation:
* Setup a test project in GCP with a Unique ID. (ID: trainingvideos)
* Enable SecretManager API in GCP
* Under IAM, create a Google Service Account , with `Secret Manager Accessor` rights. This service account will be used (later) by the `external-secrets` operator in your Kubernetes cluster to talk to GCP Secret Manager to pull the required secret. (`sa-dev-external-secrets`) . 
* Create a (JSON) key for this service account, and download the key to your local computer  `trainingvideos-6b3e7004d082.json`. Store this key at a safe place in your file system. `mv $HOME/DOwnloads/trainingvideos-6b3e7004d082.json $HOME/Keys-and-Tokens/GCP/`
* Create a Secret inside `GCP -> Security -> GCP Secret Manager`, named `dev-mysql-root-password` , with a value `DarkMountain` . This is the example secret that we would be accessing using external-secrets , and would eventually be used by a pod as a normal Kubernetes secret object.


### [Optional] - Install google cloud CLI on local/work computer

This will come handy if you want to use Google CLI instead of Web UI.

```
# yum install google-cloud-cli
```


Login to Google Cloud using gcloud:

```
[kamran@kworkhorse ~]$ gcloud auth login
Your browser has been opened to visit:

    https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=32555940559.apps.googleusercontent.com&redirect_uri=http%3A%2F%2Flocalhost%3A8085%2F&scope=openid+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.email+https%3A%2F%2Fwww.googleapis.com%2Fauttype=offline&code_challenge=8a9LkjGe92cRH3OC03JJFca6jX7-3mHQKCPwuXZ8q6Q&code_challenge_method=S256


You are now logged in as [kamranazeem@gmail.com].

Your current project is [witline].  You can change this setting by running:
  $ gcloud config set project PROJECT_ID


To take a quick anonymous survey, run:
  $ gcloud survey

[kamran@kworkhorse ~]$ 
```


Set the project to the project ID being used in this HowTo:

```
[kamran@kworkhorse ~]$ gcloud config set project trainingvideos
Updated property [core/project].
[kamran@kworkhorse ~]$ 
```

Try access the key you created in the GCP Secret Manager console:
```
[kamran@kworkhorse ~]$ gcloud secrets versions access 1 --secret=dev-mysql-root-password

DarkMountain
```


## Install external-secrets in kubernetes cluster:
Assuming you already have a kubernetes cluster. Setup dedicated namespace for `external-secrets` operator.

```
kubectl config use-context k3s
```


Add helm repository for external-secrets:
```
helm repo add external-secrets \
    https://charts.external-secrets.io
```

```
helm repo update
```

```
helm upgrade --install \
    external-secrets \
    external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace
```



```
[kamran@kworkhorse ~]$ helm upgrade --install \
    external-secrets \
    external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace
Release "external-secrets" does not exist. Installing it now.
NAME: external-secrets
LAST DEPLOYED: Mon Dec 11 15:33:41 2023
NAMESPACE: external-secrets
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
external-secrets has been deployed successfully!

In order to begin using ExternalSecrets, you will need to set up a SecretStore
or ClusterSecretStore resource (for example, by creating a 'vault' SecretStore).

More information on the different types of SecretStores and how to configure them
can be found in our Github: https://github.com/external-secrets/external-secrets
[kamran@kworkhorse ~]$ 
```

Verify:

```
[kamran@kworkhorse ~]$ helm -n external-secrets list
NAME            	NAMESPACE       	REVISION	UPDATED                                	STATUS  	CHART                 	APP VERSION
external-secrets	external-secrets	1       	2023-12-11 15:33:41.224710285 +0100 CET	deployed	external-secrets-0.9.9	v0.9.9     
[kamran@kworkhorse ~]$ 
```


```
[kamran@kworkhorse ~]$ kubectl -n external-secrets get all
NAME                                                    READY   STATUS    RESTARTS   AGE
pod/external-secrets-666dc6fb64-xdqc8                   1/1     Running   0          69s
pod/external-secrets-webhook-5fcbff7b79-w9s29           1/1     Running   0          69s
pod/external-secrets-cert-controller-6859c785f4-rbbg2   1/1     Running   0          69s

NAME                               TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/external-secrets-webhook   ClusterIP   10.32.24.37   <none>        443/TCP   69s

NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/external-secrets                   1/1     1            1           69s
deployment.apps/external-secrets-webhook           1/1     1            1           69s
deployment.apps/external-secrets-cert-controller   1/1     1            1           69s

NAME                                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/external-secrets-666dc6fb64                   1         1         1       69s
replicaset.apps/external-secrets-webhook-5fcbff7b79           1         1         1       69s
replicaset.apps/external-secrets-cert-controller-6859c785f4   1         1         1       69s
[kamran@kworkhorse ~]$ 
```

Next, setup gcp-credentials in the `external-secrets` namespace, using the JSON file downloaded earlier:


```
[kamran@kworkhorse ~]$ kubectl -n external-secrets   create secret generic gcp-credentials   --from-file=credentials=${HOME}/Keys-and-Tokens/GCP/trainingvideos-6b3e7004d082.json 

secret/gcp-credentials created
[kamran@kworkhorse ~]$ 
```

## Setup necessary objects related to `external-secrets`:

The following is a cluster wide object. It will be created in all namespaces automatically.

```
[kamran@kworkhorse ~]$ vi secret-store.yaml

apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: gcp-secret-manager
spec:
  provider:
      gcpsm:
        auth:
          secretRef:
            secretAccessKeySecretRef:
              name: gcp-credentials
              key: credentials
              namespace: external-secrets
        projectID: trainingvideos
```
**Note:** They `key: credentials` mean the name of the key in the kubernetes secret object named `gcp-credentials`. If you examine the secret using `kubectl -n external-secrets get secret gcp-credentials -o yaml`, you will see that the name of the key under data is `credentials`. This is automatically done when you created the `gcp-credentials` secret from the JSON file.




```
[kamran@kworkhorse ~]$ kubectl apply -f secret-store.yaml 
clustersecretstore.external-secrets.io/gcp-secret-manager created
[kamran@kworkhorse ~]$ 
```

Verify:

```
[kamran@kworkhorse ~]$ kubectl -n default get ClusterSecretStore
NAME                 AGE     STATUS   CAPABILITIES   READY
gcp-secret-manager   6m17s   Valid    ReadWrite      True


[kamran@kworkhorse ~]$ kubectl -n dev get ClusterSecretStore
NAME                 AGE     STATUS   CAPABILITIES   READY
gcp-secret-manager   6m21s   Valid    ReadWrite      True
[kamran@kworkhorse ~]$ 
```




## Setup DEV namespace in Kubernetes:

```
[kamran@kworkhorse ~]$ kubectl create namespace dev
namespace/dev created
[kamran@kworkhorse ~]$ 
```

Create the object to fetch the secret from secret store and populate a Kubernetes secret in-turn:


**Note:** The file below creates an externalsecret by pulling/referencing a single secret created in the GCP SM, which has one plain-text value (not in JSON format). To access a secret which has multiple key-value pairs defined in it (in JSON format), there is a slightly different syntax to be used. Example for this second case is shown later.

```
[kamran@kworkhorse ~]$ vi external-secret.yaml

apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: dev-mysql-root-password
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-secret-manager
  target:
    name: dev-mysql-root-password
    creationPolicy: Owner
  data:
    - secretKey: dev-mysql-root-password
      remoteRef: 
        key: dev-mysql-root-password

```


```
[kamran@kworkhorse ~]$ kubectl -n dev apply -f external-secret.yaml 
externalsecret.external-secrets.io/dev-mysql-root-password created
[kamran@kworkhorse ~]$ 
```

Verify:
```
[kamran@kworkhorse ~]$ kubectl -n dev get externalsecrets
NAME                                                        AGE   STATUS   CAPABILITIES   READY
clustersecretstore.external-secrets.io/gcp-secret-manager   18h   Valid    ReadWrite      True

NAME                                                         STORE                REFRESH INTERVAL   STATUS         READY
externalsecret.external-secrets.io/dev-mysql-root-password   gcp-secret-manager   1h                 SecretSynced   True
[kamran@kworkhorse ~]$ kubectl -n dev get secrets
NAME                      TYPE     DATA   AGE
dev-mysql-root-password   Opaque   1      72s
[kamran@kworkhorse ~]$ 
```


```
[kamran@kworkhorse ~]$ kubectl -n dev get secret dev-mysql-root-password -o yaml 
apiVersion: v1
data:
  dev-mysql-root-password: RGFya01vdW50YWlu
kind: Secret
metadata:
  labels:
    reconcile.external-secrets.io/created-by: a7e7edef808769e3f09347dde91d82c5
  name: dev-mysql-root-password
  namespace: dev
type: Opaque
. . . 

[kamran@kworkhorse ~]$ 
```


```
[kamran@kworkhorse ~]$ echo RGFya01vdW50YWlu | base64 -d
DarkMountain

[kamran@kworkhorse ~]$ 
```


## Use/consume secret in a Kubernetes deployment/pod:

Setup a small test deployment/pod, which would use this secret.

```
[kamran@kworkhorse ~]$ cat k8s-secrets-demo.yaml 
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
      - name: network-multitool
        image: kamranazeem/nginx-tls
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: dev-mysql-root-password
              key: dev-mysql-root-password

[kamran@kworkhorse ~]$ 
```



```
[kamran@kworkhorse ~]$ kubectl -n dev apply -f k8s-secrets-demo.yaml 
deployment.apps/k8s-secrets-demo created


[kamran@kworkhorse ~]$ kubectl -n dev get pods
NAME                                READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-6d46dbdddf-f7hrn   1/1     Running   0          9s
[kamran@kworkhorse ~]$ 
```


Check the pod if the secret is available and populated properly in the pod's ENV variable:

```
[kamran@kworkhorse ~]$ kubectl -n dev exec k8s-secrets-demo-6d46dbdddf-f7hrn -- env | grep MYSQL
MYSQL_ROOT_PASSWORD=DarkMountain
[kamran@kworkhorse ~]$ 
``` 


Super!

## Rotate/change the secret in GCP SecretManager:

Lets change password for `dev-mysql-root-password` in GCP Secret Manager from `DarkMountain` to `BrightMountain`. We would also observe the logs from the externalsecret controller pod.


```
[kamran@kworkhorse ~]$ kubectl -n external-secrets logs -f -l app.kubernetes.io/instance=external-secrets


{"level":"info","ts":1702382694.8098323,"logger":"controllers.webhook-certs-updater","msg":"updating webhook config","Webhookconfig":{"name":"externalsecret-validate"}}
{"level":"info","ts":1702382694.81833,"logger":"controllers.webhook-certs-updater","msg":"injecting ca certificate and service names","cacrt":"LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURSakNDQWk2Z0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREEyTVJrd0Z3WURWUVFLRXhCbGVIUmwKY201aGJDMXpaV055WlhSek1Sa3dGd1lEVlFRREV4QmxlSFJsY201aGJDMXpaV055WlhSek1CNFhEVEl6TVRJeApNVEV6TXpNMU0xb1hEVE16TVRJd09ERTBNek0xTTFvd05qRVpNQmNHQTFVRUNoTVFaWGgwWlhKdVlXd3RjMlZqCmNtVjBjekVaTUJjR0ExVUVBeE1RWlhoMFpYSnVZV3d0YzJWamNtVjBjekNDQVNJd0RRWUpLb1pJaHZjTkFRRUIKQlFBRGdnRVBBRENDQVFvQ2dnRUJBTklXN3FmT2g1bkFtY2NrL2oxSGxIWURUdGJNWEhPSmpRakVuTStTUitWYTVIM2Q5WkwwSzRQVWhneApTZ2Z4VWt0WXBaZHBjVzlvRHA5djAxYi9TMjhUTEtCV2hYWUs2eEZub1d0V1RyY2pLcVlMUEVlNi9kRlAwMTlwCnB1UWJxNjYwVXpmRFpmb2hIZk1GUkh6TUt0STlXVG83dUF5VG5GTkRvN0xXNHNnKzk2V1dSU0xWV2c5VHNwNDkKTDUxWnNlcVg2VHJPY3Q3SmtVVENQeGNkTUdlNkhsdFZuNVBoRUdBaGhvRklaS2NhaGFDTy81MWpBYXAvbS90dAo0ekdLYkl4KzErZi9FZzdrZmxPWDRjNEF5bnpjaFBxNWZZTT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=","name":"externalsecret-validate"}
{"level":"info","ts":1702382694.8265014,"logger":"controllers.webhook-certs-updater","msg":"updated webhook config","Webhookconfig":{"name":"externalsecret-validate"}}
{"level":"info","ts":1702382694.8269482,"logger":"controllers.webhook-certs-updater","msg":"updating webhook config","Webhookconfig":{"name":"secretstore-validate"}}
{"level":"info","ts":1702382694.8369095,"logger":"controllers.webhook-certs-updater","msg":"injecting ca certificate and service names","cacrt":"LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURSakNDQWk2Z0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREEyTVJrd0Z3WURWUVFLRXhCbGVIUmwKY201aGJDMXpaV055WlhSek1Sa3dGd1lEVlFRREV4QmxlSFJsY201aGJDMXpaV055WlhSek1CNFhEVEl6TVRJeApNVEV6TXpNMU0xb1hEVE16TVRJd09ERTBNek0xTTFvd05qRVpNQmNHQTFVRUNoTVFaWGgwWlhKdVlXd3RjMlZqCmNtVjBjekVaTUJjR0ExVUVBeE1RWlhoMFpYSnVZV3d0YzJWamNtVjBjekNDQVNJd0RRWUpLb1pJaHZjTkFRRUIKQlFBRGdnRVBBRENDQVFvQ2dnRUJBTklXN3FmT2g1bkFtY2NrL2oxSGxIWURUdGJNWEhPSmpRakVbW9VNDhZMzY1eC9Wa240UXZPUWRHdFpUVUcxcEQKN1pQU1pySFExVjZ3WWRQNW51ak1YMHNyZDhVVFNSMDdlTEJaVzhVM0huTStTUitWYTVIM2Q5WkwwSzRQVWhneApTZ2Z4VWt0WXBaZHBjVzlvRHA5djAxYi9TMjhUTEtCV2hYWUs2eEZub1d0V1RyY2pLcVlMUEVlNi9kRlAwMTlwCnB1UWJxNjYwVXpmRFpmb2hIZk1GUkh6TUt0STlXVG83dUF5VG5GTkRvN0xXNHNnKzk2V1dSU0xWV2c5VHNwNDkKTDUxWnNlcVg2VHJPY3Q3SmtVVENQeGNkTUdlNkhsdFZuNVBoRUdBaGhvRklaS2NhaGFDTy81MWpBYXAvbS90dAo0ekdLYkl4KzErZi9FZzdrZmxPWDRjNEF5bnpjaFBxNWZZTT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=","name":"secretstore-validate"}
{"level":"info","ts":1702382694.8479145,"logger":"controllers.webhook-certs-updater","msg":"updated webhook config","Webhookconfig":{"name":"secretstore-validate"}}

```


```
[kamran@kworkhorse ~]$ kubectl -n dev get secret dev-mysql-root-password 
NAME                      TYPE     DATA   AGE
dev-mysql-root-password   Opaque   1      178m
[kamran@kworkhorse ~]$ 

```


```
[kamran@kworkhorse ~]$ kubectl -n dev get secret dev-mysql-root-password -o yaml | grep -A5 apiVersion
apiVersion: v1
data:
  dev-mysql-root-password: QnJpZ2h0TW91bnRhaW4=
immutable: false
kind: Secret
metadata:
```

The k8s secret is updated:
```
[kamran@kworkhorse ~]$ echo QnJpZ2h0TW91bnRhaW4= | base64 -d
BrightMountain

[kamran@kworkhorse ~]$ 
```


The k8s secret being used inside the pod is not updated. (todo)

```
[kamran@kworkhorse ~]$ kubectl -n dev exec k8s-secrets-demo-6d46dbdddf-f7hrn -- env | grep MYSQL
MYSQL_ROOT_PASSWORD=DarkMountain
[kamran@kworkhorse ~]$ 
```


------

# The Stakater for reloading secrets automatically:

References: 
* https://www.stakater.com/
* https://github.com/stakater/Reloader

This is a Kubernetes controller to watch changes in ConfigMap and Secrets and perform rolling upgrades on Pods with their associated Deployment, StatefulSet, DaemonSet and DeploymentConfig.

## Install Stakater/Reloader in Kubernetes:

By default, Reloader gets deployed in default namespace and watches changes secrets and configmaps in all namespaces. 

```
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml
```


(todo) Can I deploy it in the same namespace as `external-secrets`? Manual attempt to deploy it in `external-secrets` failed.

```
[kamran@kworkhorse support-files]$ kubectl -n external-secrets \
apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml
clusterrole.rbac.authorization.k8s.io/reloader-reloader-role created
clusterrolebinding.rbac.authorization.k8s.io/reloader-reloader-role-binding created
the namespace from the provided object "default" does not match the namespace "external-secrets". You must pass '--namespace=default' to perform this operation.
the namespace from the provided object "default" does not match the namespace "external-secrets". You must pass '--namespace=default' to perform this operation.
[kamran@kworkhorse support-files]$
```

Using `default` namespace for now.

```
[kamran@kworkhorse support-files]$ kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml

serviceaccount/reloader-reloader created
clusterrole.rbac.authorization.k8s.io/reloader-reloader-role unchanged
clusterrolebinding.rbac.authorization.k8s.io/reloader-reloader-role-binding unchanged
deployment.apps/reloader-reloader created
[kamran@kworkhorse support-files]$ 
```

Verify:
```
[kamran@kworkhorse support-files]$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
reloader-reloader-dfd6f7bd9-b2g7f   1/1     Running   0          25s
[kamran@kworkhorse support-files]$
```

Check logs:

```
[kamran@kworkhorse support-files]$ kubectl logs -f reloader-reloader-dfd6f7bd9-b2g7f
time="2023-12-13T12:49:55Z" level=info msg="Environment: Kubernetes"
time="2023-12-13T12:49:55Z" level=info msg="Starting Reloader"
time="2023-12-13T12:49:55Z" level=warning msg="KUBERNETES_NAMESPACE is unset, will detect changes in all namespaces."
time="2023-12-13T12:49:55Z" level=info msg="created controller for: configMaps"
time="2023-12-13T12:49:55Z" level=info msg="Starting Controller to watch resource type: configMaps"
time="2023-12-13T12:49:55Z" level=info msg="created controller for: secrets"
time="2023-12-13T12:49:55Z" level=info msg="Starting Controller to watch resource type: secrets"
```



## Update deployments to enable reloading by Reloader:


First, we see the status of ENV variables in our current pod.

```
[kamran@kworkhorse support-files]$ kubectl -n dev get pods
NAME                                READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-64b7d88484-gxd2c   1/1     Running   0          8s
```

```
[kamran@kworkhorse support-files]$ kubectl -n dev exec k8s-secrets-demo-64b7d88484-gxd2c -- env | grep MYSQL

MYSQL_ROOT_PASSWORD=BrightMountain
[kamran@kworkhorse support-files]$
```

The above reflects the current value of the secret in GCP SM.

Add the following annotation to your deployment, so it (the related pod(s)) is automatically reloaded as soon as the secrets and configmaps being consumed by it are changed.

```
  annotations:
    reloader.stakater.com/auto: "true"
```

```
[kamran@kworkhorse support-files]$ kubectl -n dev delete -f k8s-secrets-demo.yaml 
deployment.apps "k8s-secrets-demo" deleted


[kamran@kworkhorse support-files]$ kubectl -n dev apply -f k8s-secrets-demo.yaml 
deployment.apps/k8s-secrets-demo created
[kamran@kworkhorse support-files]$
```


Change the dev-mysql-root-password in GCPSM to `CleverHorse`. Then check if the secret `MYSQL_ROOT_PASSWORD` mounted/loaded inside the `k8s-secrets-demo` pod get updated.


In a separate terminal, check logs of Reloader. You will see that it detected the change:
```
[kamran@kworkhorse support-files]$ kubectl logs -f reloader-reloader-dfd6f7bd9-b2g7f

. . .


time="2023-12-13T13:08:58Z" level=info msg="Changes detected in 'dev-mysql-root-password' of type 'SECRET' in namespace 'dev', Updated 'k8s-secrets-demo' of type 'Deployment' in namespace 'dev'"
```


```
[kamran@kworkhorse support-files]$ kubectl -n dev get secrets dev-mysql-root-password -o yaml

apiVersion: v1
data:
  dev-mysql-root-password: Q2xldmVySG9yc2U=
immutable: false
kind: Secret
metadata:
  annotations:

. . . 
```


Verify:
```
[kamran@kworkhorse support-files]$ echo Q2xldmVySG9yc2U= | base64 -d

CleverHorse
[kamran@kworkhorse support-files]$ 
```

Look inside the pod:
```
[kamran@kworkhorse support-files]$ kubectl -n dev exec k8s-secrets-demo-7545c467f8-cbn69 -- env | grep MYSQL

MYSQL_ROOT_PASSWORD=CleverHorse
STAKATER_DEV_MYSQL_ROOT_PASSWORD_SECRET=66841ad2b4d96f5c45dc874863f4192b48ad2607

[kamran@kworkhorse support-files]$ 
```
Notice that Stakater has added it's own ENV variable inside the pod to track the secret.


There is a new ReplicaSet in this deployment:

```
[kamran@kworkhorse support-files]$ kubectl -n dev get deployments
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
k8s-secrets-demo   1/1     1            1           6m47s


[kamran@kworkhorse support-files]$ kubectl -n dev get rs
NAME                          DESIRED   CURRENT   READY   AGE
k8s-secrets-demo-7545c467f8   1         1         1       5m29s
k8s-secrets-demo-64b7d88484   0         0         0       6m51s
[kamran@kworkhorse support-files]$ 
```

Very Good! It works!


Lets Change secret one more time from `CleverHorse` to `DumbHorse`.

The reloader logs will show that secret was changed:

```
[kamran@kworkhorse support-files]$ kubectl logs -f reloader-reloader-dfd6f7bd9-b2g7f

time="2023-12-13T13:17:02Z" level=info msg="Changes detected in 'dev-mysql-root-password' of type 'SECRET' in namespace 'dev', Updated 'k8s-secrets-demo' of type 'Deployment' in namespace 'dev'"
```

This has resulted in a new pod being started:

```
[kamran@kworkhorse support-files]$ kubectl -n dev get pods
NAME                                READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-5c97699b8d-k9jlr   1/1     Running   0          63s
[kamran@kworkhorse support-files]$ 
```

A new replicaset:
```
[kamran@kworkhorse support-files]$ kubectl -n dev get rs
NAME                          DESIRED   CURRENT   READY   AGE
k8s-secrets-demo-64b7d88484   0         0         0       10m
k8s-secrets-demo-5c97699b8d   1         1         1       87s
k8s-secrets-demo-7545c467f8   0         0         0       9m31s
[kamran@kworkhorse support-files]$ 
```

The secret has been updated inside the pod:

```
[kamran@kworkhorse support-files]$ kubectl -n dev exec k8s-secrets-demo-5c97699b8d-k9jlr -- env | grep MYSQL

MYSQL_ROOT_PASSWORD=DumbHorse
STAKATER_DEV_MYSQL_ROOT_PASSWORD_SECRET=5bc6ee862d580f08ad2d430111c41f15b03f8657

[kamran@kworkhorse support-files]$
```
It works!

------

# Working with secrets with multiple values in them:

We have a secret with multiple values related to one common thing, e.g. a wordpress website (`wbitt.com`) . How do we create it in GCP, and use it through external-secrets?


Here is the example file which contains multipl values:

```
[kamran@kworkhorse support-files]$ cat dev-wordpress-wbitt-com-multivalue-secret.json 
{
"db-host": "mysql.prod.svc.cluster.local:3306",
"db-name": "wbitt-com",
"db-user": "blogger",
"db-password": "FlyingCat"
}
[kamran@kworkhorse support-files]$
```

Create a secret named `dev-wordpress-wbitt-com` in GCP SM.

![images/gcp-muti-value-secret.png](images/gcp-muti-value-secret.png)

Or, you can use command line tool:

```
PROJECT_ID=trainingvideos

cat dev-wordpress-wbitt-com-multivalue-secret.json
  | gcloud secrets \
  --project $PROJECT_ID \
  --data-file=- \
  create dev-wordpress-wbitt-com
```
 
Create the external-secret:

```
[kamran@kworkhorse support-files]$ cat external-secret-gcp-multivalue.yaml 

apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: dev-wordpress-wbitt-com
spec:
  refreshInterval: 1m
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-secret-manager
  target:
    name: dev-wordpress-wbitt-com
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: dev-wordpress-wbitt-com
[kamran@kworkhorse support-files]$ 
```


```
[kamran@kworkhorse support-files]$ kubectl -n dev apply -f external-secret-gcp-multivalue.yaml 
externalsecret.external-secrets.io/dev-wordpress-wbitt-com created
```

Verify:
```
[kamran@kworkhorse support-files]$ kubectl -n dev get externalsecrets
NAME                                                        AGE     STATUS   CAPABILITIES   READY
clustersecretstore.external-secrets.io/gcp-secret-manager   2d20h   Valid    ReadWrite      True
clustersecretstore.external-secrets.io/vault                46h     Valid    ReadWrite      True

NAME                                                              STORE                REFRESH INTERVAL   STATUS         READY
externalsecret.external-secrets.io/dev-postgresql-root-password   vault                1m                 SecretSynced   True
externalsecret.external-secrets.io/dev-mongodb-admin-password     vault                1m                 SecretSynced   True
externalsecret.external-secrets.io/dev-mysql-root-password        gcp-secret-manager   1m                 SecretSynced   True
externalsecret.external-secrets.io/dev-wordpress-wbitt-com        gcp-secret-manager   1m                 SecretSynced   True
[kamran@kworkhorse support-files]$ 
```


Notice a new k8s secret `dev-wordpress-wbitt-com` is automatically created:
```
[kamran@kworkhorse support-files]$ kubectl -n dev get secrets
NAME                           TYPE     DATA   AGE
vault-token                    Opaque   1      46h
dev-postgresql-root-password   Opaque   1      46h
dev-mongodb-admin-password     Opaque   1      15h
dev-mysql-root-password        Opaque   1      58s
dev-wordpress-wbitt-com        Opaque   4      32s
[kamran@kworkhorse support-files]$ 
```


Look inside the k8s secret:
```
[kamran@kworkhorse support-files]$ kubectl -n dev get secret -o yaml dev-wordpress-wbitt-com 

apiVersion: v1
data:
  db-host: bXlzcWwucHJvZC5zdmMuY2x1c3Rlci5sb2NhbDozMzA2
  db-name: d2JpdHQtY29t
  db-password: Rmx5aW5nQ2F0
  db-user: YmxvZ2dlcg==
immutable: false
kind: Secret
metadata:
  annotations:
. . . 
```

Verify that the items inside the secrets have correct values. You can check them individually, or use the following commands.

```
for item in db-host db-name db-user db-password; do
  kubectl -n dev get secret dev-wordpress-wbitt-com -o jsonpath="{.data.$item}" | base64 -d
  echo
done
```


Output:
```
[kamran@kworkhorse support-files]$ for item in db-host db-name db-user db-password; do
  kubectl -n dev get secret dev-wordpress-wbitt-com -o jsonpath="{.data.$item}" | base64 -d
  echo
done

mysql.prod.svc.cluster.local:3306
wbitt-com
blogger
FlyingCat

[kamran@kworkhorse support-files]$

```


## Use this multi-value secret in a deployment/pod:


We have this file:

```
[kamran@kworkhorse support-files]$ cat k8s-secrets-demo-wp-wbitt-com-with-stakater.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-secrets-demo-wp-wbitt-com
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  replicas: 1

  selector:
    matchLabels:
      name: k8s-secrets-demo-wp-wbitt-com

  template:
    metadata:
      labels:
        name: k8s-secrets-demo-wp-wbitt-com
    spec:
      containers:
      - name: network-multitool
        image: kamranazeem/nginx-tls
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          valueFrom:
            secretKeyRef:
              name: dev-wordpress-wbitt-com
              key: db-host
        - name: WORDPRESS_DB_NAME
          valueFrom:
            secretKeyRef:
              name: dev-wordpress-wbitt-com
              key: db-name
        - name: WORDPRESS_DB_USER
          valueFrom:
            secretKeyRef:
              name: dev-wordpress-wbitt-com
              key: db-user

        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: dev-wordpress-wbitt-com
              key: db-password
              
[kamran@kworkhorse support-files]$ 
```

Create the deployment and see if we see secrets inside it:



```
[kamran@kworkhorse support-files]$ kubectl -n dev apply -f k8s-secrets-demo-wp-wbitt-com-with-stakater.yaml 

deployment.apps/k8s-secrets-demo-wp-wbitt-com configured
[kamran@kworkhorse support-files]$
```


```
[kamran@kworkhorse support-files]$ kubectl -n dev get pods
NAME                                            READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-7d87c97794-cplqj               1/1     Running   0          23h
k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj   1/1     Running   0          9s
[kamran@kworkhorse support-files]$ 
```

Look into the pod:

```
[kamran@kworkhorse support-files]$ kubectl -n dev exec k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj -- env | grep WORDPRESS
WORDPRESS_DB_PASSWORD=FlyingCat
WORDPRESS_DB_HOST=mysql.prod.svc.cluster.local:3306
WORDPRESS_DB_NAME=wbitt-com
WORDPRESS_DB_USER=blogger
[kamran@kworkhorse support-files]$ 
```

## Use multi-value secret in a deployment/pod using `envFrom`:

We can simplify the deployment YAML file by using `envFrom:` instead of `env:`, and just giving it the reference of the k8s secret. This will load all the key-value pairs from the secret and create them as ENV variables in the pod. 


```
[kamran@kworkhorse support-files]$ cat k8s-secrets-demo-wp-wbitt-com-using-envfrom-with-stakater.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-secrets-demo-wp-wbitt-com-using-envfrom
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  replicas: 1

  selector:
    matchLabels:
      name: k8s-secrets-demo-wp-wbitt-com-using-envfrom

  template:
    metadata:
      labels:
        name: k8s-secrets-demo-wp-wbitt-com-using-envfrom
    spec:
      containers:
      - name: network-multitool
        image: kamranazeem/nginx-tls
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        envFrom:
        - secretRef:
            name: dev-wordpress-wbitt-com

[kamran@kworkhorse support-files]$
```


```
[kamran@kworkhorse support-files]$ kubectl -n dev apply -f k8s-secrets-demo-wp-wbitt-com-using-envfrom-with-stakater.yaml 

deployment.apps/k8s-secrets-demo-wp-wbitt-com-using-envfrom created
[kamran@kworkhorse support-files]$ 
```

```
[kamran@kworkhorse support-files]$ kubectl -n dev get pods
NAME                                                           READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-7d87c97794-cplqj                              1/1     Running   0          23h
k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj                  1/1     Running   0          11m
k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5   1/1     Running   0          26s
[kamran@kworkhorse support-files]$ 
```


Look inside the pod:
```
[kamran@kworkhorse support-files]$ kubectl -n dev exec k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5 -- env | grep 'WORDPRESS'
[kamran@kworkhorse support-files]$ 



[kamran@kworkhorse support-files]$ kubectl -n dev exec k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5 -- env | grep 'db-'

db-user=blogger
db-host=mysql.prod.svc.cluster.local:3306
db-name=wbitt-com
db-password=FlyingCat
[kamran@kworkhorse support-files]$ 
```



Notice that the variables have the same names as the keys in the k8s secret. If you want the the variables to have proper names (`WORDPRESS_*`), as in the wordpress example above, then you need to use those at the time of creation of the secret in GCP Secret Manager.

**Note:** Rotating secret in GCP will result in a restart of these pods (caused by Stakater), and the (new) pods will load the new secrets.

```
[kamran@kworkhorse support-files]$ kubectl -n dev get pods -w
NAME                                                           READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-7d87c97794-cplqj                              1/1     Running   0          23h
k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj                  1/1     Running   0          35m
k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5   1/1     Running   0          25m


k8s-secrets-demo-wp-wbitt-com-8984bf958-2fqs7                  0/1     Pending   0          0s
k8s-secrets-demo-wp-wbitt-com-8984bf958-2fqs7                  0/1     Pending   0          1s
k8s-secrets-demo-wp-wbitt-com-using-envfrom-56cbb94764-h8wqt   0/1     Pending   0          1s
k8s-secrets-demo-wp-wbitt-com-using-envfrom-56cbb94764-h8wqt   0/1     Pending   0          1s
k8s-secrets-demo-wp-wbitt-com-8984bf958-2fqs7                  0/1     ContainerCreating   0          1s
k8s-secrets-demo-wp-wbitt-com-using-envfrom-56cbb94764-h8wqt   0/1     ContainerCreating   0          1s
k8s-secrets-demo-wp-wbitt-com-8984bf958-2fqs7                  1/1     Running             0          3s
k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj                  1/1     Terminating         0          36m
k8s-secrets-demo-wp-wbitt-com-using-envfrom-56cbb94764-h8wqt   1/1     Running             0          3s
k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5   1/1     Terminating         0          25m
k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj                  0/1     Terminating         0          36m
k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5   0/1     Terminating         0          25m
k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj                  0/1     Terminating         0          36m
k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj                  0/1     Terminating         0          36m
k8s-secrets-demo-wp-wbitt-com-996b98f59-s9kgj                  0/1     Terminating         0          36m
k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5   0/1     Terminating         0          25m
k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5   0/1     Terminating         0          25m
k8s-secrets-demo-wp-wbitt-com-using-envfrom-84d7d6fb4b-9fxp5   0/1     Terminating         0          25m
[kamran@kworkhorse support-files]
```


```
[kamran@kworkhorse support-files]kubectl -n dev get pods 
NAME                                                           READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-7d87c97794-cplqj                              1/1     Running   0          23h
k8s-secrets-demo-wp-wbitt-com-8984bf958-2fqs7                  1/1     Running   0          11s
k8s-secrets-demo-wp-wbitt-com-using-envfrom-56cbb94764-h8wqt   1/1     Running   0          11s
[kamran@kworkhorse support-files]$
```


```
[kamran@kworkhorse support-files]$ kubectl -n dev exec k8s-secrets-demo-wp-wbitt-com-8984bf958-2fqs7 -- env | grep 'WORDPRESS'
WORDPRESS_DB_HOST=mysql.prod.svc.cluster.local:3306
WORDPRESS_DB_NAME=wbitt-com
WORDPRESS_DB_USER=blogger
WORDPRESS_DB_PASSWORD=SwimmingCat
STAKATER_DEV_WORDPRESS_WBITT_COM_SECRET=801e09b8acec4d60c791ae5404a63e84ff369bd4
[kamran@kworkhorse support-files]$
```

```
[kamran@kworkhorse support-files]$ kubectl -n dev exec k8s-secrets-demo-wp-wbitt-com-using-envfrom-56cbb94764-h8wqt -- env | grep 'db-'
db-host=mysql.prod.svc.cluster.local:3306
db-name=wbitt-com
db-password=SwimmingCat
db-user=blogger
[kamran@kworkhorse support-files]$ 
```

The password has been updated correctly. Good!


------

# Handling SSL/TLS certificates through GCP SM and external-secrets:

Suppose something uses SSL certificates, and those SSL certificates are stored in GCPSM. How to create related secrets in Kubernetes? How to restart pods when the certificate is updated?

First create an example selfsigned TLS certificate, and set the certificate validity to 10 days. This will help us to be able to easily identify the change in certificate later.

**Note:** The generated Key and the Certificate will be in the `PEM` format, irrespective of what extension you use for the resulting files.

```
[kamran@kworkhorse support-files]$ openssl req -x509 -nodes \
  -days 10 -newkey rsa:2048 \
  -subj "/CN=example.com" \
  -keyout tls.key -out tls.crt
```

Load the generated certificate into a docker container to test that it works:

The `kamranazeem/nginx-tls` container image is configured to run on HTTP and HTTPS, and expects certificates to be located in `/certs/`. The files it expects are `/certs/tls.key` and `/certs/tls.crt` .

```
[kamran@kworkhorse support-files]$ docker run -v ${PWD}/tls.key:/certs/tls.key -v ${PWD}/tls.crt:/certs/tls.crt -p 8443:443 -d kamranazeem/nginx-tls
```

View the certificate being served through the nginx web server :
```
echo | openssl s_client -showcerts -connect localhost:8443 2>/dev/null | openssl x509 -inform pem -noout -text
```

```
[kamran@kworkhorse support-files]$ echo | openssl s_client -showcerts -connect localhost:8443 2>/dev/null | openssl x509 -inform pem -noout -text | head -16

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            1e:aa:d6:4b:e3:9e:79:65:c0:9d:f9:19:5d:8e:0f:76:5c:be:b6:cb
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = example.com
        Validity
            Not Before: Dec 15 09:39:25 2023 GMT
            Not After : Dec 25 09:39:25 2023 GMT
        Subject: CN = example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:a4:65:10:0f:6c:17:43:33:15:61:1b:ca:59:55:

[kamran@kworkhorse support-files]$ 
```

This is the same certificate that we loaded. Notice the Issuer, and the Validity, which is for 10 days only.

Shutdown the docker container running on local/work computer.

## Create secret for this certificate pair in GCP SM:

The GCP Secret Manager will allow you to upload only one file, against one secret that you create in there. TLS certificate (in PEM) format is normally a pair. So the challenge would be that you will end up creating two separate secrets in GCP SM, e.g. `dev-example-com-tls-key` and `dev-example-com-tls-crt` . There will be two corresponding external secrets against these two GCP SM secrets, which will in turn create two k8s secrets in the namespace of your application, which in-turn will have two `volumeMount` entries in the `deployment.yaml` file of your application. It is do-able but tedious.

There is another way.

You combine/archive these two PEM format files into a single PKCS12 file. Like so:

(choose empty password)

```
[kamran@kworkhorse support-files]$ openssl pkcs12 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -export -out tls.p12 -inkey tls.key -in tls.crt 
```

**Note:** Please see notes at the bottom of this document for the drawbacks of not using these special switches in the command shown above ( `-keypbe` , `-certpbe`, `-macalg`).  

Now, you create the secret `dev-example-com-tls-pkcs12-archive` in GCP SM with this single (PKCS12) file.


![images/gcp-tls-secret-pkcs12.png](images/gcp-tls-secret-pkcs12.png)


## Create external-secret in kubernetes against this GCPSM secret:

Reference: 
* https://external-secrets.io/v0.5.7/guides-common-k8s-secret-types/
* https://external-secrets.io/latest/guides/templating/
* https://external-secrets.io/latest/guides/common-k8s-secret-types/

```
[kamran@kworkhorse support-files]$ kubectl -n dev apply -f external-secret-gcp-tls-example-com.yaml 

externalsecret.external-secrets.io/dev-example-com-tls created
[kamran@kworkhorse support-files]$ 
```

Verify:

```
[kamran@kworkhorse support-files]$ kubectl -n dev get externalsecrets
NAME                                                        AGE     STATUS   CAPABILITIES   READY
clustersecretstore.external-secrets.io/gcp-secret-manager   3d22h   Valid    ReadWrite      True
clustersecretstore.external-secrets.io/vault                3d      Valid    ReadWrite      True

NAME                                                              STORE                REFRESH INTERVAL   STATUS         READY
externalsecret.external-secrets.io/dev-mysql-root-password        gcp-secret-manager   1m                 SecretSynced   True
externalsecret.external-secrets.io/dev-wordpress-wbitt-com        gcp-secret-manager   1m                 SecretSynced   True
externalsecret.external-secrets.io/dev-postgresql-root-password   vault                1m                 SecretSynced   True
externalsecret.external-secrets.io/dev-mongodb-admin-password     vault                1m                 SecretSynced   True
externalsecret.external-secrets.io/dev-example-com-tls            gcp-secret-manager   1h                 SecretSynced   True
[kamran@kworkhorse support-files]$ 
```


```
[kamran@kworkhorse support-files]$ kubectl -n dev get secrets
NAME                           TYPE                DATA   AGE
vault-token                    Opaque              1      3d
dev-postgresql-root-password   Opaque              1      3d
dev-mongodb-admin-password     Opaque              1      41h
dev-mysql-root-password        Opaque              1      26h
dev-wordpress-wbitt-com        Opaque              4      26h
dev-example-com-tls            kubernetes.io/tls   2      52s
[kamran@kworkhorse support-files]$ 
```



```
[kamran@kworkhorse support-files]$ kubectl -n dev get secret dev-example-com-tls -o yaml 
apiVersion: v1
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUREVENDQWZXZ0F3SUJBZ0lVSHFyV1MrT2VlV1hBbmZrWlhZNFBkUlRJRklDQVRFLS0tLS0K
  tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktjd2dnU2pBCkxMLy80bGRGcGRKbEVNZ1k0RHh3Zm9MN01LWjRSazRKVGVRM1JYTlk0L0pIaHdaK1pKcU9sWU1tdTY4VnlldjUKcEdmQWFNdC9oWCtZTG14K2dzNER4REk9Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
immutable: false
kind: Secret
metadata:
  annotations:
    reconcile.external-secrets.io/data-hash: b091011ec346c485acc0ad0b8ab3dc5f
  creationTimestamp: "2023-12-15T13:47:58Z"

. . . 

```



## Create deployment in Kubernetes that uses this certificate:

Lets create a deployment in the Kubernetes cluster, where we use this certificate. 

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-secrets-demo-example-com-tls
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  replicas: 1

  selector:
    matchLabels:
      name: k8s-secrets-demo-example-com-tls

  template:
    metadata:
      labels:
        name: k8s-secrets-demo-example-com-tls
    spec:
      containers:
      - name: nginx-tls
        image: kamranazeem/nginx-tls
        imagePullPolicy: Always
        ports:
        - containerPort: 443
        volumeMounts:
        - name: tls-archive
          mountPath: "/certs/tls.crt"
          subPath: tls.crt
        - name: tls-archive
          mountPath: "/certs/tls.key"
          subPath: tls.key
      volumes:
      - name: tls-archive
        secret:
          secretName: dev-example-com-tls

```


```
[kamran@kworkhorse support-files]$ kubectl -n dev apply -f k8s-secrets-demo-example-com-tls.yaml 

deployment.apps/k8s-secrets-demo-example-com-tls created
[kamran@kworkhorse support-files]$ 
```


```
[kamran@kworkhorse support-files]$ kubectl -n dev get pods 
NAME                                                           READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-7d87c97794-cplqj                              1/1     Running   0          2d2h
k8s-secrets-demo-wp-wbitt-com-8984bf958-2fqs7                  1/1     Running   0          26h
k8s-secrets-demo-wp-wbitt-com-using-envfrom-56cbb94764-h8wqt   1/1     Running   0          26h
k8s-secrets-demo-example-com-tls-57f64675c5-8g8k6              1/1     Running   0          19s
[kamran@kworkhorse support-files]$ 
```

```
[kamran@kworkhorse support-files]$ kubectl -n dev exec -it k8s-secrets-demo-example-com-tls-57f64675c5-8g8k6 -- ls -l /certs/

-rw-r--r--    1 root     root          1119 Dec 15 15:37 tls.crt
-rw-r--r--    1 root     root          1704 Dec 15 15:37 tls.key

[kamran@kworkhorse support-files]$ 
```

On a separate terminal:

```
[kamran@kworkhorse support-files]$ kubectl -n dev port-forward pod/k8s-secrets-demo-example-com-tls-57f64675c5-8g8k6 8443:443

Forwarding from 127.0.0.1:8443 -> 443
Forwarding from [::1]:8443 -> 443
```

On previous terminal, check if nginx pod is serving the correct certificate for `example.com` valid only for `10` days.

```
[kamran@kworkhorse support-files]$ echo | openssl s_client -showcerts -connect localhost:8443 2>/dev/null | openssl x509 -inform pem -noout -text

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            1e:aa:d6:4b:e3:9e:79:65:c0:9d:f9:19:5d:8e:0f:76:5c:be:b6:cb
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = example.com
        Validity
            Not Before: Dec 15 09:39:25 2023 GMT
            Not After : Dec 25 09:39:25 2023 GMT
        Subject: CN = example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:a4:65:10:0f:6c:17:43:33:15:61:1b:ca:59:55:
. . .

```


## Rotate certificate:

Regenerate the SSL certificate and upload as a new version of the secret in GCP SecretManager.

Change `CN` to `example.net`, and set `-days` to `90` days. This will help us easily identify the difference after the pod is restarted.

```
[kamran@kworkhorse support-files]$ openssl req -x509 -nodes \
  -days 90 -newkey rsa:2048 \
  -subj "/CN=example.net" \
  -keyout tls.key -out tls.crt
```

Create a new tls archive in PKCS12 format:

(choose empty password)

```
[kamran@kworkhorse support-files]$ openssl pkcs12 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -export -out tls.p12 -inkey tls.key -in tls.crt 
```

Upload the certificate to GCP SM.


Shortly after the secret is updated in GCP SM, a new pod has started:

```
[kamran@kworkhorse support-files]$ kubectl -n dev get pods
NAME                                                           READY   STATUS    RESTARTS   AGE
k8s-secrets-demo-7d87c97794-cplqj                              1/1     Running   0          2d2h
k8s-secrets-demo-wp-wbitt-com-8984bf958-2fqs7                  1/1     Running   0          26h
k8s-secrets-demo-wp-wbitt-com-using-envfrom-56cbb94764-h8wqt   1/1     Running   0          26h
k8s-secrets-demo-example-com-tls-56d9685c48-zj8x4              1/1     Running   0          34s
[kamran@kworkhorse support-files]$ 
```

Examine certificate again. You will see a new certificate, this time with `CN=example.net` and valid for `90` days:

```
[kamran@kworkhorse support-files]$ echo | openssl s_client -showcerts -connect localhost:8443 2>/dev/null | openssl x509 -inform pem -noout -text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            10:3d:f8:59:fe:6f:f1:b1:ef:5b:51:63:7a:2c:33:3b:92:95:a9:17
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = example.net
        Validity
            Not Before: Dec 15 15:45:20 2023 GMT
            Not After : Mar 14 15:45:20 2024 GMT
        Subject: CN = example.net
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c9:2b:6a:b1:ea:45:67:45:5c:d1:b4:dc:63:81:

. . . 
```






------
# Other notes:

If the PKCS12 archve is encoded with more modern algorithms (i.e. when you use `openssl pkcs12 -export` with defaults), then external-secrets operator (or it's built-in functions) won't be able to decode the certificate and the key.

```
[kamran@kworkhorse support-files]$ openssl pkcs12 -export -out tls.p12 -inkey tls.key -in tls.crt 
```

Then create the external secret using the `external-secret-gcp-tls-example-com.yaml` , and check:

```
[kamran@kworkhorse support-files]$ kubectl -n dev get externalsecrets
NAME                                                        AGE     STATUS   CAPABILITIES   READY
clustersecretstore.external-secrets.io/gcp-secret-manager   3d22h   Valid    ReadWrite      True
clustersecretstore.external-secrets.io/vault                3d      Valid    ReadWrite      True

NAME                                                              STORE                REFRESH INTERVAL   STATUS              READY
externalsecret.external-secrets.io/dev-mysql-root-password        gcp-secret-manager   1m                 SecretSynced        True
externalsecret.external-secrets.io/dev-wordpress-wbitt-com        gcp-secret-manager   1m                 SecretSynced        True
externalsecret.external-secrets.io/dev-postgresql-root-password   vault                1m                 SecretSynced        True
externalsecret.external-secrets.io/dev-mongodb-admin-password     vault                1m                 SecretSynced        True
externalsecret.external-secrets.io/dev-example-com-tls            gcp-secret-manager   1h                 SecretSyncedError   False
```


```
[kamran@kworkhorse support-files]$ kubectl -n dev describe externalsecret.external-secrets.io/dev-example-com-tls

. . . 

Events:
  Type     Reason        Age              From              Message
  ----     ------        ----             ----              -------
  Warning  UpdateFailed  5s (x3 over 6s)  external-secrets  could not apply template: could not execute template: could not execute template: unable to execute template at key tls.key: unable to execute template at key tls.key: template: tls.key:1:17: executing "tls.key" at <pkcs12key>: error calling pkcs12key: unable to decode pkcs12 with password: pkcs12: unknown digest algorithm: 2.16.840.1.101.3.4.2.1
  Warning  UpdateFailed  0s (x8 over 7s)  external-secrets  could not apply template: could not execute template: could not execute template: unable to execute template at key tls.crt: unable to execute template at key tls.crt: template: tls.crt:1:17: executing "tls.crt" at <pkcs12cert>: error calling pkcs12cert: unable to decode pkcs12 certificate with password: pkcs12: unknown digest algorithm: 2.16.840.1.101.3.4.2.1
[kamran@kworkhorse support-files]$ 

```


(End of HowTo)

