---
layout: post
title:  openshift4 使用方法记录 - 与ocp3差异部分
category: openshift，ocp4, userguide
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

在 worker 节点操作有些命令需要加 sudo 

#### 


### 服务状态查看

kubelet 是二进制部署，三大组件 apiserver controller-manager scheduler 以及etcd，都是静态容器，在 /etc/kubernetes/manifests/ 下，通过 kubelet 直接拉起来的。

所以若 etcd apiserver 异常，第一步先要确定 kubelet 正常工作。

#### kubelet 服务状态与日志

```bash
# 服务状态
systemctl status kubelet -l

# 服务详细日志

journalctl --no-pager -f -u kubelet
```

#### 查看运行的容器

使用命令 crictl ，参数和 docker 类似，要加 sudo  
可以在worker 节点上直接查看 pod 状态与 pod 日志

```bash
# 查看所有容器
sudo crictl ps
# 查看所有pod，ready 和 not ready 的都能查看
sudo crictl pods
# 查看 pod 日志
sudo crictl logs etcd-member-master-0 
# 查看所有 image ，可是为什么只有ID，name 和 tag 不显示
sudo crictl images
IMAGE               TAG                 IMAGE ID            SIZE
<none>              <none>              493f2db8b5178       728MB
<none>              <none>              fa4b1c816921a       251MB

```


#### 查看 etcd 状态

这是自带的 etcd 脚本，不过缺少了查看集群状态的脚本，etcdctl 默认也没有带，需要手动获取  
```bash
[core@master-1 manifests]$ etcd-
etcd-member-add.sh        etcd-member-remove.sh     etcd-snapshot-restore.sh  
etcd-member-recover.sh    etcd-snapshot-backup.sh   
```

上面的几个脚本都用到了这个  
/usr/local/bin/openshift-recovery-tools

这里面写了很多脚本，包括如何获取 etcdctl， 及 etcdctl 连接需要的证书如何获取，就是拿 apiserver 的，因为 apiserver 需要写入 etcd

etcdimg 地址是quay.io 没错，因为做了 mirror ，会把 quay.io/openshift-release-dev/ocp-v4.0-art-dev 转到 registry.example.com:5000/ocp4/openshift4 ，配置内容在  /etc/containers/registries.conf

**先获取etcdctl**

openshift-recovery-tools 脚本里 dl_etcdctl() 下载 etcdctl ，我们把他拿出来单独执行

```bash
etcdimg="quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:bc97106373ffddb5b7afe2a9010de54098c95545a654c7990b882680528c29e3"
etcdctr=$(podman create "${etcdimg}")
etcdmnt=$(podman mount "${etcdctr}")
cp ${etcdmnt}/bin/etcdctl ./bin
umount "${etcdmnt}"
podman rm "${etcdctr}"
./bin/etcdctl version
```







###  参考文档
https://blog.csdn.net/weixin_43902588/article/details/103433143


关注我的github，后续更新会同步到github

https://github.com/cai11745/k8s-ocp-yaml

