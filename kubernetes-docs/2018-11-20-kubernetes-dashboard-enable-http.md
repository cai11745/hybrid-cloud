---
layout: post
title:  kubernetes 1.9 在线部署
category: kubernetes
---

本文主要介绍通过在线方式kubeadm部署kubernetes1.9. 部署环境需要能够拉去google镜像

主要内容：

1. kubeadm init 自定义etcd环境，支持etcd证书模式

2. kubeadm join的异常解决

3. 两种网络部署方式，flannel与calico

4. dashboard的https与http两种部署方式。

5. 部署EFK、监控、ingress
  
### install docker/kubeadm

https://kubernetes.io/docs/setup/independent/install-kubeadm/

在所有kubernetes节点上设置kubelet使用cgroupfs，与dockerd保持一致，否则kubelet会启动报错

```
docker配置
cat << EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=cgroupfs"]
}
EOF
systemctl daemon-reload && systemctl restart docker

默认kubelet使用的cgroup-driver=systemd，改为cgroup-driver=cgroupfs
vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=systemd"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"

重设kubelet服务，并重启kubelet服务
systemctl daemon-reload && systemctl restart kubelet
```

关闭swap
```
swapoff -a
vim /etc/fstab  #swap一行注释掉
```

### master节点 kubeadm init 方法1

初始化集群，也会起一个etcd的pod
```
kubeadm init --pod-network-cidr=10.244.0.0/16
```

### master节点 kubeadm init 方法2

通过配置文件init

配置文件大全见官方

https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#config-file

install etcd

1. 准备证书

https://www.kubernetes.org.cn/3096.html

在master1需要安装CFSSL工具，这将会用来建立 TLS certificates。
```
export CFSSL_URL="https://pkg.cfssl.org/R1.2"
wget "${CFSSL_URL}/cfssl_linux-amd64" -O /usr/local/bin/cfssl
wget "${CFSSL_URL}/cfssljson_linux-amd64" -O /usr/local/bin/cfssljson
chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson
```

创建集群 CA 与 Certificates

在这部分，将会需要产生 client 与 server 的各组件 certificates，并且替 Kubernetes admin user 产生 client 证书。

建立/etc/etcd/ssl文件夹，然后进入目录完成以下操作。
```
 mkdir -p /etc/etcd/ssl && cd /etc/etcd/ssl
 export PKI_URL="https://kairen.github.io/files/manual-v1.8/pki"
 ```

下载ca-config.json与etcd-ca-csr.json文件，并产生 CA 密钥：
```
wget "${PKI_URL}/ca-config.json" "${PKI_URL}/etcd-ca-csr.json"
cfssl gencert -initca etcd-ca-csr.json | cfssljson -bare etcd-ca
ls etcd-ca*.pem
etcd-ca-key.pem  etcd-ca.pem
```

下载etcd-csr.json文件，并产生 kube-apiserver certificate 证书：
```
wget "${PKI_URL}/etcd-csr.json"   #修改IP为本地，如果是集群，每个节点IP都要添加进去
cfssl gencert \
  -ca=etcd-ca.pem \
  -ca-key=etcd-ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  etcd-csr.json | cfssljson -bare etcd

ls etcd*.pem
etcd-ca-key.pem  etcd-ca.pem  etcd-key.pem  etcd.pe
```

若节点 IP 不同，需要修改etcd-csr.json的hosts。

完成后删除不必要文件： ` rm -rf *.json`

确认/etc/etcd/ssl有以下文件：
```
ls /etc/etcd/ssl
etcd-ca.csr  etcd-ca-key.pem  etcd-ca.pem  etcd.csr  etcd-key.pem  etcd.pem
```

2. Etcd 安装与设定

首先在master1节点下载 Etcd，并解压缩放到 /opt 底下与安装：

```
export ETCD_URL="https://github.com/coreos/etcd/releases/download"
cd && wget -qO- --show-progress "${ETCD_URL}/v3.2.9/etcd-v3.2.9-linux-amd64.tar.gz" | tar -zx
mv etcd-v3.2.9-linux-amd64/etcd* /usr/local/bin/ && rm -rf etcd-v3.2.9-linux-amd64
```

完成后新建 Etcd Group 与 User，并建立 Etcd 配置文件目录：
```
groupadd etcd && useradd -c "Etcd user" -g etcd -s /sbin/nologin -r etcd
```

下载etcd相关文件，我们将来管理 Etcd：
```
export ETCD_CONF_URL="https://kairen.github.io/files/manual-v1.8/master"
wget "${ETCD_CONF_URL}/etcd.conf" -O /etc/etcd/etcd.conf
wget "${ETCD_CONF_URL}/etcd.service" -O /lib/systemd/system/etcd.service
```

编辑/etc/etcd/etcd.conf, 把IP改成本地IP，0.0.0.0的不要改。

如果是etcd集群，ETCD_INITIAL_CLUSTER="master1=https://192.168.1.144:2380,node1=https://192.168.1.145:2380,node2=https://192.168.1.146:2380" 

master1,node1,node2与ETCD_NAME参数匹配。

建立 var 存放信息，然后启动 Etcd 服务:
```
mkdir -p /var/lib/etcd && chown etcd:etcd -R /var/lib/etcd /etc/etcd
```

3. node1,node2 etcd安装（如果单点etcd跳过此步）

从master1 copy配置文件
```
mkdir -p /etc/etcd/ssl && cd /etc/etcd/ssl
scp  192.168.1.144:/etc/etcd/ssl/* .
scp  192.168.1.144:/usr/local/bin/etcd* /usr/local/bin/
groupadd etcd && useradd -c "Etcd user" -g etcd -s /sbin/nologin -r etcd
scp  192.168.1.144:/etc/etcd/etcd.conf /etc/etcd/etcd.conf
scp  192.168.1.144:/lib/systemd/system/etcd.service /lib/systemd/system/etcd.service
mkdir -p /var/lib/etcd && chown etcd:etcd -R /var/lib/etcd /etc/etcd
```

vim /etc/etcd/etcd.conf, ETCD_NAME改为node1 node2， 及修改IP

4. 启动etcd  
 systemctl enable etcd.service && systemctl start etcd.service  
如为集群，则都要启动  
验证，集群内节点注意时间要同步  
```
 export CA="/etc/etcd/ssl"
 ETCDCTL_API=3 etcdctl  --cacert=${CA}/etcd-ca.pem \
    --cert=${CA}/etcd.pem  --key=${CA}/etcd-key.pem \
    --endpoints="https://192.168.1.144:2379" \
    endpoint health
 ETCDCTL_API=3 etcdctl  --cacert=${CA}/etcd-ca.pem \
    --cert=${CA}/etcd.pem  --key=${CA}/etcd-key.pem \
    --endpoints="https://192.168.1.144:2379" \
    member list
```

5. 写kubeadm配置文件
```
root@instance-1:/home# cat cluster 
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
etcd:
  endpoints:
  - https://192.168.1.144:2379
  - https://192.168.1.145:2379
  - https://192.168.1.146:2379
  caFile : /etc/etcd/ssl/etcd-ca.pem
  certFile : /etc/etcd/ssl/etcd.pem
  keyFile : /etc/etcd/ssl/etcd-key.pem
networking:
  podSubnet: 10.244.0.0/16
```

kubeadm init  
```
root@master1:~# kubeadm init --config=cluster
```
### kubeadm init 排错
完成后如果不能get node ,get po

```
root@master1:/etc/kubernetes# kubectl get node
Unable to connect to the server: x509: certificate signed by unknown authority (possibly because of "crypto/rsa: verification error" while trying to verify candidate authority certificate "kubernetes")
```

清空/root/.kube
```
root@master1:/etc/kubernetes# rm -rf /root/.kube/

root@master1:/etc/kubernetes#   mkdir -p $HOME/.kube
root@master1:/etc/kubernetes#   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
root@master1:/etc/kubernetes#   sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 部署网络-flannel，与calico二选一
未部署网络时，get node，node的状态是not ready
```
root@master1:~# kubectl get no
NAME      STATUS     ROLES     AGE       VERSION
master1   NotReady   master    22m       v1.9.2
node1     NotReady   <none>    14m       v1.9.2
```

kube-dns的状态也是pending，他依赖于网络

通过官方模版导入flannel，yaml文件中有一行参数，"Network": "10.244.0.0/16" ，这个要与kubeadm init时候参数一致，是pod IP的范围
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
或者
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml  #来自官方

root@master1:~# kubectl get no
NAME      STATUS    ROLES     AGE       VERSION
master1   Ready     master    24m       v1.9.2
node1     Ready     <none>    16m       v1.9.2
```

### 部署网络-calico，与flannel二选一
1. 如果使用的k8s内置etcd  
直接执行，注意calico.yaml中pod IP范围与init一致。
```
kubectl taint node master1 node-role.kubernetes.io/master-  #如果只有一个maser，要设为可运行pod
kubectl apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/rbac.yaml
kubectl apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/calico.yaml
```


2. 使用自己部署的etcd  
RBAC. If deploying Calico on an RBAC enabled cluster, you should first apply the ClusterRole and ClusterRoleBinding specs:  
kubectl apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/rbac.yaml


Download calico.yaml  
Configure etcd_endpoints in the provided ConfigMap to match your etcd cluster.
Then simply apply the manifest:
```
wget https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/calico.yaml

vim calico.yaml  
修改
etcd_endpoints: "https://192.168.1.144:2379,https://192.168.1.145:2379,https://192.168.1.146:2379"
  etcd_ca: ""   # "/calico-secrets/etcd-ca"  --/etc/etcd/ssl/etcd-ca.pem
  etcd_cert: "" # "/calico-secrets/etcd-cert"  --/etc/etcd/ssl/etcd.pem
  etcd_key: ""  # "/calico-secrets/etcd-key"  --/etc/etcd/ssl/etcd-key.pem

对三个pem文件分别转码  
 base64 /etc/etcd/ssl/etcd-ca.pem  | tr -d '\n'
 base64 /etc/etcd/ssl/etcd.pem  | tr -d '\n'
 base64 /etc/etcd/ssl/etcd-key.pem | tr -d '\n'

把pod ip池修改为和init时候的ip池一致
            - name: CALICO_IPV4POOL_CIDR
              value: "192.168.0.0/16"

kubectl apply -f calico.yaml
kubectl taint node master1 node-role.kubernetes.io/master-  #如果只有一个maser，要设为可运行pod
```

```
root@master1:/home# kubectl logs calico-node-vvl87 calico-node  -n kube-system 
2018-01-29 09:46:16.638 [INFO][9] startup.go 187: Early log level set to info
2018-01-29 09:46:16.639 [INFO][9] startup.go 198: NODENAME environment not specified - check HOSTNAME
```

3. calicoctl

```
curl -O -L https://github.com/projectcalico/calicoctl/releases/download/v2.0.0/calicoctl
mv calicoctl /usr/local/bin/
chmod a+x /usr/local/bin/calicoctl
mkdir -p /etc/calico

vim /etc/calico/calicoctl.cfg
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  etcdEndpoints: https://192.168.1.144:2379,https://192.168.1.145:2379,https://192.168.1.146:2379
  etcdKeyFile: /etc/etcd/ssl/etcd-key.pem
  etcdCertFile: /etc/etcd/ssl/etcd.pem
  etcdCACertFile: /etc/etcd/ssl/etcd-ca.pem

calicoctl get ippools
calicoctl get node
```

###  node节点kubeadm join
node节点join失败
```
kubeadm join --token 55c2c6.2a4bde1bc73a6562 192.168.1.144:6443 --discovery-token-ca-cert-hash sha256:0fdf8cfc6fecc18fded38649a4d9a81d043bf0e4bf57341239250dcc62d2c832

[discovery] Failed to request cluster info, will try again: [Get https://192.168.1.144:6443/api/v1/namespaces/kube-public/configmaps/cluster-info: x509: certificate has expired or is not yet valid]
```

检查master节点KUBECONFIG变量，如果不存在,则执行export
```
root@master1:~# echo $KUBECONFIG
export KUBECONFIG=$HOME/.kube/config
```

node节点kubeadm reset ，再join

如果忘了token，在master执行kubeadm token list 可以看到token
node执行 kubeadm join --token n7uezq.b82snkxzseitpjzs  192.168.1.144:6443  --discovery-token-unsafe-skip-ca-verification
执行join执行要执行下kubeadm reset


### Addons
https://github.com/kubernetes/kubernetes/tree/master/cluster/addons

###  部署dashboard

dashboard（UI）默认是没有部署的，需要手动导入  

https://github.com/kubernetes/dashboard  

dashboard的语言是根据浏览器的语言自己识别的  

方法1： https

```
wget https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

修改下service，不然无法外部访问dashboard
kind: Service，增加type: NodePort和NodePort: 32001
  type: NodePort
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 32001

kubectl create -f kubernetes-dashboard.yaml

赋予dashboard 的sa 集群admin权限
cat admin-role.yaml

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: kubernetes-dashboard
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system

root@master1:~# kubectl create -f admin-role.yaml 
clusterrolebinding "admin" created

创建完成后，通过 https://任意节点的IP:32001即可访问，注意是https。
如果chrome无法打开，换firefox，kubeadm生产的证书日期不太多，过期了
登录页面直接点跳过就行，因为默认的serviceaccount已经具备了集群管理员权限。

如果想使用token登录，使用下面命令获取。就是kubernetes-dashboard-token这个secret
kubectl -n kube-system describe secret `kubectl -n kube-system get secret|grep kubernetes-dashboard-token|cut -d " " -f1`|grep "token:"|tr -s " "|cut -d " " -f2
```


方法2： http，登录不弹出认证页面

```
wget https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/alternative/kubernetes-dashboard.yaml

修改下service，不然无法外部访问dashboard
kind: Service，增加type: NodePort和NodePort: 32001
  type: NodePort
  ports:
  - port: 80
    targetPort: 9090
    nodePort: 32002

kubectl create -f kubernetes-dashboard.yaml

赋予dashboard 的sa 集群admin权限
cat admin-role.yaml

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: kubernetes-dashboard
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system

root@master1:~# kubectl create -f admin-role.yaml 
clusterrolebinding "admin" created
```

创建完成后，通过 http://任意节点的IP:32002即可访问

###  部署监控

Heapster + InfluxDB + Grafana
 
https://github.com/kubernetes/heapster/blob/master/docs/influxdb.md  

```
kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/grafana.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml
```
部署完成后，在dashboard能看到pod的cpu、mem使用量

如果想看grafana页面，改下service，通过nodeport暴露端口
```
 kubectl edit svc monitoring-grafana  -n kube-system
 type: ClusterIP 改成  type: NodePort
 
 kubectl get svc monitoring-grafana  -n kube-system
```

遗留问题：不显示master节点pod监控信息

###  部署EFK

```
https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/fluentd-elasticsearch

kubectl create -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/fluentd-elasticsearch/es-service.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/fluentd-elasticsearch/es-statefulset.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/fluentd-elasticsearch/fluentd-es-configmap.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/fluentd-elasticsearch/fluentd-es-ds.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/fluentd-elasticsearch/kibana-deployment.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/fluentd-elasticsearch/kibana-service.yaml

给每个每个每个节点加下标签，不然fluentd-es-ds不会部署

kubectl label node node1 beta.kubernetes.io/fluentd-ds-ready=true


```

###  部署ingress controller

https://github.com/kubernetes/ingress-nginx  

Mandatory commands
```
curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/namespace.yaml  | kubectl apply -f -
curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/default-backend.yaml | kubectl apply -f -
curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/configmap.yaml  | kubectl apply -f -
curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/tcp-services-configmap.yaml | kubectl apply -f -
curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/udp-services-configmap.yaml | kubectl apply -f -
```

Install with RBAC roles
```
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/rbac.yaml
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/with-rbac.yaml
   
vim with-rbac.yaml  修改三处
1. kind: Deployment 改成kind: DaemonSet
2. replicas: 1  删除
3. initContainers:上面一行加hostNetwork: true #两句平级

导入
kubectl create -f rbac.yaml 
kubectl create -f with-rbac.yaml
```

检查
```
root@master1:~# kubectl get po -n ingress-nginx  -o wide
NAME                                    READY     STATUS    RESTARTS   AGE       IP              NODE
default-http-backend-55c6c69b88-6n88s   1/1       Running   0          10m       10.244.1.15     node2
nginx-ingress-controller-2w9g4          1/1       Running   0          7m        192.168.1.146   node2
nginx-ingress-controller-bzfzr          1/1       Running   0          7m        192.168.1.145   node1
nginx-ingress-controller-j9lds          1/1       Running   3          7m        192.168.1.144   master1
```

### FAQ 
### kubectl 命令补全

```
root@master1:/# vim /etc/profilecd   #添加下面这句，再source
source <(kubectl completion bash)
root@master1:/# source /etc/profile
```

### master节点默认不可部署pod

执行如下，node-role.kubernetes.io/master 可以在 kubectl edit node master1中taint配置参数下查到
```
root@master1:/var/lib/kubelet# kubectl taint node master1 node-role.kubernetes.io/master-
node "master1" untainted
```

### node节点pod无法启动/节点删除网络重置

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

