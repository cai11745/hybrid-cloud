---
layout: post
title:  kubernetes/openshift 应用异常诊断思路
category: kubernetes,openshift,trobshooting
description: 
---

分享一下本人在k8s openshift项目中积累的一些异常诊断方法，希望能带给各位一些帮助。 本文主要描述问题解决流程和思路，针对应用发布/运行异常、访问异常，会插入一些场景。
分两部分
1. 应用发布后运行异常，即pod 无法正常启动或者启动后无限重启
2. 应用运行正常，pod 状态是running，但是无法通过ingress，nodeport，router等方式访问

### 一些技巧写在前面
应该能够在平时运维上提高一丢丢效率
1. kubectl 命令table自动补全
```bash
echo 'source <(kubectl completion bash)' >>/etc/profile
source  /etc/profile

# mac
echo 'source <(kubectl completion zsh)' >> ~/.zshrc
source  ~/.zshrc
```

2. 切换namespace/project
```bash
# 使用非default namespace，先写 -n xxx ,不影响table补全 xxx
kubectl -n kube-system get deploy
kubectl -n kube-system describe pod xxx

# 如果长期在某个namespace下操作，可以设置默认namespace
kubectl config set-context --current --namespace=kube-system
kubectl get pod   #看到的都是kube-system下的pod

# 如果是openshift，直接oc project 可以切换
oc project openshift-infra
```

### 应用运行异常整体处理流程
![trobshooting-1](../image/trobshooting-1.png)

从发布一个应用开始。应用是指deployment或者deploymentconfig，以下简称deploy 和dc。deploymentconfig是openshift中常用的控制器，可以简单理解为和deploy类似。
大部分的异常现象是我们kubectl get pod 发现pod 一指处于creating 或crash 或一直restart，或根本看不到pod。
图中每个操作默认第一个命令是kubectl,如kubectl describe pod xxx
以下详述各步骤操作缘由和可能引起的原因。

### 



准备不低于2台虚机。 1台 master，其余的做node

OS: Centos7.5 mini install。 最小化安装。配置节点IP

|主机名|IP| 配置|
|----|----|----|
|master1|192.168.4.130| 4C 8G|
|node1|192.168.4.131| 4C 8G|

分别设置主机名为master1 node1 ... 时区
```
timedatectl set-timezone Asia/Shanghai  #都要执行
hostnamectl set-hostname master1   #master1执行
hostnamectl set-hostname node1    #node1执行
```
在所有节点/etc/hosts中添加解析,master1,node1
```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.4.130 matser1
192.168.4.131 node1
```
关闭所有节点的seliux以及firewalld
```
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
systemctl disable firewalld
systemctl stop firewalld
```

### 2. 安装docker

使用文件docker-ce-18.09.tar.gz，每个节点都要安装。
```
tar -zxvf docker-ce-18.09.tar.gz
cd docker
rpm -Uvh * 或者  yum  localinstall *.rpm  进行安装，yum命令可以自动解决依赖
docker version        #安装完成查看版本
```
启动docker，并设置为开机自启
```
systemctl start docker && systemctl enable docker
```
输入docker info，==记录Cgroup Driver==
Cgroup Driver: cgroupfs
docker和kubelet的cgroup driver需要一致，如果docker不是cgroupfs，则执行
```
cat << EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=cgroupfs"]
}
EOF
systemctl daemon-reload && systemctl restart docker
```

### 2. 安装kubeadm，kubectl，kubelet

使用文件kube114-rpm.tar.gz，每个节点都要安装

kubeadm是集群部署工具

kubectl是集群管理工具，通过command来管理集群

kubelet的k8s集群每个节点的docker管理服务

```
tar -zxvf kube114-rpm.tar.gz 
cd kube114-rpm
yum  localinstall *.rpm  进行安装，yum命令可以自动解决依赖
```

关闭swap，及修改iptables，不然后面kubeadm会报错
```
swapoff -a
vi /etc/fstab   #swap一行注释
```
```
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
```

### 3. 导入镜像

使用文件k8s-114-images.tar.gz flannel-dashboard.tar.gz，每个节点都要执行

节点较少，就不搭建镜像仓库服务了，后续要用的应用镜像，每个节点都要导入

```
docker load -i k8s-114-images.tar.gz
docker load -i flannel-dashboard.tar.gz 
一共9个镜像，分别是
k8s.gcr.io/kube-apiserver:v1.14.1
k8s.gcr.io/kube-controller-manager:v1.14.1
k8s.gcr.io/kube-scheduler:v1.14.1
k8s.gcr.io/kube-proxy:v1.14.1
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd:3.3.10
k8s.gcr.io/coredns:1.3.1
k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1
quay.io/coreos/flannel:v0.11.0-amd64
```
### 4. kubeadm init 部署master节点

只在master执行。此处选用最简单快捷的部署方案。etcd、api、controller-manager、 scheduler服务都会以容器的方式运行在master。etcd 为单点，不带证书。etcd的数据会挂载到master节点/var/lib/etcd

init部署是支持etcd 集群和证书模式的，配置方法见我1.9的文档，此处略过。

init命令注意要指定版本，和pod范围

```
kubeadm init --kubernetes-version=v1.14.1 --pod-network-cidr=10.244.0.0/16

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.4.130:6443 --token 911xit.xkp2gfxbvf5wuqz7 \
    --discovery-token-ca-cert-hash sha256:23db3094dc9ae1335b25692717c40e24b1041975f6a43da9f43568f8d0dbac72
```

记下join的命令，后续node节点加入的时候要用到

执行提示的命令，保存kubeconfig
```
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

此时执行kubectl get node 已经可以看到master节点，notready是因为还未部署网络插件

```
[root@master1 ~]# kubectl get node
NAME      STATUS     ROLES    AGE    VERSION
master1   NotReady   master   3m9s   v1.14.1
```
查看所有的pod，kubectl get pod --all-namespaces

coredns也依赖于容器网络，此时pending是正常的

```
[root@master1 ~]# kubectl get pod --all-namespaces
NAMESPACE     NAME                              READY   STATUS    RESTARTS   AGE
kube-system   coredns-fb8b8dccf-8wdn8           0/1     Pending   0          2m21s
kube-system   coredns-fb8b8dccf-rsnr6           0/1     Pending   0          2m21s
kube-system   etcd-master1                      1/1     Running   0          89s
kube-system   kube-apiserver-master1            1/1     Running   0          94s
kube-system   kube-controller-manager-master1   1/1     Running   0          89s
kube-system   kube-proxy-9nl4m                  1/1     Running   0          2m21s
kube-system   kube-scheduler-master1            1/1     Running   0          106s

```

配置KUBECONFIG变量

```
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/profile
source /etc/profile
echo $KUBECONFIG    #应该返回/etc/kubernetes/admin.conf
```

### 5. 部署flannel网络

k8s支持多种网络方案，flannel，calico，openvswitch

此处选择flannel。 在熟悉了k8s部署后，可以尝试其他网络方案，我另外一篇1.9部署中有介绍flannel和calico的方案，以及切换时需要的动作。
```
kubectl create -f kube-flannel.yml

网络就绪后，节点的状态会变为ready
[root@master1 ~]# kubectl get node
NAME      STATUS   ROLES    AGE     VERSION
master1   Ready    master   11m     v1.14.1
```

### 6. kubeadm join 加入node节点

#### 6.1 node节点加入集群

使用之前kubeadm init 生产的join命令，加入成功后，回到master节点查看是否成功

```

[root@node1 ~]# kubeadm join 192.168.4.130:6443 --token 911xit.xkp2gfxbvf5wuqz7 \
>     --discovery-token-ca-cert-hash sha256:23db3094dc9ae1335b25692717c40e24b1041975f6a43da9f43568f8d0dbac72 

[root@master1 ~]# kubectl get node
NAME      STATUS   ROLES    AGE     VERSION
master1   Ready    master   12m     v1.14.1
node1     Ready    <none>   9m52s   v1.14.1
```
至此，集群已经部署完成。

#### 6.2 如果出现x509这个报错

此处未更新，沿用1.12

如果有报错才需要做这一步，不然不需要。

这是因为master节点缺少KUBECONFIG变量
```
[discovery] Failed to request cluster info, will try again: [Get https://192.168.1.181:6443/api/v1/namespaces/kube-public/configmaps/cluster-info: x509: certificate has expired or is not yet valid]
```
master节点执行
```
export KUBECONFIG=$HOME/.kube/config
```
node节点kubeadm reset 再join
```
kubeadm reset
kubeadm join  xxx ...
```

#### 6.3 如果忘了join命令，加入节点方法

此处未更新，沿用1.12

若node已经成功加入，忽略这一步。

使用场景：忘了保存上面kubeadm init生产的join命令，可按照下面的方法加入node节点。

首先master节点获取token，如果token list内容为空，则kubeadm token create创建一个，记录下token数据

```
[root@master1 kubernetes1.10]# kubeadm token list
TOKEN                     TTL       EXPIRES                     USAGES                   DESCRIPTION                                                EXTRA GROUPS
wct45y.tq23fogetd7rp3ck   22h       2018-04-26T21:38:57+08:00   authentication,signing   The default bootstrap token generated by 'kubeadm init'.   system:bootstrappers:kubeadm:default-node-token

```

node节点执行如下，把token部分进行替换

```
kubeadm join --token wct45y.tq23fogetd7rp3ck 192.168.1.181:6443 --discovery-token-unsafe-skip-ca-verification
```

### 7. 部署k8s ui界面，dashboard

dashboard是官方的k8s 管理界面，可以查看应用信息及发布应用。dashboard的语言是根据浏览器的语言自己识别的  

官方默认的dashboard为https方式，如果用chrome访问会拒绝。本次部署做了修改，方便使用，使用了http方式，用chrome访问正常。

修改方法可以查看我简书中另一篇文档，修改dashboard 为http方式

一共需要导入3个yaml文件

文件地址 
https://github.com/cai11745/k8s-ocp-yaml/tree/master/yaml-file/dashboard-1.10.1

```
kubectl apply -f kubernetes-dashboard.yaml
kubectl apply -f admin-role.yaml
kubectl apply -f kubernetes-dashboard-admin.rbac.yaml


[root@master1 ~]# kubectl -n kube-system get svc
NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                      AGE
kube-dns               ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP       32m
kubernetes-dashboard   NodePort    10.97.8.30   <none>        443:32001/TCP,80:32000/TCP   13m
```

创建完成后，通过 http://任意节点的IP:32000即可访问ui
不需要输入token，也不需要https


### 8. EFK和监控

方案github可查，监控推荐使用coreos的 prometheus，部署完成后通过grafana的nodeport访问，自带的模板已经满足日常使用。


### 9. FAQ 

##### 9.1 kubectl 命令补全
```
root@master1:/# vim /etc/profilecd   #添加下面这句，再source
source <(kubectl completion bash)
root@master1:/# source /etc/profile
```

##### 9.2 master节点默认不可部署pod

执行如下，node-role.kubernetes.io/master 可以在 kubectl edit node master1中taint配置参数下查到

```
root@master1:/var/lib/kubelet# kubectl taint node master1 node-role.kubernetes.io/master-
node "master1" untainted
```

##### 9.3 node节点pod无法启动/节点删除网络重置

node1之前反复添加过,添加之前需要清除下网络
```
root@master1:/var/lib/kubelet# kubectl get po -o wide
NAME                   READY     STATUS              RESTARTS   AGE       IP           NODE
nginx-8586cf59-6zw9k   1/1       Running             0          9m        10.244.3.3   node2
nginx-8586cf59-jk5pc   0/1       ContainerCreating   0          9m        <none>       node1
nginx-8586cf59-vm9h4   0/1       ContainerCreating   0          9m        <none>       node1
nginx-8586cf59-zjb84   1/1       Running             0          9m        10.244.3.2   node2
```

```
root@node1:~# journalctl -u kubelet
 failed: rpc error: code = Unknown desc = NetworkPlugin cni failed to set up pod "nginx-8586cf59-rm4sh_default" network: failed to set bridge addr: "cni0" already has an IP address different from 10.244.2.1/24
12252 cni.go:227] Error while adding to cni network: failed to set bridge addr: "cni0" already
```

重置kubernetes服务，重置网络。删除网络配置，link

```
kubeadm reset
systemctl stop kubelet
systemctl stop docker
rm -rf /var/lib/cni/
rm -rf /var/lib/kubelet/*
rm -rf /etc/cni/
ifconfig cni0 down
ifconfig flannel.1 down
ifconfig docker0 down
ip link delete cni0
ip link delete flannel.1
systemctl start docker

```

加入节点
systemctl start docker
```
kubeadm join --token 55c2c6.2a4bde1bc73a6562 192.168.1.144:6443 --discovery-token-ca-cert-hash sha256:0fdf8cfc6fecc18fded38649a4d9a81d043bf0e4bf57341239250dcc62d2c832
```


### 参考文档

参考文档为kubernetes官网，若无法访问或者页面显示格式异常，请科学上网

https://kubernetes.io/docs/setup/independent/install-kubeadm/




