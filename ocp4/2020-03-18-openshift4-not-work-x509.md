---
layout: post
title:  openshift4 not work x509
category: openshift4，x509
description: 
---

这套 openshift4 的环境搭建在家里的台式电脑上，当我需要 k8s 集群的时候，会把这套ocp 先关闭。 当我再次开启时，发现集群异常了。无法 oc et node。   
记录下本次的排查，顺便也梳理下，ocp4 在集群的日志、组件状态和ocp3 的一些差异。


### 异常现象： cant't get node x509


```bash
[root@bastion ~]# oc get node
Unable to connect to the server: x509: certificate has expired or is not yet valid
```



### 


