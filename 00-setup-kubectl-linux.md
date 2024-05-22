# Setup kubectl - for correct context:

It is assumed that you are provided with a kubernetes cluster by the instructor. Before you are able to do anything on the cluster, you need to be able to *talk* to this cluster from/using your computer. **kubectl** - short for Kubernetes Controller (or Kube Control) - is *the* command line tool to talk to a Kubernetes cluster. 

## What is kubectl?
`kubectl` is a *go* binary which allows you to execute commands on your cluster. Your cluster could be a single node VM, such as [minikube](https://github.com/kubernetes/minikube), or a set of VMs on your local computer or somewhere on a host in your data center, a bare-metal cluster, or a cluster provided by any of the cloud providers - as a service - such as GCP. In any case, the person who sets up the kubernetes cluster will provide you with the credentials to access the cluster. Normally it the credentials are in a form of a file called `.kube/config`, which is generated automatically when you provision a kubernetes cluster using `minikube` , `kubeadm` or `kube-up.sh` or any other methods.

For instructions on connecting to minikube and kubeadm based clusters, the information is available [here](https://github.com/KamranAzeem/learn-kubernetes/tree/master/minikube), and [here](https://github.com/KamranAzeem/learn-kubernetes/blob/master/kubeadm/README.md). 

**Note:** It is useful to know that `kubectl` binary is also part of **Google Cloud SDK** . If you install google-cloud-sdk, then you can use gcloud to install the `kubectl` component/binary. If you are already provided with a kubernetes cluster *config* file by your instructor, then you probably don't need to install google-cloud-sdk. In that case you will need to follow these instructions to install `kubectl` on your computer.

To get `kubectl` on your computer, you have to use the following commands:

### Linux (distribution agnostic/independent binary) :

Run the following commands:

```
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

chmod +x ./kubectl

sudo mv ./kubectl /usr/bin/kubectl
```

### macOS:

Run the following commands:

```
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl

chmod +x ./kubectl

sudo mv ./kubectl /usr/local/bin/kubectl
```

### Windows:

First, check the latest version of kubectl from [https://storage.googleapis.com/kubernetes-release/release/stable.txt](https://storage.googleapis.com/kubernetes-release/release/stable.txt)

Then, using the version information you got from the above link, run the following `curl` command to download the `kubectl.exe` file on your computer. (Replace `v1.13.0` with the version you got from the above link). Then place the file in one of the directories specified in your PATH environment variable.

```
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kubectl.exe
```

## Configure kubectl to access your cluster:

There are several ways to configure `kubectl` to be able to talk to your kubernetes cluster. Some/most-useful are described in the sections below.

**Note:** This will be a straight-forward procedure for most of the students, who are new to Kubernetes, and this is their first interaction with a kubernetes cluster. However, there will be some students, who may already have access to some clusters, and they will have their `kubectl` configured to talk to those clusters. They may be concerned that the procedure below may over-write their configurations, or they may lose access to their existing clusters. This is to assure you that nothing bad will happen to your existing `kubectl` configurations. Whenever you configure `kubectl` to talk to a cluster, it adds a new set of entries on your existing `~/.kube/config` file. However, to be safe, and for peace of mind, you should backup your `~/.kube/config` before proceeding with the instructions below.

### Minikube: 

When you setup `minikube`, usually by `minikube start`, it sets up the correct context for `kubectl`, in the `.kube/config` file. There is no authentication, etc. You are ready to go. 

Start `minikube`:

```
$ minikube start
😄  minikube v1.32.0 on Fedora 38
    ▪ KUBECONFIG=/home/kamran/.kube/config:/home/kamran/.kube/k3s.yaml
✨  Using the docker driver based on existing profile
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
🤷  docker "minikube" container is missing, will recreate.
🔥  Creating docker container (CPUs=2, Memory=3900MB) ...
🐳  Preparing Kubernetes v1.28.3 on Docker 24.0.7 ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
    ▪ Using image registry.k8s.io/ingress-nginx/controller:v1.9.4
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
    ▪ Using image registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231011-8b53cabe0
    ▪ Using image registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231011-8b53cabe0
🔎  Verifying ingress addon...
🌟  Enabled addons: storage-provisioner, default-storageclass, ingress
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

Check list of kubernetes/cluster contexts:

```
$ kubectl config get-contexts
CURRENT   NAME                                            CLUSTER                                         AUTHINFO                                        NAMESPACE
          k3s                                             k3s                                             k3s                                             
*         minikube                                        minikube                                        minikube                                        default
          teleport.infra.aidn.no-demo                     teleport.infra.aidn.no                          teleport.infra.aidn.no-demo                     
          teleport.infra.aidn.no-infra                    teleport.infra.aidn.no                          teleport.infra.aidn.no-infra                    
```

Check the nodes:

```
$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   61d   v1.28.3
```

```
$ kubectl get pods
No resources found in default namespace.
```


## Kind cluster:

`kind` also sets correct kubectl context for you automatically.

You can also install kind, which stands for "Kubernetes in Docker."

Reference: https://kind.sigs.k8s.io/docs/user/quick-start/#installation

* Mac: `brew install kind`
* Linux AMD64: `[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64`
* Linux ARM64: `[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-arm64`

```
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Create kind cluster:

```
kind create cluster --name k8s-training
```


## Configure kubectl to connect to your cluster - using `config` file provided by instructor:

In case you are provided by a `config` file, simply create a `.kube` directory under your home directory, place it inside it. i.e. `/home/<username>/.kube/`. This file contains all information to correctly authenticate and connect to the cluster assigned to you.  Make sure to backup any existing `.kube/config` before you do this. 

If you have an existing `.kube/config` file, then you can't merge the config file from the instructor with existing file directly. A simpler way is to create the new file with a new name within the `.kube/` directory. e.g. `.kube/gke-lab-cluster.yaml`, and then update a specific environment variable in the shell.

```
export KUBECONFIG=$HOME/.kube/config:$HOME/.kube/gke-lab-cluster.yaml
```

**Note:** Windows users need to adjust the path to the home directory in the instructions above. 

### Authenticate to your Google/GKE cluster - using gcloud utility:

**Note:** This does not apply to minikube and kubeadm based clusters.

This step is needed if you are **not** provided with a `config` file by your instructor, or, you have a kubernetes cluster of your own in google cloud, which you want to connect to.

To authenticate against your cluster, you will need a gmail account. You also need `gcloud` utility from Google Cloud SDK installed on your computer. The Cloud SDK is a set of tools for Cloud Platform. It contains gcloud, gsutil, and bq command-line tools, which you can use to access Google Compute Engine, Google Cloud Storage, Google BigQuery, and other products and services from the command-line.

Refer to this URL for instructions: [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)

### Verify `kubectl` configuration:

Now that you have completed the `kubectl` setup, you need to verify that you have configured `kubectl` *correctly*, and it is able to *talk to* your kubernetes cluster.

```
$ kubectl config get-contexts
CURRENT   NAME                                            CLUSTER                                         AUTHINFO                                        NAMESPACE
          gke_witline_europe-west2-a_witline-production   gke_witline_europe-west2-a_witline-production   gke_witline_europe-west2-a_witline-production   
          k3s                                             k3s                                             k3s                                             
*         minikube                                        minikube                                        minikube                                        default
```

You can connect to different clusters, by switching context. Use the following command:

```
$ kubectl config use-context k3s

$ kubectl config use-context minikube

$ kubectl config use-context gke_witline_europe-west2-a_witline-production
```


There is also a `kubectl cluster-info` command, which gives you the address of the master node of the currently selected cluster.
```
$ kubectl cluster-info
Kubernetes control plane is running at https://192.168.49.2:8443
CoreDNS is running at https://192.168.49.2:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

If `kubectl cluster-info` returns the URL, but you can’t access your cluster use `dump` with the previous command:

```
$ kubectl cluster-info dump
```

Get the list of nodes:

```
$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   61d   v1.28.3
```

If you add the `-o wide` parameters to the above command, you will also see the (public) IP addresses of the nodes:

```
$ kubectl get nodes -o wide
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION          CONTAINER-RUNTIME
minikube   Ready    control-plane   61d   v1.28.3   192.168.49.2   <none>        Ubuntu 22.04.3 LTS   6.6.4-100.fc38.x86_64   docker://24.0.7
```

If your cluster is on GKE, you should be able to see something similar:

```
$ kubectl get nodes
NAME                                                 STATUS   ROLES    AGE   VERSION
gke-witline-production-nodepool-1-24-739c7460-hpfb   Ready    <none>   74d   v1.26.6-gke.1700
gke-witline-production-nodepool-1-24-739c7460-nbhl   Ready    <none>   74d   v1.26.6-gke.1700

```

If you add the `-o wide` parameters to the above command, you will also see the public IP addresses of the nodes:

```
$ kubectl get nodes -o wide
NAME                                                 STATUS   ROLES    AGE   VERSION            INTERNAL-IP   EXTERNAL-IP      OS-IMAGE                             KERNEL-VERSION   CONTAINER-RUNTIME
gke-witline-production-nodepool-1-24-739c7460-hpfb   Ready    <none>   74d   v1.26.6-gke.1700   10.154.0.19   34.142.1.1     Container-Optimized OS from Google   5.15.107+        containerd://1.6.18
gke-witline-production-nodepool-1-24-739c7460-nbhl   Ready    <none>   74d   v1.26.6-gke.1700   10.154.0.18   34.147.207.2   Container-Optimized OS from Google   5.15.107+        containerd://1.6.18

```

**Note:** On some service providers (GCP), you will only see worker nodes, as shown above. On other clusters (AWS), you will see both master and worker nodes.

Below is a cluster from AWS.

```
$ kubectl get nodes -o wide
NAME                                             STATUS    ROLES     AGE     VERSION   EXTERNAL-IP     OS-IMAGE                      KERNEL-VERSION   CONTAINER-RUNTIME
ip-172-20-40-108.eu-central-1.compute.internal   Ready     master    1d      v1.8.0    1.2.3.4         Debian GNU/Linux 8 (jessie)   4.4.78-k8s       docker://1.12.6
ip-172-20-49-54.eu-central-1.compute.internal    Ready     node      1d      v1.8.0    2.3.4.5         Debian GNU/Linux 8 (jessie)   4.4.78-k8s       docker://1.12.6
ip-172-20-60-255.eu-central-1.compute.internal   Ready     node      1d      v1.8.0    5.6.7.8         Debian GNU/Linux 8 (jessie)   4.4.78-k8s       docker://1.12.6
```

**Note:** Depending on the setup for this workshop, you may not be the only tenant on the cluster; you may be sharing it with the rest of the people around you in the course! So be careful!
