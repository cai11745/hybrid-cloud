---
layout: post
title:  centos7.3 kubernetes/k8s 1.10 离线安装
category: kubernetes
description: 
---

本文介绍在centos7.3使用kubeadm快速离线安装kubernetes 1.10。

采用单master，单node（可以多node），占用资源较少，方便在笔记本或学习环境快速部署，不适用于生产环境。

所需文件百度盘连接

链接：https://pan.baidu.com/s/1iQJpKZ9PdFjhz9yTgl0Wjg 密码：gwmh

### 1. 环境准备

准备不低于2台虚机。 1台 master，其余的做node

OS: Centos7.3 mini install。 最小化安装。配置节点IP

|主机名|IP| 配置|
|----|----|----|
|master1|192.168.1.181| 1C 4G|
|node1|192.168.1.182| 2C 6G|

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
192.168.1.181 matser1
192.168.1.182 node1
```
关闭所有节点的seliux以及firewalld
```
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
systemctl disable firewalld
systemctl stop firewalld
```

### 2. 安装docker

使用文件docker-packages.tar，每个节点都要安装。
```
tar -xvf docker-packages.tar
cd docker-packages
rpm -Uvh * 或者 yum install local *.rpm  进行安装
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

使用文件kube-packages-1.10.1.tar，每个节点都要安装

kubeadm是集群部署工具

kubectl是集群管理工具，通过command来管理集群

kubelet的k8s集群每个节点的docker管理服务

```
tar -xvf kube-packages-1.10.1.tar
cd kube-packages-1.10.1
rpm -Uvh * 或者 yum install local *.rpm  进行安装
```

在所有kubernetes节点上设置kubelet使用cgroupfs，与dockerd保持一致，否则kubelet会启动报错

```
默认kubelet使用的cgroup-driver=systemd，改为cgroup-driver=cgroupfs
sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

重设kubelet服务，并重启kubelet服务
systemctl daemon-reload && systemctl restart kubelet
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

使用文件k8s-images-1.10.tar.gz，每个节点都要执行

节点较少，就不搭建镜像仓库服务了，后续要用的应用镜像，每个节点都要导入

```
docker load -i k8s-images-1.10.tar.gz 
一共11个镜像，分别是
k8s.gcr.io/etcd-amd64:3.1.12 
k8s.gcr.io/kube-apiserver-amd64:v1.10.1 
k8s.gcr.io/kube-controller-manager-amd64:v1.10.1 
k8s.gcr.io/kube-proxy-amd64:v1.10.1 
k8s.gcr.io/kube-scheduler-amd64:v1.10.1 
k8s.gcr.io/pause-amd64:3.1 
k8s.gcr.io/k8s-dns-kube-dns-amd64:1.14.8  
k8s.gcr.io/k8s-dns-dnsmasq-nanny-amd64:1.14.8 
k8s.gcr.io/k8s-dns-sidecar-amd64:1.14.8 
k8s.gcr.io/kubernetes-dashboard-amd64:v1.8.3 
quay.io/coreos/flannel:v0.9.1-amd64 
```
### 4. kubeadm init 部署master节点

只在master执行。此处选用最简单快捷的部署方案。etcd、api、controller-manager、 scheduler服务都会以容器的方式运行在master。etcd 为单点，不带证书。etcd的数据会挂载到master节点/var/lib/etcd

init部署是支持etcd 集群和证书模式的，配置方法见我1.9的文档，此处略过。

init命令注意要指定版本，和pod范围

```
kubeadm init --kubernetes-version=v1.10.1 --pod-network-cidr=10.244.0.0/16

Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join 192.168.1.181:6443 --token wct45y.tq23fogetd7rp3ck --discovery-token-ca-cert-hash sha256:c267e2423dba21fdf6fc9c07e3b3fa17884c4f24f0c03f2283a230c70b07772f
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
[root@master1 kubernetes1.10]# kubectl get node
NAME      STATUS     ROLES     AGE       VERSION
master1   NotReady   master    3m        v1.10.1
```
查看所有的pod，kubectl get pod --all-namespaces

kubedns也依赖于容器网络，此时pending是正常的

```
[root@master1 kubernetes1.10]# kubectl get pod --all-namespaces
NAMESPACE     NAME                              READY     STATUS    RESTARTS   AGE
kube-system   etcd-master1                      1/1       Running   0          3m
kube-system   kube-apiserver-master1            1/1       Running   0          3m
kube-system   kube-controller-manager-master1   1/1       Running   0          3m
kube-system   kube-dns-86f4d74b45-5nrb5         0/3       Pending   0          4m
kube-system   kube-proxy-ktxmb                  1/1       Running   0          4m
kube-system   kube-scheduler-master1            1/1       Running   0          3m

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
kubectl apply -f kube-flannel.yml

网络就绪后，节点的状态会变为ready
[root@master1 kubernetes1.10]# kubectl get node
NAME      STATUS    ROLES     AGE       VERSION
master1   Ready     master    18m       v1.10.1
```

### 6. kubeadm join 加入node节点

#### 6.1 node节点加入集群

使用之前kubeadm init 生产的join命令，加入成功后，回到master节点查看是否成功

```
kubeadm join 192.168.1.181:6443 --token wct45y.tq23fogetd7rp3ck --discovery-token-ca-cert-hash sha256:c267e2423dba21fdf6fc9c07e3b3fa17884c4f24f0c03f2283a230c70b07772f

[root@master1 kubernetes1.10]# kubectl get node
NAME      STATUS    ROLES     AGE       VERSION
master1   Ready     master    31m       v1.10.1
node1     Ready     <none>    44s       v1.10.1
```
至此，集群已经部署完成。

#### 6.2 如果出现x509这个报错

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

一共需要导入3个yaml文件

```
kubectl apply -f kubernetes-dashboard-http.yaml
kubectl apply -f admin-role.yaml
kubectl apply -f kubernetes-dashboard-admin.rbac.yaml

[root@master1 kubernetes1.10]# kubectl apply -f kubernetes-dashboard-http.yaml 
serviceaccount "kubernetes-dashboard" created
role.rbac.authorization.k8s.io "kubernetes-dashboard-minimal" created
rolebinding.rbac.authorization.k8s.io "kubernetes-dashboard-minimal" created
deployment.apps "kubernetes-dashboard" created
service "kubernetes-dashboard" created
[root@master1 kubernetes1.10]# kubectl apply -f admin-role.yaml 
clusterrolebinding.rbac.authorization.k8s.io "kubernetes-dashboard" created
[root@master1 kubernetes1.10]# kubectl apply -f kubernetes-dashboard-admin.rbac.yaml 
clusterrolebinding.rbac.authorization.k8s.io "dashboard-admin" created
```

创建完成后，通过 http://任意节点的IP:31000即可访问ui


### 8. EFK和监控

这两部分后续会单独写如何部署。


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




