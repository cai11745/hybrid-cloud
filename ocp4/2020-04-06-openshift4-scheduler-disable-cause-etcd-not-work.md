---
layout: post
title:  openshift4 禁用调度引发的血案
category: openshift4，not ready
description: 
---

我的openshift4.3 环境安装在自己的台式电脑上，今天断电重启后，节点有点异常，出现了好几个节点not ready，我尝试把master2重启一下，发现master2节点上面api进程都没有了。

我把master-0 master-2 worker-0 重启后，etcd 已经不工作了，在master0/2 两个节点找不到etcd进程

连不上api，看报错连etcd都挂了
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

