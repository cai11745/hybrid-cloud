---
layout: post
title:  kubernetes 1.9 高可用部署
category: kubernetes
description:
---

本文主要介绍部署一个高可用的k8s集群。master三个节点。使用在线环境，能获取国外镜像。  

参考链接： 

https://kubernetes.io/docs/setup/independent/high-availability/  

https://github.com/cookeem/kubeadm-ha/blob/master/README_CN.md  

### install HA etcd https
1. 部署带证书的etcd集群   
见install_k8s  
如果按照官网，etcd证书不要放在/etc/kubernetes/pki下，kubeadm reset会把这个目录清空掉。  

2. 部署单点不带证书etcd

```
export ETCD_VERSION=v3.1.18
curl -sSL https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz | tar -xzv --strip-components=1 -C /usr/local/bin/
rm -rf etcd-$ETCD_VERSION-linux-amd64*

mkdir -p /etc/etcd 
mkdir -p /var/lib/etcd/
useradd etcd
groupadd etcd
chown etcd:etcd -R /var/lib/etcd /etc/etcd
```

```
root@master1:/home/kubernetes# cat /etc/etcd/etcd.conf  |grep -v ^#
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.1.144:2380"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_NAME="infra1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.1.144:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_INITIAL_CLUSTER="infra1=http://192.168.1.144:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
etcserver=WARNING,security=DEBUG
```

```
root@master1:/home/kubernetes# cat /etc/systemd/system/etcd.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
User=etcd
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/local/bin/etcd --name=\"${ETCD_NAME}\" --data-dir=\"${ETCD_DATA_DIR}\" --listen-client-urls=\"${ETCD_LISTEN_CLIENT_URLS}\""
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

```
systemctl start etcd

### install docker，kubeadm，kubectl
同上一篇 kubernetes 1.9 部署 

### install kube master1
kubeadm初始化并删除遗留的网络接口  
```
kubeadm reset
systemctl stop kubelet
systemctl stop docker
rm -rf /var/lib/cni/
rm -rf /var/lib/kubelet/*
rm -rf /etc/cni/

ip a | grep -E 'docker|flannel|cni'  
ip link del docker0
ip link del flannel.1
ip link del cni0

systemctl restart docker && systemctl restart kubelet
ip a | grep -E 'docker|flannel|cni'
```

```
 cat config.yaml 
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
etcd:
  endpoints:
  - http://192.168.1.144:2379
networking:
  podSubnet: 10.244.0.0/16
apiServerCertSANs:
- master1
- master2
- master3
- 192.168.1.144
- 192.168.1.145
- 192.168.1.146
- 192.168.4.130
- 127.0.0.1
token: 7f276c.0741d82a5337f526
tokenTTL: "0"

etcd此处用的单点http，如果要集群https
etcd:
  endpoints:
  - https://<etcd0-ip-address>:2379
  - https://<etcd1-ip-address>:2379
  - https://<etcd2-ip-address>:2379
  caFile: /etc/kubernetes/pki/etcd/ca.pem
  certFile: /etc/kubernetes/pki/etcd/client.pem
  keyFile: /etc/kubernetes/pki/etcd/client-key.pem
podSubnet可以写10.244.0.0/16，与后续网络配置要保持一致
apiServerCertSANs: 填负载三个master主机名，IP。 HA的IP
token可以自己生成，用kubeadm token generate
官网说的api、apiServerExtraArgs 两个参数不要

kubeadm init --config=config.yaml
如果出现etcd版本的报错，后面加上 --ignore-preflight-errors=ExternalEtcdVersion
如果要重置集群，清空etcd

rm -rf /root/.kube
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


vi ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf
source ~/.bashrc
```

### 部署网络 flannel or calico
方法见 kubernetes 1.9 部署  

查看flannel或者calico能否正常启动。  
查看kubedns是否正常，网络正常，kubedns才会正常。  
kube-proxy异常也会导致flannel异常。  


### install kube master2，3
kubeadm初始化并删除遗留的网络接口  
```
kubeadm reset
systemctl stop kubelet
systemctl stop docker
rm -rf /var/lib/cni/
rm -rf /var/lib/kubelet/*
rm -rf /etc/cni/

ip a | grep -E 'docker|flannel|cni'
ip link del docker0
ip link del flannel.1
ip link del cni0

systemctl restart docker && systemctl restart kubelet
ip a | grep -E 'docker|flannel|cni'
```

 config.yaml同上，把advertiseAddress改成本地IP
 从master1 copy CA证书
```
root@master1:/# cd /etc/kubernetes/pki
scp * root@192.168.1.145:/etc/kubernetes/pki/

master2执行  
kubeadm init --config=config.yaml  
完成后提示的join信息应该和master1是一致的  

init如果出错，重做初始化。 和master1时间要同步!  
vi ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf
source ~/.bashrc
```

### 部署haproxy
bind即HA本地端口，后续kube-proxy，kubelet指向api时候需要和这个匹配  
```
apt-get install haproxy
vim /etc/haproxy/haproxy.cfg 增加
frontend  k8s-api
    bind *:16443
    default_backend k8s-api
    mode tcp
    option tcplog

backend k8s-api
    balance source
    mode tcp
    server      master0 192.168.1.144:6443 check
    server      master1 192.168.1.145:6443 check
    server      master2 192.168.1.146:6443 check

systemctl restart haproxy && systemctl enable haproxy
```


### 修改api，及高可用参数
在所有master上增加apiserver的apiserver-count设置  
三个节点依次做，确认正常后下一个，不要一次性做。  
```
 vi /etc/kubernetes/manifests/kube-apiserver.yaml
    - --apiserver-count=3

# 重启服务
 systemctl restart docker && systemctl restart kubelet
```

kube-proxy配置
```
在master01上设置proxy高可用，设置server指向高可用虚拟IP
 kubectl edit -n kube-system configmap/kube-proxy
        server: https://192.168.4.130:6443
在master上重启proxy
 kubectl get pods --all-namespaces -o wide | grep proxy

 kubectl delete pod -n kube-system kube-proxy-XXX
```

### node节点join
使用上面init返回的join参数  
如果没了，在master   
```
root@master1:/etc/kubernetes# kubeadm token list
TOKEN                     TTL         EXPIRES   USAGES                   DESCRIPTION                                                EXTRA GROUPS
7f276c.0741d82a5337f526

node执行
kubeadm join --token 7f276c.0741d82a5337f526 192.168.1.144:6443 --discovery-token-unsafe-skip-ca-verification

回到master 执行kubectl get node
如果没有新加节点，get csr里有，Approved,Issued
检查node节点kubelet服务。
journalctl --no-pager -u kubelet
```

加入成功后，修改kubernetes集群设置，更改server为高可用虚拟IP，端口  
vim /etc/kubernetes/bootstrap-kubelet.conf  
vim /etc/kubernetes/kubelet.conf  
https://192.168.4.130:6443  

