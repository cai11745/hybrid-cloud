---
layout: post
title:  k8s metrics-server 轻量化监控
category: kubernetes, metrics-server
description: 
---

metrics-server 是用来取代heapster，负责从kubelet中采集数据， 并通过Metrics API在Kubernetes Apiserver中暴露它们。

metrics-server 采集node 和pod 的cpu/mem，数据存在容器本地，不做持久化。这些数据的使用场景有 kubectl top 和scheduler 调度、hpa 弹性伸缩，以及原生的dashboard 监控数据展示。

**metrics-server 和prometheus 没有半毛钱关系。 也没有任何数据或者接口互相依赖关系。**

prometheus 能力更强，也更重，拥有更多的监控指标以及自定义监控指标，可以配合grafana 面板更好的展示数据，配合alertmanager 实现告警。介绍见之前内容  
https://github.com/cai11745/k8s-ocp-yaml/blob/master/prometheus/2019-10-22-prometheus-1-install-and-metricsIngress.md

metrics-server 指标少，但是更轻量，适用于简单场景的容器与节点数据监控。

### 安装 metrics-server
官网 https://github.com/kubernetes-sigs/metrics-server

修改下镜像地址，默认的k8s.grc.io 国内拉取不到，换成阿里云  
registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server-amd64:v0.3.6  
```bash
[root@master ~]# wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml        
[root@master ~]# vim components.yaml 
# 修改image
# registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server-amd64:v0.3.6   
[root@master ~]# kubectl apply -f components.yaml 
```

使用kubectl top 查看pod 和node 的资源使用情况，获取不到数据
```bash
[root@master ~]# kubectl top node        
error: metrics not available yet
[root@master ~]# kubectl top pod
W0414 13:34:35.193688   13720 top_pod.go:266] Metrics not available for pod default/centos-758b7556f5-542wl, age: 299h19m20.193680607s
error: Metrics not available for pod default/centos-758b7556f5-542wl, age: 299h19m20.193680607s
```

查看metrics-server pod 日志
```bash
[root@master ~]# kubectl -n kube-system logs metrics-server-58c885686f-nlp25 
...
E0414 05:34:32.752194       1 reststorage.go:135] unable to fetch node metrics for node "node1": no metrics known for node
E0414 05:34:32.752208       1 reststorage.go:135] unable to fetch node metrics for node "master": no metrics known for node
E0414 05:34:35.186237       1 reststorage.go:160] unable to fetch pod metrics for pod default/tomtest-86f7667d85-hxnzl: no metrics known for pod
E0414 05:34:35.186247       1 reststorage.go:160] unable to fetch pod metrics for pod default/centos-758b7556f5-542wl: no metrics known for pod
```

提示 无法解析节点的主机名，是metrics-server 这个容器不能通过CoreDNS 解析各Node的主机名，metrics-server 连节点时默认是连接节点的主机名，需要加个参数，让它连接节点的IP，而不是使用主机名：
          - --kubelet-insecure-tls
          - --kubelet-preferred-address-types=InternalIP

修改yaml 文件，增加这两行
```bash
        image: k8s.gcr.io/metrics-server-amd64:v0.3.6
        imagePullPolicy: IfNotPresent
        args:
          - --cert-dir=/tmp
          - --secure-port=4443
          - --kubelet-insecure-tls
          - --kubelet-preferred-address-types=InternalIP
```

导入文件，过一会就正常了
```bash
[root@master ~]# kubectl apply -f components.yaml 

[root@master ~]# kubectl top node                     
NAME     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
master   101m         5%     971Mi           17%       
node1    72m          1%     914Mi           3%        
[root@master ~]# kubectl top pod --all-namespaces
NAMESPACE       NAME                                       CPU(cores)   MEMORY(bytes)   
ingress-nginx   nginx-ingress-controller-c8848f54b-z2fwd   4m           181Mi           
kube-system     calico-kube-controllers-77c4b7448-n92dt    1m           14Mi            
kube-system     calico-node-nqltv                          12m          53Mi            
kube-system     calico-node-rf9gh                          10m          49Mi            
kube-system     coredns-6955765f44-579bp                   2m           13Mi            
kube-system     coredns-6955765f44-7h4vh                   1m           13Mi            
kube-system     etcd-master                                12m          108Mi           
kube-system     kube-apiserver-master                      19m          336Mi           
kube-system     kube-controller-manager-master             5m           42Mi            
kube-system     kube-proxy-24k9w                           1m           22Mi            
kube-system     kube-proxy-w48qf                           1m           17Mi            
kube-system     kube-scheduler-master                      2m           18Mi            
kube-system     metrics-server-6ffdb54684-lg77c            1m           14Mi  
```

### 接口测试
metrics-server 将node 和pod 的监控数据通过k8s 标准api 暴露出来。

```bash
All endpoints are GET endpoints, rooted at /apis/metrics/v1alpha1/. There won't be support for the other REST methods.

The list of supported endpoints:

/nodes - all node metrics; type []NodeMetrics
/nodes/{node} - metrics for a specified node; type NodeMetrics
/namespaces/{namespace}/pods - all pod metrics within namespace with support for all-namespaces; type []PodMetrics
/namespaces/{namespace}/pods/{pod} - metrics for a specified pod; type PodMetrics
The following query parameters are supported:

labelSelector - restrict the list of returned objects by labels (list endpoints only)
```

通过kubectl proxy 命令暴露api 端口，默认8080，非加密端口。如果端口被用了就加上-p 参数指定一个端口

```bash
kubectl proxy -p 8002

# 再开一个终端，测试访问
[root@master ~]# kubectl api-resources |grep metrics                        
nodes                                          metrics.k8s.io                 false        NodeMetrics
pods                                           metrics.k8s.io                 true         PodMetrics

[root@master ~]# curl 127.0.0.1:8002/ |grep metrics
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  4963    0  4963    0     0  4822k      0 --:--:-- --:--:-- --:--:-- 4846k
    "/apis/metrics.k8s.io",
    "/apis/metrics.k8s.io/v1beta1",
    "/metrics",

# 获取所有node    
[root@master ~]# curl 127.0.0.1:8002/apis/metrics.k8s.io/v1beta1/nodes

# 某个pod
[root@master ~]# curl 127.0.0.1:8002/apis/metrics.k8s.io/v1beta1/namespaces/kube-system/pods/kube-apiserver-master
{
  "kind": "PodMetrics",
  "apiVersion": "metrics.k8s.io/v1beta1",
  "metadata": {
    "name": "kube-apiserver-master",
    "namespace": "kube-system",
    "selfLink": "/apis/metrics.k8s.io/v1beta1/namespaces/kube-system/pods/kube-apiserver-master",
    "creationTimestamp": "2020-04-14T15:25:04Z"
  },
  "timestamp": "2020-04-14T15:24:10Z",
  "window": "30s",
  "containers": [
    {
      "name": "kube-apiserver",
      "usage": {
        "cpu": "19383740n",
        "memory": "344704Ki"
      }
    }
  ]
```