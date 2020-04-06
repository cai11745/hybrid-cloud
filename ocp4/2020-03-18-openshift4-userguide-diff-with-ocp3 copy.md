---
layout: post
title:  openshift4 node not ready debug
category: openshift4，not ready
description: 
---

我的openshift4.3 环境安装在自己的台式电脑上，今天断电重启后，节点有点异常，出现了好几个节点not ready，我尝试把master2重启一下，发现master2节点上面api进程都没有了。

operatorhub测试到一半，干不下去了，先解决问题，顺便缕缕新版本的组件是怎么运作的。

这是开始的情况，就一个节点好使，别的都异常了
```bash
[root@bastion ocp4]# oc get node
NAME       STATUS     ROLES    AGE   VERSION
master-0   NotReady   master   23d   v1.16.2
master-1   Ready      master   23d   v1.16.2
master-2   NotReady   master   23d   v1.16.2
worker-0   NotReady   worker   23d   v1.16.2
worker-1   NotReady   worker   23d   v1.16.2
```

我把master-0 master-2 worker-0 重启后，etcd 已经不工作了，在master0/2 两个节点找不到etcd进程
```bash
[root@bastion ~]# oc get  node
Error from server: etcdserver: request timed out
```

按照ocp3.x的思路，这种情况应该是查 openshift-node 也就是 kubelet 服务  
进入到master-0节点

```bash
# 进入master-0
[root@bastion ~]# ssh root@master-0
# 先看kubelet服务，状态正常
[core@master-0 manifests]$ systemctl status kubelet -l 

# 那么先查etcd，再去看api。发现没有etcd进程，systemctl里面也找不到etcd
[core@master-0 manifests]$ ps -ef |grep etcd
core      1684 24975  0 16:55 pts/0    00:00:00 grep --color=auto etcd 

[core@master-0 manifests]$ systemctl |grep etcd

# /etc/kubernetes/manifests 这里找到了etcd，也就是说通过kubelet来启动的
[core@master-0 manifests]$ pwd
/etc/kubernetes/manifests
[core@master-0 manifests]$ ls 
etcd-member.yaml  kube-apiserver-pod.yaml  kube-controller-manager-pod.yaml  kube-scheduler-pod.yaml

# kubelet的日志里找etcd，无法调度，这是因为我之前改了master节点的调度

[core@master-0 manifests]$ journalctl -b -f -u kubelet.service |grep etcd 
Apr 05 16:59:11 master-0 hyperkube[27660]: I0405 15:49:49.391418       1 factory.go:545] Unable to schedule openshift-machine-config-operator/etcd-quorum-guard-7ccfdfd464-l6d7j: no fit: 0/5 nodes are available: 1 node(s) didn't match pod affinity/anti-affinity, 1 node(s) didn't satisfy existing pods anti-affinity rules, 2 node(s) didn't match node selector, 2 node(s) had taints that the pod didn't tolerate.; waiting






```





openshift4 与 openshift3.x 在部署、运维、操作层面有不少的差异，本篇主要用于记录在运维及操作层面的差异，部署差异见另外一篇openshift4.3 部署文档。


### 平台管理

#### console 登录用户密码
在bastion 部署机上，install.config 所在路径有个auth目录，下面有kubeadmin-password文件， 或者直接搜这个文件 kubeadmin-password ，密码在里面  
用户名是 kubeadmin

#### oc 命令操作集群
认证文件在这 auth/kubeconfig

```bash
mkdir ~/.kube
cp  auth/kubeconfig ~/.kube/config
oc get node

# 其他节点把这个配置文件拿去，装上 oc client 也可以操作集群
# 也可以用 --config 命令指定配置文件
oc --config ./ocp4/auth/kubeconfig get node
```

#### 从部署机ssh到其他RHCOS节点

用户名是core，节点用主机名
```bash
ssh core@master-0 
```

#### 从其他节点ssh到RHCOS节点
比如要从自己的win或者个人电脑直接ssh到master或者worker节点

先从部署机上把ssh私钥拿下来 /root/.ssh/id_rsa

在自己的终端工具或者命令行使用私钥，注意用户名是 core

```bash
[C:\Users\feng\Desktop]$ ssh -i id_rsa core@192.168.2.16

```

#### master 节点禁用调度
刚部署完，master 节点 ROLES 也带了worker，会导致容器调度到上面，把他去掉

```bash
 # oc edit scheduler
...
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  creationTimestamp: null
  name: cluster
spec:
  mastersSchedulable: false >>> Change this to false
  policy:
    name: ""
status: {}
```

原因： 
With Openshift 4.2 cluster masters are marked schedulable if the cluster is configured with only masters and workers are marked '0' in the install-config.

So, in that case, to allow pods to be scheduled on the cluster, masters should be marked scheduable,

To disable this, you can edit the custom resource named 'Scheduler',

```bash
可以看下install-config 中worker是不是0
oc get cm cluster-config-v1 -n kube-system -o yaml
oc get scheduler cluster -o yaml
```

#### 


### 问题记录
#### 经常出现节点 not ready

```bash
[root@bastion ~]# oc get node
NAME       STATUS     ROLES           AGE   VERSION
master-0   NotReady   master,worker   23d   v1.16.2
master-1   Ready      master,worker   23d   v1.16.2
master-2   NotReady   master,worker   23d   v1.16.2
worker-0   NotReady   worker          23d   v1.16.2
worker-1   NotReady   worker          23d   v1.16.2

```

###  参考文档
https://blog.csdn.net/weixin_43902588/article/details/103433143


关注我的github，后续更新会同步到github

https://github.com/cai11745/k8s-ocp-yaml

