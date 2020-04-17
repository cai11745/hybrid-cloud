---
layout: post
title:  openshift4 使用方法记录 - 与ocp3差异部分
category: openshift，ocp4, install 
description: 
---

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


### 日志查看




###  参考文档
https://blog.csdn.net/weixin_43902588/article/details/103433143


关注我的github，后续更新会同步到github

https://github.com/cai11745/k8s-ocp-yaml

