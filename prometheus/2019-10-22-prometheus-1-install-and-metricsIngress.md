---
layout: post
title:  prometheus监控应用于容器云平台
category: kubernetes, prometheus
description: 
---


prometheus 当前已经成为k8s的主流监控方案。具备集群资源监控、服务监控、告警与一体，具备较强的扩展性与集成能力。

扩展性：可以通过多个prometheus 采集多个不同区域的数据，使用联邦集群技术在一个prometheus上进行汇聚与展示。

集成能力：目前支持： Java， JMX， Python， Go，Ruby， .Net， Node.js等等语言的客户端SDK，基于这些SDK可以快速让应用程序纳入到Prometheus的监控当中，或者开发自己的监控数据收集程序。

我们常用于k8s的prometheus并不单单只有这一组件
export: 采集client数据并暴露，因为prometheus服务端是采取的pull方式主动获取数据
prometheus：定期从数据源拉取数据，然后将数据持久化到磁盘
grafana：展示面板，将prometheus中的数据通过面板图形化更友好的方式展示
alertmanager: 告警配置

**架构图**
![prometheus-all](../image/prometheus-all.png)
### 安装部署

k8s：1.14
使用coreos的版本，包含了整套高可用方案

```bash
# 里面包含了prometheus大全套，kubernetes组件收集指标，grafana常用面板, prometheus operator 
git clone https://github.com/coreos/kube-prometheus.git
cd kube-prometheus/
# 创建namespace和CRD，要等他们就绪后，才能继续后面的。until 那句返回空信息，不报错，就可以执行下一步了
kubectl create -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl create -f manifests/
# 看下所有pod，都正常，prometheus就部署好了。当前prometheus 和grafana都是没有挂载持久化存储的，若长期使用需配置存储。
kubectl -n monitoring get po

[root@master1 kube-prometheus]# kubectl -n monitoring get po
NAME                                   READY   STATUS    RESTARTS   AGE
alertmanager-main-0                    2/2     Running   0          22h
alertmanager-main-1                    2/2     Running   0          22h
alertmanager-main-2                    2/2     Running   0          22h
grafana-6bf77bc85f-vx6rg               1/1     Running   0          22h
kube-state-metrics-5c9bd5465b-7jxl8    3/3     Running   0          22h
node-exporter-lrzsj                    2/2     Running   0          22h
node-exporter-p9pjp                    2/2     Running   0          22h
prometheus-adapter-8667948d79-lwmjz    1/1     Running   0          22h
prometheus-k8s-0                       3/3     Running   1          22h
prometheus-k8s-1                       3/3     Running   1          22h
prometheus-operator-579b9fdc44-jjd7f   1/1     Running   0          22h
```

### 配置访问页面

修改service为nodeport，就可以从外部访问了

```bash
# 编辑三个service，把   type: ClusterIP 改为   type: NodePort 
# 也可以再手动指定nodeport端口
kubectl -n monitoring edit svc grafana
kubectl -n monitoring edit svc prometheus-k8s
kubectl -n monitoring edit svc alertmanager-main

kubectl -n monitoring get svc grafana prometheus-k8s alertmanager-main

[root@master1 kube-prometheus]# kubectl -n monitoring get svc grafana prometheus-k8s alertmanager-main
NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
grafana             NodePort   10.101.251.76   <none>        3000:32664/TCP   22h
NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
prometheus-k8s      NodePort   10.96.18.46     <none>        9090:31970/TCP   22h
NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
alertmanager-main   NodePort   10.103.41.177   <none>        9093:32113/TCP   22h
```

任意k8s节点IP:32664 即可访问grafana，其他同理

grafana 初始用户密码 admin/admin

内置了很多默认面板
![grafana-all-dashboard](../image/grafana-all-dashboard.png)

集群信息面板
![grafana-cluster](../image/grafana-cluster.png)

prometheus 页面
![prometheus-dashboard](../image/prometheus-dashboard.png)

### 监控Ingress controller

Ingress controller 作为整个集群流量的入口，有必要对他的流量做一定监控与展示







