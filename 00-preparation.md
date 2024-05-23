# Preparation:
The usual first step of any training course is to prepare your local computer. This one is no different.

To be able to complete this course, you would need:
* access to a computer - usually your home/work computer
* a kubernetes cluster - either provided by your instructor, or set up by yourself on your local computer using `minikube` or `kind`
* `kubectl` CLI tool installed on your local computer.
* a clone of this training course's repository on your local computer

## Install kubectl 
Follow instructions from the Kubernetes official documentation on how to install kubectl on your local computer.

* [Linux: ](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux)
* [macOS: ](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos)
* [Windows: ](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows)


## Configure kubectl - for correct cluster context:
The `kubectl` tool would need to be setup to correct (cluster) context. 

* If you are setting up your own local kubernetes cluster on your local computer - e.g. `minikube` or `kind`, then usually the command that brings up the local kubernetes cluster will also setup the correct context for `kubectl`.
* In case the kubernetes cluster is provided by your instructor, a *kubeconfig* file will be provided to you. 

You can check the kubectl context using:

```
$ kubectl config get-contexts
```

You can set/configure kubectl to use the desired kubernetes cluster (context) using:

```
$ kubectl config use-context <context-name>
```

In case you are provided by a `config` file (say `training-cluster.config`), simply create a `.kube` directory under your home directory, place the received file inside it. i.e. `/home/<username>/.kube/training-cluster.config`. This file contains all information to correctly authenticate and connect to the cluster assigned to you.  Make sure to backup any existing `.kube/config` before you do this. The file is in YAML format.

Then, setup `KUBECONFIG` environment variable to include that config file. This variable is used by the kubectl command to gather list of all available clusters, users, contexts.

```
export KUBECONFIG=$HOME/.kube/config:$HOME/.kube/training-cluster.config
```

**Note:** You can't simply merge the config file from the instructor with existing `.kube/config` file directly.

## Install a small kubernetes cluster on your local computer:
Usually the participants want to have their own cluster on their local computer. There are many options, but we recommend either `minikube` or `kind`.

### Install Minikube: 

Minikube can be run as a VM or as a docker container. This means, you need to have either a virtualization service or Docker running on your local computer.

Follow the minikube installation instructions from here: https://minikube.sigs.k8s.io/docs/start/ 

When you setup `minikube`, usually by `minikube start`, it sets up the correct context for `kubectl`, in the `.kube/config` file. There is no authentication, etc. You are ready to go. 

Start `minikube`:

```
$ minikube start
. . . 

🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

Check list of kubernetes/cluster contexts. Notice that the minikube cluster is set as the default context for `kubectl`.

```
$ kubectl config get-contexts
CURRENT   NAME                                            CLUSTER                                         AUTHINFO                                        NAMESPACE
          k3s                                             k3s                                             k3s                                             
*         minikube                                        minikube                                        minikube                                        default
          teleport.infra.aidn.no-demo                     teleport.infra.aidn.no                          teleport.infra.aidn.no-demo                     
          teleport.infra.aidn.no-infra                    teleport.infra.aidn.no                          teleport.infra.aidn.no-infra                    
```

Check the nodes of this cluster:

```
$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   61d   v1.28.3
```

```
$ kubectl get pods
No resources found in default namespace.
```


## Install Kind cluster:

Kind (Kubernetes in Docker) is another option for running a small kubernetes cluster locally. 

Installation instructions for Kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation

**Note:** Kind runs as a Docker container, so you need to have Docker service running on your local computer.

When you start `kind`,  it sets correct kubectl context for you automatically.

Create kind cluster:

```
$ kind create cluster --name k8s-training
Creating cluster "k8s-training" ...
. . . 

Set kubectl context to "kind-k8s-training"
You can now use your cluster with:

kubectl cluster-info --context kind-k8s-training

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
```

```
$ kubectl get nodes
NAME                         STATUS   ROLES           AGE   VERSION
k8s-training-control-plane   Ready    control-plane   96s   v1.29.2
```

```
$ kubectl get pods
No resources found in default namespace.
```


Delete kind cluster:

```
$ kind delete cluster --name k8s-training
```

## Connecting to Kubernetes clusters running on cloud providers:

To connect to a kubernetes cluster running on a cloud provider (GKE, AWS, AKS, etc), you would usually be required to authenticate to the cloud provider before setting up kubectl.

The steps vary from provider to provider. For this reason, the steps are not provided here.
