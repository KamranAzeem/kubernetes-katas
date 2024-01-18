# Setup Namespace

Namespaces are the default way for kubernetes to separate resources. Namespaces do not share anything between them, which is important to know, and thus come in handy when you have multiple users on the same cluster, that you don't want stepping on each other's toes :)

## Create a namespace:

Choose a name for your namespace, something unique so you don't clash with one of the other participants at the workshop.

```
$ kubectl create namespace student47
namespace "student47" created
```

## Scoping the kubectl command:

You want to target your own namespace instead of default one every time you use `kubectl`. You can run a command in a specific namespace by using the `-n | --namespace` flag.


```
kubectl get pods
```

```
kubectl get pods -n student47
```

## Set your default namespace:

On a multi-tenant Kubernetes cluster, especially in lab/training environment, you want to run `kubectl` to be targeting your own namespace, and specifying `-n your-name-space` may be tedious. In that case, you can actually set a specific namespace as the default namespace for your current context.

To overwrite the default namespace for your current `context`, run:

```
$ kubectl config set-context $(kubectl config current-context) --namespace=my-namespace

Context "<your current context>" modified.
```

Or perform the same step with two individual commands:
```
$ kubectl config current-context
gke_praqma-education_europe-north1-a_kamran-test-cluster-0617

$ kubectl  config \
  set-context gke_praqma-education_europe-north1-a_kamran-test-cluster-0617 \
  --namespace=student47

Context "gke_praqma-education_europe-north1-a_kamran-test-cluster-0617" modified.
```


You can verify that you've updated your current `context` by running:

```
$ kubectl config get-contexts
```

```
$ kubectl config get-contexts

CURRENT   NAME                                                            CLUSTER                                                         AUTHINFO                                                        NAMESPACE
*         gke_praqma-education_europe-north1-a_kamran-test-cluster-0617   gke_praqma-education_europe-north1-a_kamran-test-cluster-0617   gke_praqma-education_europe-north1-a_kamran-test-cluster-0617   student47
```

Notice that the namespace column has now value of what you specified.

On a multi-tenant cluster, most errors you will get will be due to deploying into a namespace, where someone's already done the exercise before you. Therefore always ensure you're using your own newly created namespace!

## More on Namespaces:

Kubernetes clusters come with a namespace called `default` with nothing in it, and another one called `kube-system` which will contain some of the kubernetes services running in the cluster. There may be a couple of more namespaces depending on who is the service provider of the Kubernetes cluster that you are running.
