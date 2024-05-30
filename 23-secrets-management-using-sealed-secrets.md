# "Sealed Secrets" for Kubernetes
**Reference:** https://github.com/bitnami-labs/sealed-secrets?tab=readme-ov-file#installation

## The problem and the solution:
**Problem:** "I can manage all my K8s config in git, except Secrets."

**Solution:** Encrypt your Secret into a SealedSecret, which is safe to store - even inside a public repository. The SealedSecret can be decrypted only by the controller running in the target cluster and nobody else. Not even the original (human) author is able to obtain the original Secret from the SealedSecret.

## Moving parts:
Sealed Secrets is composed of two parts:

* A cluster-side controller / operator, normally named `sealed-secrets-controller` 
* A client-side utility: `kubeseal`

The `kubeseal` utility uses asymmetric crypto to encrypt secrets that only the controller can decrypt.

## Installation in the Kubernetes cluster:

```
$ helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets

"sealed-secrets" has been added to your repositories
```

The helm chart by default installs the controller with the name `sealed-secrets`, while the `kubeseal` client tries to access the controller with the name `sealed-secrets-controller`. To keep things simple, we install the helm chart by passing the custom name for the controller.
 
```
$ helm install sealed-secrets \
  -n kube-system \
  --set-string fullnameOverride=sealed-secrets-controller \
  sealed-secrets/sealed-secrets


NAME: sealed-secrets
LAST DEPLOYED: Thu Mar 28 13:21:55 2024
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

You should now be able to create sealed secrets.

1. Install the client-side tool (kubeseal) as explained in the docs below:

    https://github.com/bitnami-labs/sealed-secrets#installation-from-source

2. Create a sealed secret file running the command below:

    kubectl create secret generic secret-name --dry-run=client --from-literal=foo=bar -o [json|yaml] | \
    kubeseal \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=kube-system \
      --format yaml > mysealedsecret.[json|yaml]

The file mysealedsecret.[json|yaml] is a commitable file.

If you would rather not need access to the cluster to generate the sealed secret you can run:

    kubeseal \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=kube-system \
      --fetch-cert > mycert.pem

to retrieve the public cert used for encryption and store it locally. You can then run 'kubeseal --cert mycert.pem' instead to use the local cert e.g.

    kubectl create secret generic secret-name --dry-run=client --from-literal=foo=bar -o [json|yaml] | \
    kubeseal \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=kube-system \
      --format [json|yaml] --cert mycert.pem > mysealedsecret.[json|yaml]

3. Apply the sealed secret

    kubectl create -f mysealedsecret.[json|yaml]

Running 'kubectl get secret secret-name -o [json|yaml]' will show the decrypted secret that was generated from the sealed secret.

Both the SealedSecret and generated Secret must have the same name and namespace.
```

Verify the sealed-secrets installation:

```
$ kubectl -n kube-system get crds

NAME                                CREATED AT
. . . 

sealedsecrets.bitnami.com           2024-03-28T12:21:55Z

. . . 
```

```
$ kubectl -n kube-system get pods

NAME                                         READY   STATUS    RESTARTS       AGE
coredns-76f75df574-7sx6m                     1/1     Running   5 (2d4h ago)   13d
coredns-76f75df574-9n9tr                     1/1     Running   5 (2d4h ago)   13d
etcd-kind-control-plane                      1/1     Running   2 (2d4h ago)   8d
kindnet-mf75m                                1/1     Running   5 (2d4h ago)   13d
kube-apiserver-kind-control-plane            1/1     Running   2 (2d4h ago)   8d
kube-controller-manager-kind-control-plane   1/1     Running   6 (2d4h ago)   13d
kube-proxy-dsht9                             1/1     Running   5 (2d4h ago)   13d
kube-scheduler-kind-control-plane            1/1     Running   6 (2d4h ago)   13d
sealed-secrets-controller-6cd6668c69-7hnrm   1/1     Running   0              3m24s
```

```
$ kubectl -n kube-system get svc

NAME                                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE
kube-dns                            ClusterIP   10.96.0.10      <none>        53/UDP,53/TCP,9153/TCP   13d
sealed-secrets-controller           ClusterIP   10.96.107.120   <none>        8080/TCP                 3m35s
sealed-secrets-controller-metrics   ClusterIP   10.96.165.114   <none>        8081/TCP                 3m35s
```

## Install client utility on local computer- `kubeseal`:

```
# Set this to, for example, KUBESEAL_VERSION='0.26.1'
KUBESEAL_VERSION='0.26.1' 

wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION:?}/kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz"

tar -xvzf kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz kubeseal

cp  kubeseal ~/.local/bin/kubeseal
```

Run the following command to validate that kubeseal is able to talk to the sealed-secrets-controller inside the kubernetes cluster:

```
$ kubeseal --validate

(tty detected: expecting json/yaml k8s resource in stdin)
```

If something is wrong, you will see something like this:

```
$ kubeseal --validate

(tty detected: expecting json/yaml k8s resource in stdin)
error: cannot get sealed secret service: services "sealed-secrets-controller" not found.
```

## Create a test sealed secret in the `default` namespace:

```
$ kubectl create secret generic mysecret \
  --dry-run=client \
  --from-literal=foo=bar \
  -o yaml | kubeseal -n default --format yaml > mysealedsecret.yaml
```

View the generated (sealed-secret) file. Notice the **`kind`** is `SealedSecret` , and is not `Secret`.

```
$ cat mysealedsecret.yaml 

apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: mysecret
  namespace: default
spec:
  encryptedData:
    foo: AgB82sZGsS6fdE8PrCe6i3K0oLNvDvHiKLZ+oDQ/WlqX6FOSeUFuoF++hJHRRlAW2qwu2RZa3WnWpN8DYE++/z1I2icSMhWuNb7Rc8wdDlFZDTGmk7P0GQnZd0WNTCxqJIIu7pZLOSkLW+V82mjmLZ3/C60R+/gvJnTvwGN4J6vIOLXdAHx3lfYoOpVgASqRw5M18o8h1shlazk16EFAcwYx2k1ItXzxlDhf4uYKpnpALQniCJ34gbE6aw+UQyTyAS6FR9bt4Fcnp6aa1EI4ihkH4GUSiuZ/d2TLTQIhI05LqSQroThGSeWjtbmXZ9NTS6ioox/BQs5P3PgpXeAkzstGw6Ph9CA/2IjN33cS9yL1KliB1b8dYvsQrWFMBJDDI3BEXGdNHKgvy2d6wOnaVCgr1wDGQ5xfg0nhhGEeBxPJi9GLIcEjg1bKJsu2XB3Sn1ajR9cm8wB4nbjUDEujmfpIYfyB5FOk3LAtx1Mv4VQbBCYDEcFp3HatwcqfykVCtQbgpQi0TfwLW9uifVJU+jGubWXgUT5a7ennyfsugjeDuH+xvLl8W2bZvQo9Y+3sjuJVXpc6qHV17C6S/3mX+RhgMdjjC7euN6abqFz2zJ7BRnI3tvANhcIsKlhx9nUfvZ4P5tz0l3XMCFGueD9rfeZDr6TsM/1hKF/AgIGWYIOCQujJ8e4F74BLdrN2va3kE07rA40=
  template:
    metadata:
      creationTimestamp: null
      name: mysecret
      namespace: default
```

Apply the sealed secret:

```
$  kubectl create -f mysealedsecret.yaml

sealedsecret.bitnami.com/mysecret created
```



```
$ kubectl -n default get sealedsecrets,secrets
NAME                                STATUS   SYNCED   AGE
sealedsecret.bitnami.com/mysecret            True     19s

NAME                           TYPE     DATA   AGE
secret/mysecret                Opaque   1      19s
```

Verify:

```
$ kubectl get secret mysecret -o yaml
apiVersion: v1
data:
  foo: YmFy
kind: Secret
metadata:
  creationTimestamp: "2024-03-28T13:21:53Z"
  name: mysecret
  namespace: default
  ownerReferences:
  - apiVersion: bitnami.com/v1alpha1
    controller: true
    kind: SealedSecret
    name: mysecret
    uid: e7595787-618c-4c96-b572-b3d714e472f6
  resourceVersion: "506780"
  uid: 0f8ea885-8935-4171-9f9f-391b6b252ef9
type: Opaque
```

**Note:** If you delete a `sealedsecret` then the corresponding `secret` will be automatically deleted, because a `sealedsecret` owns the `secret` it created.

```
$ kubectl -n default delete sealedsecret mysecret
sealedsecret.bitnami.com "mysecret" deleted


$ kubectl -n default get sealedsecrets,secrets
No resources found in default namespace.
```

**Note:** If you delete a `secret`, then it will be automatically recreated by the sealed-secret-controller as long as it's parent `sealedsecret` exists.

```
$ kubectl -n default get secrets

NAME       TYPE     DATA   AGE
mysecret   Opaque   1      46h
```

```
$ kubectl -n default get sealedsecrets

NAME       STATUS   SYNCED   AGE
mysecret            True     46h
```

```
$ kubectl -n default delete secret mysecret

secret "mysecret" deleted
```

```
$ kubectl -n default get secrets

NAME       TYPE     DATA   AGE
mysecret   Opaque   1      5s
```

You can now use this secret as usual in your Kubernetes deployments.
