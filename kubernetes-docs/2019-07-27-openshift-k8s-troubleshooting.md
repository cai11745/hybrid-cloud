---
layout: post
title:  kubernetes/openshift 应用异常诊断思路
category: kubernetes,openshift,trobshooting
description: 
---

分享一下本人在k8s openshift项目中积累的一些异常诊断方法，希望能带给各位一些帮助。 本文主要描述问题解决流程和思路，针对应用发布/运行异常、访问异常，会插入一些场景。
分两部分
1. 应用发布后运行异常，即pod 无法正常启动或者启动后无限重启
2. 应用运行正常，pod 状态是running，但是无法通过ingress，nodeport，router等方式访问

### 一些技巧写在前面
应该能够在平时运维上提高一些效率
1. kubectl 命令table自动补全
```bash
echo 'source <(kubectl completion bash)' >>/etc/profile
source  /etc/profile

# mac
echo 'source <(kubectl completion zsh)' >> ~/.zshrc
source  ~/.zshrc
```

2. 切换namespace/project
```bash
# 使用非default namespace，先写 -n xxx ,不影响table补全 xxx
kubectl -n kube-system get deploy
kubectl -n kube-system describe pod xxx

# 如果长期在某个namespace下操作，可以设置默认namespace
kubectl config set-context --current --namespace=kube-system
kubectl get pod   #看到的都是kube-system下的pod

# 如果是openshift，直接oc project 可以切换
oc project openshift-infra
```
3. 应用迁移的时候配置文件由简到繁
不要一开始就一古脑把readiness，liveness，resource通通配上，会让你在排查故障时多走弯路。 最开始运行的时候只要镜像、端口、必要的环境变量或者存储。

### 应用运行异常整体处理流程
![troubleshooting-1](../image/troubleshooting-1.png)
简单说就是看pod event，pod start了，看pod log为主，但是也有可能是liveness 失败导致了反复重启，event也要看
容器未出现start，看event,存储挂载失败有时候要等几分钟才会出现event

图中每个操作默认第一个命令是kubectl,如kubectl describe pod xxx
以下详述各步骤操作缘由和可能引起的原因。
**查看pod 及控制器event的方法是 kubectl describe pod podname-xx  及 kubectl describe deploy deployname-xxx, 看pod 日志是 kubectl logs pod-name ，如果pod内多个容器，kubectl logs pod-name -c container-name**
另外，如果deploy，dc，pod中event都是空空如也，get rs,rc 看看他们的event，或许有新发现。 rs rc为deploy，dc的二级控制器，用于版本管理。

### kubectl get pod 能看到pod
#### pod event 无start container
1. pod状态处于pending
pod未被成功调度到node节点，通过查看pod event 都能够找到原因
下面列几个常见报错
a. 资源不足
```bash
kubectl apply -f https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-resources-limit.yaml
# kubectl get pod
NAME                                    READY   STATUS    RESTARTS   AGE
demo-resources-limit-7698bb955f-ldtgk   0/1     Pending   0          2m7s

# kubectl describe pod demo-resources-limit-7698bb955f-ldtgk
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  3m3s  default-scheduler  0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory.
  #内容解读一共1个node节点，0个node满足资源需求，1个不满足cpu，1个不满足内存。 
```
解决方法
```bash
# 手动修改deploy，kubectl edit deploy demo-resources-limit 
# 或者通过yaml文件来更新应用
kubectl apply -f https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-resources-limit-update.yaml
```

b. 使用了node selector，但是node节点未设置label
```bash
https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-node-selector.yaml

# kubectl get pod
NAME                                  READY   STATUS    RESTARTS   AGE
demo-node-selector-6cd7c5474f-whct6   0/1     Pending   0          72s
# kubectl describe pod demo-node-selector-6cd7c5474f-whct6 
Node-Selectors:  nodetest=yeyeye
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason            Age                    From               Message
  ----     ------            ----                   ----               -------
  Warning  FailedScheduling  2m50s (x2 over 2m50s)  default-scheduler  0/1 nodes are available: 1 node(s) didn't match node selector.

# deploy 配置了node selector，找不到对应label的node
# 解决方法，修改deploy中node selector或者给node 加上label
# kubectl get node --show-labels
NAME     STATUS   ROLES    AGE    VERSION   LABELS
ubuntu   Ready    master   223d   v1.13.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=ubuntu,node-role.kubernetes.io/master=

# kubectl label nodes ubuntu nodetest=yeyeye
node/ubuntu labeled

# kubectl get pod
NAME                                  READY   STATUS    RESTARTS   AGE
demo-node-selector-6cd7c5474f-whct6   1/1     Running   0          5m58s
```

c. 存储挂载失败
**这种情况在对接ceph，glusterfs的时候很有可能出现，可能是因为参数配置错误或者node节点未安装相应的client服务。**
**需要注意的是 创建pvc pv 并bond成功，并不能说明存储配置正确，此时是不校验存储可用性的，只有pod创建的时候，才会去真正挂载，此时才能确认存储是否可用。**
创建pv pvc，并创建一个deploy 使用pvc。 pv中是我的nfs 地址，若测试，需修改成自己的
```bash
kubectl apply -f https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-pv-pvc.yaml
kubectl apply -f https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-volume.yaml

# 查看pod event

Events:
  Type     Reason       Age   From               Message
  ----     ------       ----  ----               -------
  Normal   Scheduled    20s   default-scheduler  Successfully assigned troubleshot/demo-volume-5f974bf75c-vmpmp to ubuntu
  Warning  FailedMount  19s   kubelet, ubuntu    MountVolume.SetUp failed for volume "demo-pv" : mount failed: exit status 32
Mounting command: systemd-run
Mounting arguments: --description=Kubernetes transient mount for /var/lib/kubelet/pods/4ae14be1-b1f4-11e9-8cb3-001c4209f822/volumes/kubernetes.io~nfs/demo-pv --scope -- mount -t nfs 192.168.4.130:/opt/add-dev/nfs/ /var/lib/kubelet/pods/4ae14be1-b1f4-11e9-8cb3-001c4209f822/volumes/kubernetes.io~nfs/demo-pv
Output: Running scope as unit run-r7d15a31341454888b9a3d471611e827f.scope.
mount: wrong fs type, bad option, bad superblock on 192.168.4.130:/opt/add-dev/nfs/,
       missing codepage or helper program, or other error
       (for several filesystems (e.g. nfs, cifs) you might
       need a /sbin/mount.<type> helper program)

```
这个报错是没有安装nfs-client
每个node节点apt-get install nfs-utils 
重建pod
```bash
# kubectl get pod
NAME                           READY   STATUS              RESTARTS   AGE
demo-volume-5f974bf75c-tpkxv   0/1     ContainerCreating   0          3m48s

# kubectl describe pod demo-volume-5f974bf75c-tpkxv 
Events:
  Type     Reason       Age    From               Message
  ----     ------       ----   ----               -------
  Normal   Scheduled    2m19s  default-scheduler  Successfully assigned troubleshot/demo-volume-5f974bf75c-tpkxv to ubuntu
  Warning  FailedMount  16s    kubelet, ubuntu    Unable to mount volumes for pod "demo-volume-5f974bf75c-tpkxv_troubleshot(45985214-b1f6-11e9-8cb3-001c4209f822)": timeout expired waiting for volumes to attach or mount for pod "troubleshot"/"demo-volume-5f974bf75c-tpkxv". list of unmounted volumes=[share]. list of unattached volumes=[share default-token-2msph]
  Warning  FailedMount  13s    kubelet, ubuntu    MountVolume.SetUp failed for volume "demo-pv" : mount failed: exit status 32
Mounting command: systemd-run
Mounting arguments: --description=Kubernetes transient mount for /var/lib/kubelet/pods/45985214-b1f6-11e9-8cb3-001c4209f822/volumes/kubernetes.io~nfs/demo-pv --scope -- mount -t nfs 192.168.4.130:/opt/add-dev/nfs/ /var/lib/kubelet/pods/45985214-b1f6-11e9-8cb3-001c4209f822/volumes/kubernetes.io~nfs/demo-pv
Output: Running scope as unit run-r179d447154fc42fa9f1108382cf846df.scope.
mount.nfs: Connection timed out
```
查看event，报错不一样了，连接错误，因为，我写了错误的nfs ip，实际ip是192.168.4.133 ，修改yaml后把pv pvc删了重建，pod删了重建即可

```bash
# kubectl get pod
NAME                          READY   STATUS    RESTARTS   AGE
demo-volume-78d654c4d-2cwdx   1/1     Running   0          6m22s
# kubectl exec -it demo-volume-78d654c4d-2cwdx bash
root@demo-volume-78d654c4d-2cwdx:/usr/local/tomcat# df -h
Filesystem                      Size  Used Avail Use% Mounted on
overlay                          48G   17G   32G  35% /
tmpfs                            64M     0   64M   0% /dev
tmpfs                            16G     0   16G   0% /sys/fs/cgroup
192.168.4.133:/opt/add-dev/nfs  100G   62G   39G  62% /tmp
/dev/mapper/centos-root          48G   17G   32G  35% /etc/hosts
shm                              64M     0   64M   0% /dev/shm
tmpfs                            16G   12K   16G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                            16G     0   16G   0% /proc/acpi
tmpfs                            16G     0   16G   0% /proc/scsi
tmpfs                            16G     0   16G   0% /sys/firmware
```
现在都正常了，进入容器 df -h 查看挂载ok

2. pod状态处于 ImagePullBackOff或者 ErrImagePull
这个报错很明显，镜像拉取失败，通过 kubectl get pod -owide 查看pod 所在node节点，在node节点上手动docker pull 试试，或者是外网的镜像比如 gcr.io 可能需要自己手动搭梯子
另外需要注意，如果使用的是自己搭建的仓库，不是https的，而pod event 中镜像地址却是https:// 开头，说明你docker 配置中少了 Insecure Registries 的配置


#### pod event 有 start container
event出现start container，说明pod已经调度成功，镜像拉取成功，存储挂载成功（不代表读写权限正常）
但是可能因为健康检查配置不当或者容器启动脚本、存储权限、运行权限的原因导致启动失败而反复重启。
首先还是kubectl describe pod 看event，若没有报错内容，则查看pod log
1. pod liveness 监测失败
首先需要理解liveness的功能，当liveness 监测失败次数达到设定值的时候，就会重启容器。这种原因导致的容器重启原因在event中能够很明确的获取到，修改相应设定即可，或延迟init时间，或调整监测参数、端口。解决没有什么难度，而且遇到的也相对较少。
```bash

# kubectl get pod -owide
NAME                                  READY   STATUS    RESTARTS   AGE     IP           NODE     NOMINATED NODE   READINESS GATES
demo-liveness-fail-6b47f5bc74-n8qj4   1/1     Running   2          3m54s   10.68.0.56   ubuntu   <none>           <none>
# kubectl describe pod demo-liveness-fail-6b47f5bc74-n8qj4
  Normal   Pulling    2m42s (x4 over 4m49s)  kubelet, ubuntu    pulling image "tomcat"
  Warning  Unhealthy  2m42s (x3 over 2m48s)  kubelet, ubuntu    Liveness probe failed: HTTP probe failed with statuscode: 404
  Normal   Killing    2m42s                  kubelet, ubuntu    Killing container with id docker://demo-liveness-fail:Container failed liveness probe.. Container will be killed and recreated.
  Normal   Pulled     2m22s (x2 over 3m30s)  kubelet, ubuntu    Successfully pulled image "tomcat"
  Normal   Created    2m22s (x2 over 3m30s)  kubelet, ubuntu    Created container
  Normal   Started    2m21s (x2 over 3m30s)  kubelet, ubuntu    Started container
  Warning  Unhealthy  92s (x3 over 98s)      kubelet, ubuntu    Liveness probe failed: Get http://10.68.0.56:8080/healthz: net/http: request canceled (Client.Timeout exceeded while awaiting headers)
```
可以看到pod已经重启2次，event中有明确报错信息，对于liveness或者readiness的错误，手动访问下配置的端口或url或者command，测试下能否成功。
```bash
# 更新yaml文件，因为服务不存在/healthz的访问路径，把监测url /healthz 改为/docs
kubectl apply -f https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-liveness-fail-update.yaml

# kubectl get pod
NAME                                  READY   STATUS    RESTARTS   AGE
demo-liveness-fail-766f9df949-b68wr   1/1     Running   0          10m
```

2. pod 启动异常导致反复重启
**这种情况是非常常见的**
这种基本是启动脚本、权限之类问题引起。
基本思路是describe pod 看event，同时观察log。
首先 describe pod 看event 以及  Last State/Message 会有一些有用信息。

a. **注意 Exit Code，如果是0**，那说明pod是正常运行退出的，你没有设置启动脚本或者启动脚本有误，一下就执行完了，pod认为启动脚本已经执行完成，会吧container杀掉，而pod的重启策略是一直重启 restartPolicy: Always ，你就会看到你的pod在不停重启。
比如
```bash
# 没有设置容器启动脚本，因为centos:7镜像默认没有启动脚本
 kubectl run demo-centos --image=centos:7 

 # 或者给他一个很快就能执行完成的启动命令，也会反复重启
kubectl run demo-centos2 --image=centos:7  --command ls /

# 换这个，短期内是不会重启了
kubectl run demo-centos3 --image=centos:7  --command sleep 36000

# 这个，基本是永远不重启了，就是别让他闲着
kubectl run demo-centos4 --image=centos:7  --command tailf /var/log/lastlog
```

b. **注意 Exit Code，如果不是0**
那么可能是，**你的启动参数错了**
```bash
kubectl run demo-centos2 --image=centos:7  --command wahaha
kubectl describe pod demo-centos5-7fc7f8bccc-zpzct 

    Last State:     Terminated
      Reason:       ContainerCannotRun
      Message:      OCI runtime create failed: container_linux.go:348: starting container process caused "exec: \"wahaha\": executable file not found in $PATH": unknown
      Exit Code:    127
```

**或者你的存储权限不对**，此处为挂载的nfs server
```bash
# nfs server 参数，默认root_squash 是on
# cat /etc/exports
/opt/add-dev/nfs/ *(rw,sync)
```
创建pv pvc 和应用
```bash
kubectl apply -f https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-mysql-pv-pvc.yaml
kubectl apply -f https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-mysql-volume.yaml
```

这种情况下会出现存储权限报错
```bash
# kubectl get pod
NAME                                 READY   STATUS             RESTARTS   AGE
demo-mysql-volume-75fdc55cd5-4mxkp   0/1     CrashLoopBackOff   7          13m
[root@master1 troubleshooting]# kubectl logs demo-mysql-volume-75fdc55cd5-4mxkp 
chown: changing ownership of '/var/lib/mysql/': Operation not permitted

# 修改下nfs server的权限，重启nfs-server
# cat /etc/exports
/opt/add-dev/nfs/ *(rw,sync,no_root_squash)

# kubectl delete pod demo-mysql-volume-75fdc55cd5-4mxkp 
# kubectl get pod
NAME                                 READY   STATUS    RESTARTS   AGE
demo-mysql-volume-75fdc55cd5-l5bfh   1/1     Running   0          5m27s
root@demo-mysql-volume-75fdc55cd5-l5bfh:/# df -h
Filesystem                      Size  Used Avail Use% Mounted on
overlay                          48G   17G   31G  36% /
tmpfs                            64M     0   64M   0% /dev
tmpfs                            16G     0   16G   0% /sys/fs/cgroup
/dev/mapper/centos-root          48G   17G   31G  36% /etc/hosts
shm                              64M     0   64M   0% /dev/shm
192.168.4.133:/opt/add-dev/nfs  100G   63G   38G  63% /var/lib/mysql
tmpfs                            16G   12K   16G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                            16G     0   16G   0% /proc/acpi
tmpfs                            16G     0   16G   0% /proc/scsi
tmpfs                            16G     0   16G   0% /sys/firmware
```
**或者运行权限问题**
在新部署完成的openshift中，首次运行docker.io 上的tomcat，nginx 都会失败



### kubectl get pod 看不到pod
以下描述其中一种会导致发布应用看不到pod的场景。
好像是cka的一道考题。一下子涵盖了quota，limit，deploy的版本管理几个内容。
主要考察对deployment子控制器rs的了解及对quota limit了解。
通过yaml文件创建一个namespace，里面包含了quota和limit
```bash
kubectl apply -f https://raw.githubusercontent.com/cai11745/k8s-ocp-yaml/master/yaml-file/troubleshooting/demo-ns-quota-limit.yaml
```

然后在这个namespace下创建的应用都看不到pod

```bash
# kubectl -n demo-test run tomtest --image=tomcat
# kubectl -n demo-test get deploy
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
tomtest   0/1     0            0           3m3s
# kubectl -n demo-test get pod
No resources found.
# kubectl -n demo-test describe deployments tomtest 
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  4m2s  deployment-controller  Scaled up replica set tomtest-865b47b7df to 1
```

可以从deploy的event中看到，reason ScalingReplicaSet， replicaset是deploy的二级控制器，用于版本管理，简写rs，我们需要去查看rs 的event
（openshift deploymenyconfig的二级控制器是replicationcontrollers，简写rc）
```bash
# kubectl -n demo-test get rs
NAME                 DESIRED   CURRENT   READY   AGE
tomtest-865b47b7df   1         0         0       8m53s
# kubectl -n demo-test describe rs tomtest-865b47b7df 
  Warning  FailedCreate  9m14s                  replicaset-controller  Error creating: pods "tomtest-865b47b7df-hxwr6" is forbidden: exceeded quota: myquota, requested: cpu=2,memory=2Gi, used: cpu=0,memory=0, limited: cpu=1,memory=1G
  Warning  FailedCreate  3m47s (x8 over 9m12s)  replicaset-controller  (combined from similar events): Error creating: pods "tomtest-865b47b7df-f7mcx" is forbidden: exceeded quota: myquota, requested: cpu=2,memory=2Gi, used: cpu=0,memory=0, limited: cpu=1,memory=1G

```
可以看到rs的event中有明确报错信息。
原因是这个namespace 设置了quota，即资源上线为1核1G。 同时设置了limitranges 为2核2G，即这个namespace下创建的容器，每个的默认资源都为2核2G，资源不足导致了pod未创建。

 ### 应用运行正常，但是无法访问
 
基本思路就是从负载层一步步往回推，ingress/router/nodeport不通，就先在集群内访问service cluster地址，再在集群内直接访问pod地址

 具体下一篇再写。        