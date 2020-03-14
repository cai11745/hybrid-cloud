---
layout: post
title:  prometheus2-组件介绍与数据来源
category: kubernetes, prometheus
description: 
---

上一篇介绍了prometheus operator的安装部署及如何监控ingress controller。

本篇将介绍prometheus部署完成后，每个组件的功能，在整个监控组件中承担什么角色。以及数据来源，节点、容器、kube组件的监控数据来源，这样有助于我们在异常情况下能够快速定位问题，比如无法获取节点数据、kube组件状态等。

### 各组件角色与功能

从整体架构看，prometheus 一共四大组件。 exporter 通过接口暴露监控数据， prometheus-server 采集并存储数据， grafana 通过prometheus-server查询并友好展示数据， alertmanager 处理告警，对外发送。

从部署看，pod 一共有 alertmanager-main, grafana, kube-state-metrics, node-exporter, prometheus-adapter, prometheus-k8s, prometheus-operator，以下
分别介绍各组件功能。

```bash
[root@k8s ~]# kubectl -n monitoring get pod 
NAME                                  READY   STATUS    RESTARTS   AGE
alertmanager-main-0                   2/2     Running   0          53s
alertmanager-main-1                   2/2     Running   0          55s
alertmanager-main-2                   2/2     Running   0          51s
grafana-58dc7468d7-2v8mg              1/1     Running   0          61s
kube-state-metrics-769f4fd4d5-vf4vg   3/3     Running   0          61s
node-exporter-6h7qm                   2/2     Running   0          52s
prometheus-adapter-5cd5798d96-8ck8k   1/1     Running   0          61s
prometheus-k8s-0                      3/3     Running   1          54s
prometheus-k8s-1                      3/3     Running   1          51s
prometheus-operator-99dccdc56-mmvq9   1/1     Running   0          61s
```

#### prometheus-operator
prometheus-operator 服务是deployment方式部署，他是整个基础组件的核心，他监控我们自定义的 prometheus 和alertmanager，并生成对应的 statefulset。 就是prometheus和alertmanager服务是通过他部署出来的。

```bash
[root@k8s ~]# kubectl -n monitoring get deploy prometheus-operator
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
prometheus-operator   1/1     1            1           13d
```

#### prometheus-k8s
prometheus-server 获取各端点数据并存储与本地，创建方式为自定义资源 crd中的prometheus。 创建自定义资源prometheus后，会启动一个statefulset，即prometheus-server

```bash
[root@k8s ~]# kubectl -n monitoring get prometheus
NAME   AGE
k8s    13d

prometheus-k8s 这个statefulset即对应上面get prometheus中的 k8s。
所以如果想要删除prometheus-server，只删除statefulset是没用的，会再次被重建，需要删除prometheus这个资源对象里的内容kubectl delete prometheus k8s
[root@k8s ~]# kubectl -n monitoring get statefulset
NAME                READY   AGE
alertmanager-main   3/3     13d
prometheus-k8s      2/2     13d
```

prometheus-server 默认情况下没有配置数据持久化。

#### node-exporter
node-exporter 提供每个node节点的监控数据，以daemonset方式运行，保证每个节点运行一个pod。 pod网络是hostnetwork方式.

```bash
[root@k8s ~]# kubectl -n monitoring get daemonset
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
node-exporter   1         1         1       1            1           kubernetes.io/os=linux   13d
```

#### kube-state-metrics



#### prometheus-adapter



#### grafana
grafana是数据展示的面板. deployment方式部署。

```bash
[root@k8s ~]# kubectl -n monitoring get deploy grafana
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
grafana   1/1     1            1           13d
```

#### alertmanager-main
alertmanager-main服务和prometheus-server类似，也是通过自定义资源创建出来的。
自定义资源格式叫alertmanager

```bash
[root@k8s ~]# kubectl -n monitoring get alertmanager
NAME   AGE
main   13d

[root@k8s ~]# kubectl -n monitoring get statefulset
NAME                READY   AGE
alertmanager-main   3/3     13d
prometheus-k8s      2/2     6m3s
```

### 五大自定义资源对象




### prometheus server 数据来源










**本文全文及见github，欢迎点点小星星**
https://github.com/cai11745/k8s-ocp-yaml/blob/master/prometheus/2019-10-22-prometheus-1-install-and-metricsIngress.md

参考内容：
https://yunlzheng.gitbook.io/prometheus-book/
https://github.com/kubernetes/ingress-nginx/tree/master/deploy
https://www.jianshu.com/p/2c899452ab5a
