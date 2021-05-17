---
layout: post
title:  openshift4.4 在线最小化安装（可用于all-in-one） -- 静态ip
category: openshift，4.4, install 
description: 
---

本文描述openshift4.4 baremental 在线安装方式，我的环境是 vmwamre esxi 虚拟化，也适用于其他方式提供的虚拟主机或者物理机。  
ocp4 注册账户即可下载畅游。 - -！  觉得好的可以买官方订阅提供更多企业服务。   
采用 1master 1 worker方式，节约资源，worker节点可以参照步骤，想加多少加多少。   
若采用 all in one 单节点，master多分配些资源，不再需要部署worker，在下文mster 部署及组件部署后即完成，步骤都是一样的。

之前做过4.3 的离线安装，环境坏了。这次方便点，直接用在线安装，1master 1worker。  
4.3离线安装-dhcp方式，之前的文档，高可用的离线安装。    
https://github.com/cai11745/k8s-ocp-yaml/blob/master/ocp4/2020-02-25-openshift4.3-install-offline-dhcp.md

### 部署环境介绍

比官方多了一个base节点，用来搭建部署需要的dns，仓库等服务，这台系统用Centos7.6，因为centos解决源比较方便。

其他机器都用RHCOS，就是coreos专门针对openshift的操作系统版本。  

|Machine|OS|vCPU|RAM|Storage|IP|
|-|-|-|-|-|-|
|bastion|Centos7.6|2|8GB|100 GB|192.168.2.20|
|bootstrap-0|RHCOS|2|4GB|100 GB|192.168.2.21|
|master-0|RHCOS|8|16 GB|100 GB|192.168.2.22|
|worker-0|RHCOS|16|32 GB|100 GB|192.168.2.23|

节点角色：  
1台 基础服务节点，用于安装部署所需的dhcp，dns，ftp服务。系统不限。由于单master，这台上面不用部署负载了。 
1台 部署引导节点 Bootstrap，用于安装openshift集群，在集群安装完成后可以删除。系统RHCOS  
1台 控制节点 Control plane，即master，通常使用三台部署高可用，etcd也部署在上面。系统RHCOS  
2台 计算节点 Compute，用于运行openshift基础组件及应用 。系统RHCOS

### 安装顺序

顺序就是先准备基础节点，包括需要的dns、文件服务器、引导文件等，然后安装引导机 bootstrap，再后面就是 master， 再 node

### 安装准备-镜像仓库

#### 安装base基础组件节点
|base|centos7.6|4|8GB|100 GB|192.168.2.20|

安装系统 centos7.6 mini  
设置IP，设置主机名，关闭防火墙和selinux
注意所有节点主机名采用三级域名格式  如 master1.aa.bb.com

base 节点最好安装ntp 服务对下时间，确保时间正常，若时间异常部署节点时拉取镜像会报错 "x509: certificate has expired or is not yet valid"

```bash
hostnamectl set-hostname bastion.ocp4.example.com
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
systemctl disable firewalld
systemctl stop firewalld

```
#### 下载安装文件
https://cloud.redhat.com/openshift/install/metal/user-provisioned
没有账号就注册一个  
下载 openshift-install-linux.tar.gz   pull-secret.txt  openshift-client-linux.tar.gz rhcos-4.4.3-x86_64-installer.x86_64.iso  	rhcos-4.4.3-x86_64-metal.x86_64.raw.gz
分别是安装文件，镜像拉取密钥，openshift linux client （oc 命令），RHCOS 安装文件，都从上面同一个页面下载，如果节点之前有oc命令，删掉，使用下载的最新的

安装 openshift-install 和 oc 命令

```bash
tar -zxvf openshift-install-linux.tar.gz
chmod +x openshift-install
mv openshift-install /usr/local/bin/

tar -zxvf openshift-client-linux.tar.gz
chmod +x oc kubectl
mv oc kubectl /usr/local/bin/
```
#### 配置dns server
base节点  
worker 节点连接 master 都是通过域名的，需要有一个dns server 负责域名解析

```bash
yum install dnsmasq -y

# 配置dnsmasq，配置文件如下
cd /etc/dnsmasq.d/

vi ocp4.conf
address=/api.ocp4.example.com/192.168.2.20
address=/api-int.ocp4.example.com/192.168.2.20
address=/.apps.ocp4.example.com/192.168.2.22
address=/etcd-0.ocp4.example.com/192.168.2.22
srv-host=_etcd-server-ssl._tcp.ocp4.example.com,etcd-0.ocp4.example.com,2380,10

# api 和api-int 指向base本机，本机会部署haproxy 负载到 bootstrap 和master
# .apps 这个用作应用的泛域名解析，写master的，一开始route 会部署到master节点
# etcd-0 写master的

# 启动服务
systemctl start dnsmasq
systemctl enable  dnsmasq

# 验证解析，通过nslookup 都能解析到上面对应的ip
yum install bind-utils -y

nslookup api.ocp4.example.com 192.168.2.20
nslookup api-int.ocp4.example.com 192.168.2.20
nslookup 333.apps.ocp4.example.com 192.168.2.20
nslookup etcd-0.apps.ocp4.example.com 192.168.2.20

```

#### 准备安装配置文件
base节点  
新建一个目录用于存放安装配置文件。目录不要建在 /root 下，后面httpd 服务权限会有问题。

```bash
mkdir /opt/install
cd /opt/install


# 编辑安装配置文件
vi install-config.yaml


apiVersion: v1
baseDomain: example.com    #1
compute:
- hyperthreading: Enabled 
  name: worker
  replicas: 0   #2
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 1   #3
metadata:
  name: ocp4   #4
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14   #5
    hostPrefix: 23 
  networkType: OpenShiftSDN
  serviceNetwork: 
  - 172.30.0.0/16    #5
platform:
  none: {}    #6
fips: false 
pullSecret: '{"auths": ...}'  #7
sshKey: 'ssh-ed25519 AAAA...'  #8

```

参数解读：
1. 基础域名
2. 因为work部署后面是单独执行的，这边写0
3. 单master，所以写1
4. 就是节点master/worker名称后面一级，这也是为什么主机名要用好几级 
5. pod ip 和service ip范围，需要注意不能和内网已有ip范围冲突
6. 我们这属于直接裸金属安装类别，所有不填
7. 这是上一节从网页下载的 pull-secret.txt 内容，需要在txt 内容两头加上单引号
8. 用于后面免密登录。 ssh-keygen -t rsa -b 2048 -N "" -f /root/.ssh/id_rsa  ；cat /root/.ssh/id_rsa.pub ；内容两头带上单引号填入sshKey

**备份下配置文件，必须，因为下面命令执行后这个 yaml 文件就消失了**

```bash
cp install-config.yaml install-config.yaml.bak.0619

# 生成kubernetes配置
# 这个--dir 是有install-config.yaml 的路径
openshift-install create manifests --dir=/opt/install

# 生成引导配置
openshift-install create ignition-configs --dir=/opt/install/

文件目录现在是这样
.
├── auth
│   ├── kubeadmin-password
│   └── kubeconfig
├── bootstrap.ign
├── master.ign
├── metadata.json
└── worker.ign

```

#### 部署 httpd 文件服务器
部署在base节点，用于openshift节点部署时候拉取配置文件  

```bash
# 安装httpd
yum install httpd -y

# 把/root/install 目录软链到 /var/www/html 下，可以把这个 raw.gz 文件名字改短点，后面手动输入省心点  
mv ocp4.4/rhcos-4.4.3-x86_64-metal.x86_64.raw.gz /opt/install/
ln -s /opt/install/ /var/www/html/install
chmod 777 -R /opt/install/

# 启动服务
systemctl start httpd
systemctl enable httpd
```

浏览器访问下 base节点， http://192.168.2.20/install/  可以查看到目录下的文件，点开一个文件确认下有查看权限，万一没权限没给到后面安装会失败，无法拉取文件

#### 部署haproxy
部署在base节点，负载到 bootstrap 和master api 6443 端口

```bash
yum install haproxy -y
cd /etc/haproxy/
vi haproxy.cfg  #在最下面加配置文件，也可以把自带的frontend 和backend删掉，没有用

# 可选项,可以通过页面查看负载监控状态
listen stats
    bind :9000
    mode http
    stats enable
    stats uri /
    monitor-uri /healthz

# 负载master api，bootstrap 后面删掉
frontend openshift-api-server
    bind *:6443
    default_backend openshift-api-server
    mode tcp
    option tcplog

backend openshift-api-server
    balance source
    mode tcp
    server bootstrap 192.168.2.21:6443 check
    server master0 192.168.2.22:6443 check

frontend machine-config-server
    bind *:22623
    default_backend machine-config-server
    mode tcp
    option tcplog

backend machine-config-server
    balance source
    mode tcp
    server bootstrap 192.168.2.21:22623 check
    server master0 192.168.2.22:22623 check

```

启动服务

```bash
systemctl enable haproxy && systemctl start haproxy
```

验证服务

通过浏览器页面查看 IP:9000 可以看到haproxy的监控页面，当前后端服务还没起，所以很多红色的。

#### 安装 bootstrap 

在虚拟化中按照之前的配置规划创建系统，使用 rhcos-4.4.3-x86_64-installer.x86_64.iso 启动系统

在安装界面 "Install RHEL CoreOS" ， 按 Tab 键修改启动参数。 
在 coreos.inst = yes 之后添加。仔细校对参数，不能粘贴

ip=192.168.2.21::192.168.2.1:255.255.255.0:bootstrap.ocp4.example.com:ens192:none nameserver=192.168.2.20 coreos.inst.install_dev=sda coreos.inst.image_url=http://192.168.2.20/install/rhcos-4.4.3-x86_64-metal.x86_64.raw.gz coreos.inst.ignition_url=http://192.168.2.20/install/bootstrap.ign 

ip=.. 对应的参数是 ip=ipaddr::gateway:netmask:hostnameFQDN:网卡名称:是否开启dhcp

网卡名称和磁盘名称参照base节点，一样的命名规则，后面两个http文件先在base节点 wget 测试下能否下载

仔细检查，出错了会进入shell界面，可以排查问题。然后重启再输入一次

安装完成后，从base节点 ssh core@192.168.2.21 进入bootstrap 节点

```bash
检查下端口已经开启  
 ss -tulnp|grep 6443 
 ss -tulnp|grep 22623

 sudo crictl pods
 会有7个正常的pod
[core@bootstrap ~]$ sudo crictl pods
POD ID              CREATED             STATE               NAME                                                            NAMESPACE                             ATTEMPT
8e8954862fcb7       12 minutes ago      Ready               bootstrap-kube-scheduler-bootstrap.ocp4.example.com             kube-system                           0
93b2815644aa7       12 minutes ago      Ready               cloud-credential-operator-bootstrap.ocp4.example.com            openshift-cloud-credential-operator   0
065b168e882df       12 minutes ago      Ready               bootstrap-kube-controller-manager-bootstrap.ocp4.example.com    kube-system                           0
eca6297ed38a4       12 minutes ago      Ready               bootstrap-cluster-version-operator-bootstrap.ocp4.example.com   openshift-cluster-version             0
9c1ab43da5714       12 minutes ago      Ready               bootstrap-kube-apiserver-bootstrap.ocp4.example.com             kube-system                           0
f90a312794fd9       13 minutes ago      Ready               bootstrap-machine-config-operator-bootstrap.ocp4.example.com    default                               0
7a10cdbd474a1       13 minutes ago      Ready               etcd-bootstrap-member-bootstrap.ocp4.example.com                openshift-etcd                        0

# 查看服务状态的命令，ssh进去的时候就会提示这条命令
journalctl -b -f -u bootkube.service

```

#### 安装 master
同上，注意ip、主机名、ign配置文件和上述不同

ip=192.168.2.22::192.168.2.1:255.255.255.0:master0.ocp4.example.com:ens192:none nameserver=192.168.2.20 coreos.inst.install_dev=sda coreos.inst.image_url=http://192.168.2.20/install/rhcos-4.4.3-x86_64-metal.x86_64.raw.gz coreos.inst.ignition_url=http://192.168.2.20/install/master.ign 

装完后 master 的apiserver 会有问题，后面处理

```bash
mkdir ~/.kube
cp /opt/install/auth/kubeconfig ~/.kube/config 

echo '192.168.2.19 api.ocp4.example.com api-int.ocp4.example.com' >>/etc/hosts

[root@bastion ~]# oc get node
NAME                       STATUS   ROLES           AGE    VERSION
master0.ocp4.example.com   Ready    master,worker   163m   v1.17.1
```

master 上的etcd 没起得来，导致了master的apiserver 也是异常的，需要改下etcd参数
```bash
[root@bastion ~]# oc get pod -A |grep api
openshift-kube-apiserver                                kube-apiserver-master0.ocp4.example.com                           3/4     CrashLoopBackOff   30         47s

# 改etcd
oc patch etcd cluster -p='{"spec": {"unsupportedConfigOverrides": {"useUnsupportedUnsafeNonHANonProductionUnstableEtcd": true}}}' --type=merge

# 然后master 的etcd 会被拉起来
[root@bastion ~]# oc -n openshift-etcd get pod -owide
NAME                                         READY   STATUS      RESTARTS   AGE     IP             NODE                       NOMINATED NODE   READINESS GATES
etcd-master0.ocp4.example.com                3/3     Running     0          10m     192.168.2.22   master0.ocp4.example.com   <none>           <none>

# 观察apiserver 至恢复正常，一直不好就删pod重启看下
[root@bastion ~]# oc -n openshift-kube-apiserver get pod -owide |grep Running
kube-apiserver-master0.ocp4.example.com      4/4     Running     3          2m37s   192.168.2.22   master0.ocp4.example.com   <none>           <none>
```

master节点完成了

base 节点执行下面命令完成master节点安装

```bash
openshift-install --dir=/opt/install wait-for bootstrap-complete --log-level=debug

这个命令主要检测master 节点是否正常工作，完成后会提示可以移除bootstrap

```

现在可以修改 /etc/haproxy/haproxy.cfg 移除 bootstrap 节点的6443 和 22623， 然后重启haproxy。 或者直接改dnsmasq

因为我们只有一个master节点，或者可以直接修改dnserver配置  /etc/dnsmasq.d/ocp4.conf 的配置，将api.ocp4.example.com 和 api-int.ocp4.example.com 解析到 master节点IP 192.168.2.22 ，然后重启dnsmasq。 这种情况haproxy 服务可以关掉了。

现在master 的服务组件都安装完成了。bootstrap节点任务完成，可以关掉，已经没用了。  

/opt/install/install-config.yaml 中 worker 写的0，所以ocp 会默认把master节点打上 worker的标签。 从 oc get node 可以看出。

#### 安装其他组件
由于我们的master 有worker 的标签，也可当做计算节点。

使用 openshift-install 命令完成集群剩余组件的安装

先处理下 etcd-quorum-guard这个组件，默认是部署三个且用的主机网络，我们需要把他改成1个。

```bash
# 编辑文件，写入内容。必须打这个patch，不然直接改副本数，还会恢复回去
[root@bastion opt]# vi etcd_quorum_guard.yaml

- op: add
  path: /spec/overrides
  value:
  - kind: Deployment
    group: apps/v1
    name: etcd-quorum-guard
    namespace: openshift-machine-config-operator
    unmanaged: true


oc patch clusterversion version --type json -p "$(cat etcd_quorum_guard.yaml)"

oc scale --replicas=1 deployment/etcd-quorum-guard -n openshift-machine-config-operator

```


```bash
# 修改下面这些服务副本数为1 ，不然后面过不去
oc scale --replicas=1 ingresscontroller/default -n openshift-ingress-operator
oc scale --replicas=1 deployment.apps/console -n openshift-console
oc scale --replicas=1 deployment.apps/downloads -n openshift-console
oc scale --replicas=1 deployment.apps/oauth-openshift -n openshift-authentication
oc scale --replicas=1 deployment.apps/packageserver -n openshift-operator-lifecycle-manager

oc scale --replicas=1 deployment.apps/prometheus-adapter -n openshift-monitoring
oc scale --replicas=1 deployment.apps/thanos-querier -n openshift-monitoring
oc scale --replicas=1 statefulset.apps/prometheus-k8s -n openshift-monitoring
oc scale --replicas=1 statefulset.apps/alertmanager-main -n openshift-monitoring


openshift-install --dir=/opt/install wait-for install-complete --log-level debug

主要检查平台的web 监控等组件，完成后会提示登录地址和密码
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.ocp4.example.com
INFO Login to the console with user: kubeadmin, password: JzPpM-hVUJn-o2PD7-RKtoe

查看所有pod 状态
oc get pod -A
```

检查所有组件，avaiable 都是 true，如果有个别有问题，可以等worker部署完了慢慢排查。

```bash
[root@bastion ~]# oc get clusteroperator
NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.4.9     True        False         False      7m8s
cloud-credential                           4.4.9     True        False         False      46m
cluster-autoscaler                         4.4.9     True        False         False      7m32s
console                                    4.4.9     True        False         False      38s
csi-snapshot-controller                    4.4.9     True        False         False      11m
dns                                        4.4.9     True        False         False      11m
etcd                                       4.4.9     True        False         False      16m
image-registry                             4.4.9     True        False         False      11m
ingress                                    4.4.9     True        False         False      9m18s
insights                                   4.4.9     True        False         False      11m
kube-apiserver                             4.4.9     True        False         False      14m
kube-controller-manager                    4.4.9     True        False         False      18m
kube-scheduler                             4.4.9     True        False         False      19m
kube-storage-version-migrator              4.4.9     True        False         False      11m
machine-api                                4.4.9     True        False         False      11m
machine-config                             4.4.9     True        False         False      20m
marketplace                                4.4.9     True        False         False      11m
monitoring                                 4.4.9     True        False         False      6m29s
network                                    4.4.9     True        False         False      21m
node-tuning                                4.4.9     True        False         False      11m
openshift-apiserver                        4.4.9     True        False         False      3m41s
openshift-controller-manager               4.4.9     True        False         False      11m
openshift-samples                          4.4.9     True        False         False      5m26s
operator-lifecycle-manager                 4.4.9     True        False         False      21m
operator-lifecycle-manager-catalog         4.4.9     True        False         False      21m
operator-lifecycle-manager-packageserver   4.4.9     True        False         False      4m50s
service-ca                                 4.4.9     True        False         False      21m
service-catalog-apiserver                  4.4.9     True        False         False      21m
service-catalog-controller-manager         4.4.9     True        False         False      21m
storage                                    4.4.9     True        False         False      11m
```

至此平台已经部署完成，组件也部署完成，若采用all in one，则到此为止。

若需要继续添加计算节点，完成下一步骤。

#### 安装 worker
同上，注意ip、主机名、ign配置文件和上述不同

ip=192.168.2.23::192.168.2.1:255.255.255.0:worker0.ocp4.example.com:ens192:none nameserver=192.168.2.20 coreos.inst.install_dev=sda coreos.inst.image_url=http://192.168.2.20/install/rhcos-4.4.3-x86_64-metal.x86_64.raw.gz coreos.inst.ignition_url=http://192.168.2.20/install/worker.ign 


当worker 在控制台看到已经部署完

在部署机执行 oc get csr 命令，查看node 节点加入申请，批准之，然后就看到了node节点。 大功告成！！！
每个node节点会有两条新的csr

```bash
[root@bastion opt]# oc get csr
NAME        AGE   REQUESTOR                                                                   CONDITION
csr-bbzlk   29s     system:node:worker0.ocp4.example.com                                        Approved,Issued
csr-hxnvl   2m49s   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Approved,Issued

[root@bastion opt]# yum install epel-release
[root@bastion opt]# yum install jq -y
[root@bastion opt]# oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve

刚加进来状态是not ready，等一会就变成ready了
[root@bastion opt]# oc get node
NAME                       STATUS   ROLES           AGE     VERSION
master0.ocp4.example.com   Ready    master,worker   5h25m   v1.17.1
worker0.ocp4.example.com   Ready    worker          3m4s    v1.17.1
```

至此，整个集群部署完成，若要添加更多node节点，重复本步骤即可。

#### Web console 登录

ocp4的web console 入口走router了，所以找下域名  
首先找到我们的域名，然后在我们自己电脑上 hosts添加解析，指向到router所在节点ip，这样就能够访问openshift 的web 控制台了

```bash
[root@bastion opt]# oc get route -A |grep console-openshift
openshift-console          console             console-openshift-console.apps.ocp4.example.com                       console             https   reencrypt/Redirect     None
[root@bastion opt]# oc get pod -A -owide|grep router
openshift-ingress                                       router-default-679488d97-pt5xh                                    1/1     Running     0          21m     192.168.2.22   master0.ocp4.example.com   <none>           <none>
```

把这条写入hosts  
192.168.2.22 oauth-openshift.apps.ocp4.example.com console-openshift-console.apps.ocp4.example.com

然后浏览器访问console  
https://console-openshift-console.apps.ocp4.example.com

用户名是 kubeadmin
密码在这个文件里
cat /opt/install/auth/kubeadmin-password

后续需注意，若重启worker，则router 可能会在几台worker漂移，可以参照ocp3的做法，给某个节点打上infra 标签，再修改 router 的 nodeselector

oc -n openshift-ingress-operator get ingresscontroller/default -o yaml

###  参考文档

官方文档  
https://access.redhat.com/documentation/en-us/openshift_container_platform/4.4/html/pipelines/installing-pipelines  
https://www.redhat.com/sysadmin/kubernetes-cluster-laptop  

米开朗基杨  
https://cloud.tencent.com/developer/article/1638330


也可以顺便关注下我的github，后续更新会同步到github

https://github.com/cai11745/k8s-ocp-yaml

