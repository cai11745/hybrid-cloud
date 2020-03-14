---
layout: post
title:  centos7.6 kubernetes/k8s 1.17在线安装
category: kubernetes
description: 
---

记录自己esxi虚拟化环境部署，1master 1node 
操作系统： Centos 7.6 mini install
kubernetes： 1.17

### 环境准备

|主机名|IP| 配置|
|----|----|----|
|master|192.168.2.31| 2C 8G|
|node1|192.168.2.32| 6C 24G|
设置主机名为master/node1  时区
```
timedatectl set-timezone Asia/Shanghai  #都要执行
hostnamectl set-hostname master  #第一台
hostnamectl set-hostname node1   #第二台
```
在/etc/hosts中添加解析
```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.2.31 master
192.168.2.32 node1
```
关闭seliux以及firewalld
```
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
systemctl disable firewalld
systemctl stop firewalld
```

### 安装docker

使用阿里yum源

```
yum install -y yum-utils \
device-mapper-persistent-data \
lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce-18.09.7 docker-ce-cli-18.09.7 containerd.io

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

### 安装kubeadm，kubectl，kubelet

使用国内源
```bash
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```
```bash
yum install -y kubelet-1.17.3 kubeadm-1.17.3 kubectl-1.17.3
```
kubeadm是集群部署工具

kubectl是集群管理工具，通过command来管理集群

kubelet的k8s集群每个节点的docker管理服务，设置为开机自启动  

```bash
 systemctl enable kubelet
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
net.ipv4.ip_forward = 1
EOF
sysctl --system
```

### 拉取镜像

查看部署需要的镜像

```bash
kubeadm config images list

k8s.gcr.io/kube-apiserver:v1.17.3
k8s.gcr.io/kube-controller-manager:v1.17.3
k8s.gcr.io/kube-scheduler:v1.17.3
k8s.gcr.io/kube-proxy:v1.17.3
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd:3.4.3-0
k8s.gcr.io/coredns:1.6.5

```

根据需要的版本，直接拉取国内镜像，并修改tag，每台都跑一下脚本，node可以不要apiserver，controller，scheduler,etcd这几个

```bash
# vim kubeadm.sh

#!/bin/bash

## 使用如下脚本下载国内镜像，并修改tag为google的tag
set -e

KUBE_VERSION=v1.17.3
KUBE_PAUSE_VERSION=3.1
ETCD_VERSION=3.4.3-0
CORE_DNS_VERSION=1.6.5

GCR_URL=k8s.gcr.io
ALIYUN_URL=registry.cn-hangzhou.aliyuncs.com/google_containers

images=(kube-proxy:${KUBE_VERSION}
kube-scheduler:${KUBE_VERSION}
kube-controller-manager:${KUBE_VERSION}
kube-apiserver:${KUBE_VERSION}
pause:${KUBE_PAUSE_VERSION}
etcd:${ETCD_VERSION}
coredns:${CORE_DNS_VERSION})

for imageName in ${images[@]} ; do
  docker pull $ALIYUN_URL/$imageName
  docker tag  $ALIYUN_URL/$imageName $GCR_URL/$imageName
  docker rmi $ALIYUN_URL/$imageName
done
```

运行脚本，拉取镜像

```bash
sh ./kubeadm.sh
```

### kubeadm init 部署master节点

只在master执行。此处选用最简单快捷的部署方案。etcd、api、controller-manager、 scheduler服务都会以容器的方式运行在master。etcd 为单点，不带证书。etcd的数据会挂载到master节点/var/lib/etcd

init命令注意要指定版本，和pod范围

```
kubeadm init --kubernetes-version=v1.17.3 --pod-network-cidr=10.244.0.0/16
```

执行提示的命令，保存kubeconfig
```
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

此时执行kubectl get node 已经可以看到master节点，notready是因为还未部署网络插件

查看所有的pod，kubectl get pod --all-namespaces

coredns也依赖于容器网络，此时pending是正常的

配置KUBECONFIG变量

```bash
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/profile
source /etc/profile
echo $KUBECONFIG    #应该返回/etc/kubernetes/admin.conf
```
master节点默认不可部署pod

执行如下，node-role.kubernetes.io/master 可以在 kubectl edit node master1中taint配置参数下查到

```
root@master1:/var/lib/kubelet# kubectl taint node k8s node-role.kubernetes.io/master-
node "k8s" untainted
```
### kubeadm join 加入计算节点
node节点执行master 节点kubeadm init 之后的提示信息

```bash
kubeadm join 192.168.2.31:6443 --token 2pfhoi.vxundi9v57xg7bad \
>     --discovery-token-ca-cert-hash sha256:8dc8647fcbc96b5e2ec2c952c285c08402fe4aabcfa97ec87cf0d77d768ba888 
```

完成后，在master 执行 kubectl get node 查看节点

```bash
[root@master ~]# kubectl get node                                          
NAME     STATUS     ROLES    AGE     VERSION
master   NotReady   master   2m50s   v1.17.3
node1    NotReady   <none>   18s     v1.17.3
```

### 部署calico网络

k8s支持多种网络方案，flannel，calico，openvswitch

此处选择calico
```
wget https://docs.projectcalico.org/v3.12/manifests/calico.yaml

修改 CALICO_IPV4POOL_CIDR 的IP段和上面kubeadm init 一致
10.244.0.0/16

kubectl create -f calico.yaml

网络就绪后，节点的状态会变为ready
[root@master ~]# kubectl get node
NAME     STATUS   ROLES    AGE   VERSION
master   Ready    master   10h   v1.17.3
node1    Ready    <none>   10h   v1.17.3

```

### 部署k8s ui界面，dashboard

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
#### 镜像加速器，相应域名替换掉即可

dockerhub(docker.io) 
dockerhub.azk8s.cn
dockerhub.azk8s.cn/<repo-name>/<image-name>:<version>
dockerhub.azk8s.cn/microsoft/azure-cli:2.0.61dockerhub.azk8s.cn/library/nginx:1.15

gcr.io 
gcr.azk8s.cn
gcr.azk8s.cn/<repo-name>/<image-name>:<version>
gcr.azk8s.cn/google_containers/hyperkube-amd64:v1.13.5

quay.io 
quay.azk8s.cn
quay.azk8s.cn/<repo-name>/<image-name>:<version>
quay.azk8s.cn/deis/go-dev:v1.10.0

### 参考文档
https://kubernetes.io/docs/setup/independent/install-kubeadm/
https://www.cnblogs.com/xingyys/p/11594189.html




