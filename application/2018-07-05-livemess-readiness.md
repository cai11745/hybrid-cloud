# liveness readiness 健康检查

为了更好的检测容器是否存活及能否对外提供服务。 通常在正式运行的应用中都会配置这两个参数来保障应用的正常运行。

liveness probe  存活探针， 来确定容器何时重启（注意是重启容器，不是杀了pod 重来）。一旦探针检测失败次数达到设定值，就会重启容器。 在 kubectl get pod 的状态中能看到 restart 次数。

readiness 就绪探针， 来确定容器是否就绪能够接受流量。当探针返回0， 即返回结果为正常时， kubelet 会认定容器就绪，可以提供服务，就会把容器加到 service 的负载中。 反之，则会从负载列表中移除容器。

[kubernetes 官方配置文档](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/)

有三种 liveness/readiness probe 可供选择：http、tcp 和 container exec。前两者检查 Kubernetes 是否能使 http 或者 tcp 连接至指定端口。container exec probe 可用来运行容器里的指定命令，并维护容器里的停止响应代码。如下所示的代码片段中,我们使用http probe发送Root URL，使用 GET请求到端口80。

liveness和readiness在参数格式上用法相同，只是作用不通。

## liveness

许多长时间运行的应用程序最终会转换到broken状态，除非重新启动，否则无法恢复。Kubernetes提供了liveness probe来检测和补救这种情况。当探针检测到容器异常时，能自动重启容器。

### exec

```bash
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    image: registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5

```

该配置文件给Pod配置了一个容器。periodSeconds 规定kubelet要每隔5秒执行一次liveness probe。 initialDelaySeconds 告诉kubelet在第一次执行probe之前要的等待5秒钟。探针检测命令是在容器中执行 cat /tmp/healthy 命令。如果命令执行成功，将返回0，kubelet就会认为该容器是活着的并且很健康。如果返回非0值，kubelet就会杀掉这个容器并重启它。

容器启动时，执行该命令：

```bash
/bin/sh -c "touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600"

```

在容器生命的最初30秒内有一个 /tmp/healthy 文件，在这30秒内 cat /tmp/healthy 命令会返回一个成功的返回码。30秒后， cat /tmp/healthy 将返回失败的返回码。

创建Pod：

```bash
root@master1:~/k8s-oc-yaml/application# kubectl create -f pod-liveness-exec.yaml 
pod "liveness-exec" created
```

在30秒内，查看Pod的event：

```bash
kubectl describe pod liveness-exec
```

结果显示没有失败的liveness probe：

```bash
Events:
  Type    Reason                 Age   From               Message
  ----    ------                 ----  ----               -------
  Normal  Scheduled              1m    default-scheduler  Successfully assigned liveness-exec to node1
  Normal  SuccessfulMountVolume  1m    kubelet, node1     MountVolume.SetUp succeeded for volume "default-token-8lv8j"
  Normal  Pulling                1m    kubelet, node1     pulling image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28"
  Normal  Pulled                 18s   kubelet, node1     Successfully pulled image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28"
  Normal  Created                18s   kubelet, node1     Created container
  Normal  Started                18s   kubelet, node1     Started container
```

启动35秒后，再次查看pod的event：

```bash
kubectl describe pod liveness-exec
```

在最下面有一条信息显示liveness probe失败，容器被删掉并重新创建。

```bash
Events:
  Type     Reason                 Age               From               Message
  ----     ------                 ----              ----               -------
  Normal   Scheduled              11m               default-scheduler  Successfully assigned liveness-exec to node1
  Normal   SuccessfulMountVolume  11m               kubelet, node1     MountVolume.SetUp succeeded for volume "default-token-8lv8j"
  Normal   Pulling                11m               kubelet, node1     pulling image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28"
  Normal   Pulled                 10m               kubelet, node1     Successfully pulled image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28"
  Normal   Started                8m (x3 over 10m)  kubelet, node1     Started container
  Normal   Created                6m (x4 over 10m)  kubelet, node1     Created container
  Normal   Killing                6m (x3 over 9m)   kubelet, node1     Killing container with id docker://liveness:Container failed liveness probe.. Container will be killed and recreated.
  Normal   Pulled                 6m (x3 over 9m)   kubelet, node1     Container image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28" already present on machine
  Warning  Unhealthy              1m (x19 over 9m)  kubelet, node1     Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
 ```

再等30秒，确认容器已经重启：
kubectl get pod liveness-exec
从输出结果来RESTARTS值加1了。
NAME            READY     STATUS    RESTARTS   AGE
liveness-exec   1/1       Running   1          1m







容器有一个特性，当容器重启或删除后，其中的数据就会丢失。

所以对于一些需要保留的数据，需要通过 volume 的方式挂载到网络存储或本地存储。

存储的方式可以是网络存储 nfs ceph glusterfs 等， 也可以是 hostpath emptydir.

## 多 volueme 书写注意

 volumeMounts  volumes 这参数只要写一次

```bash
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: tom-volume  
spec:
  replicas: 2
  template:
    metadata:
      labels:
        run: tom-volume
    spec:
      containers:
      - image: registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0
        name: tom-volume
        ports:
        - containerPort: 8080
          name: port8080  
        volumeMounts:
        - mountPath: /usr/local/tomcat/logs/    # 容器内路径
          name: log     # 要与 volume 中 name 匹配
        - mountPath: /mnt      # 容器内路径
          name: other
      volumes:
      - name: log
        hostPath:
          path: /tmp/logs/     # 使用 pod 所在节点的路径
      - name: other
        emptyDir: {}

```

错误示例1：

```bash
        volumeMounts:
        - mountPath: /usr/local/tomcat/logs/
          name: log
        volumeMounts:    #多余
        - mountPath: /mnt
          name: other
      volumes:
      - name: log
        hostPath:
          path: /tmp/logs/
      volumes:    #多余
      - name: other
        emptyDir: {}
```

错误示例2：

```bash
        volumeMounts:
        - mountPath: /usr/local/tomcat/logs/
          name: log
      volumes:
      - name: log
        hostPath:
          path: /tmp/logs/
        volumeMounts:
        - mountPath: /mnt
          name: other
      volumes:
      - name: other
        emptyDir: {}
```

错误示例3：

```bash
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: tom-volume  
spec:
  replicas: 2
  template:
    metadata:
      labels:
        run: tom-volume
    spec:
      containers:
      - image: registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0
        name: tom-volume
        volumeMounts:
        - mountPath: /usr/local/tomcat/logs/
          name: log
        - mountPath: /mnt
          name: other
      volumes:   # 和containers 一个级别
      - name: log
        hostPath:
          path: /tmp/logs/
      - name: other
        emptyDir: {}
        ports:    # 和image volumemount 一个级别，应该写到 volume 上面
        - containerPort: 8080
          name: port8080  
```

## 使用 nfs

对于需要容器内数据持久化的，低成本的方案是自己部署nfs server。

对于性能有要求的可以使用企业级 NAS 或者 ceph glusterfs。

使用 ceph 和 glusterfs 的方式将会单独写出来，可以通过搜索查找相关内容。

使用网络存储可以直接在 volume 中定义网络存储参数， 也可以先 挂在到 pvc ，通过 pv pvc 配置存储。 pv pvc 的方式将在后面存储的内容中介绍。

更推荐使用 pv pvc 方式。

已有 nfs server ， IP 192.168.4.136 , 路径 /srv/nfs/share

```bash

apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: tom-nfs  
spec:
  replicas: 1
  template:
    metadata:
      labels:
        run: tom-nfs
    spec:
      containers:
      - image: registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0
        name: tom-nfs
        ports:
        - containerPort: 8080
          name: port8080  
        volumeMounts:
        - mountPath: /usr/local/tomcat/logs/
          name: log
      volumes:
      - name: log
        nfs:
         server: 192.168.4.136
         path: "/srv/nfs/share"

```

可以进入到容器 df -h 中查看

```bash
root@master1:~/yaml-new/application# kubectl create -f deployment-volume-nfs.yaml
deployment.extensions "tom-nfs" created

root@master1:~/yaml-new/application# kubectl exec -it tom-nfs-5549849fc6-vsjdb bash
root@tom-nfs-5549849fc6-vsjdb:/usr/local/tomcat# df -h
Filesystem                    Size  Used Avail Use% Mounted on
none                           51G   36G   12G  76% /
tmpfs                         4.2G     0  4.2G   0% /dev
tmpfs                         4.2G     0  4.2G   0% /sys/fs/cgroup
/dev/mapper/node1--vg-root     51G   36G   12G  76% /etc/hosts
shm                            64M     0   64M   0% /dev/shm
192.168.4.136:/srv/nfs/share   76G   39G   37G  52% /usr/local/tomcat/logs
tmpfs                         4.2G   12K  4.2G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                         4.2G     0  4.2G   0% /sys/firmware

```

## 使用 hostpath

使用 nfs 在某些情况下，读写性能不能满足需求，可以使用 hostpath ，即数据直接写到容器所在节点的指定目录。

但是 pod 重启后， 如果漂移到其他节点， 那挂载的数据就会丢失，如果要求数据不能丢失，可以配合 nodeselector 使用。 即强制 pod 只运行在某个节点，重启或删除重建后数据不会丢失。

使用场景示例， EFK 中的 elasticsearch 集群， es1 发布到 node1， es2 发布到 node2， es3 发布到 node3

没找到es的模板，就用tomcat的了，比如 现在要把 tom-hostpath 应用发布到node1

```bash
# 给node1 增加标签 hostpath=yes
root@master1:~# kubectl label node node1 hostpath=yes
node "node1" labeled
root@master1:~# kubectl get node --show-labels
NAME      STATUS    ROLES     AGE       VERSION   LABELS
master1   Ready     master    24d       v1.10.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=master1,node-role.kubernetes.io/master=
node1     Ready     <none>    24d       v1.10.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,hostpath=yes,kubernetes.io/hostname=node1
node2     Ready     <none>    20d       v1.10.0   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=node2

# 书写 yaml 文件
root@master1:~/k8s-oc-yaml/application# cat deployment-volume-hostpath.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: tom-hostpath
spec:
  replicas: 1
  template:
    metadata:
      labels:
        run: tom-hostpath
    spec:
      nodeSelector:
        hostpath: "yes"
      containers:
      - image: registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0
        name: tom-hostpath  
        ports:
        - containerPort: 8080
          name: port8080  
        volumeMounts:
        - mountPath: /usr/local/tomcat/logs/
          name: log
      volumes:
      - name: log
        hostPath:
          path: "/tmp/test-hostpath"

# 特别注意： 如果是openshift， 需要提前修改目录的 selinux 上下文，不然挂载的时候会报权限问题
chcon -Rt svirt_sandbox_file_t /tmp/test-hostpath

# 创建应用
root@master1:~/k8s-oc-yaml/application# kubectl create -f deployment-volume-hostpath.yaml
deployment.extensions "tom-hostpath" created

# node1 查看文件, /tmp/test-hostpath 目录如果之前没有，会自动创建
root@node1:~# hostname
node1
root@node1:~# ls /tmp/test-hostpath/
catalina.2018-07-03.log  host-manager.2018-07-03.log  localhost.2018-07-03.log	localhost_access_log.2018-07-03.txt  manager.2018-07-03.log

```

使用hostpath 方式，在容器删除后，hostpath 路径中的文件会保留。

## 使用 emptydir

当 pod 删除时，emptydir 中的数据也会被清除，这与 hostpath 不同。

但是 pod 中的容器崩溃，或者重启， emptydir 中的数据不会丢失。

```bash
root@master1:~/k8s-oc-yaml/application# cat deployment-volume-emptydir.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: tom-emptydir  
spec:
  replicas: 1
  template:
    metadata:
      labels:
        run: tom-emptydir
    spec:
      containers:
      - image: registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0
        name: tom-emptydir
        ports:
        - containerPort: 8080
          name: port8080  
        volumeMounts:
        - mountPath: /usr/local/tomcat/logs/
          name: log
      volumes:
      - name: log
        emptyDir: {}

# 创建应用
root@master1:~/k8s-oc-yaml/application# kubectl create -f deployment-volume-emptydir.yaml
deployment.extensions "tom-emptydir" created

root@master1:~/k8s-oc-yaml/application# kubectl get pod -owide
NAME                            READY     STATUS    RESTARTS   AGE       IP           NODE
tom-emptydir-7f7d5c875f-fqrkc   1/1       Running   0          20s       10.244.4.8   node2

# 进入容器，在挂载的日志目录写一个文件，并使用 shutdown.sh 命令使容器重启
root@master1:~/k8s-oc-yaml/application# kubectl exec -it tom-emptydir-7f7d5c875f-fqrkc bash
root@tom-emptydir-7f7d5c875f-fqrkc:/usr/local/tomcat# cd logs/
root@tom-emptydir-7f7d5c875f-fqrkc:/usr/local/tomcat/logs# date > testfile
root@tom-emptydir-7f7d5c875f-fqrkc:/usr/local/tomcat/logs# cd ../bin/
root@tom-emptydir-7f7d5c875f-fqrkc:/usr/local/tomcat/bin# ./shutdown.sh

# 执行完上一步，容器会重启，可以看到 RESTARTS 次数是1
root@master1:~/k8s-oc-yaml/application# kubectl get pod -owide
NAME                            READY     STATUS    RESTARTS   AGE       IP           NODE
tom-emptydir-7f7d5c875f-fqrkc   1/1       Running   1          2m        10.244.4.8   node2

# 进入容器，之前写入的文件还存在。 注意这是容器重启，不是 pod 删了重建，pod 重建数据还是会丢失。
root@master1:~/k8s-oc-yaml/application# kubectl exec -it tom-emptydir-7f7d5c875f-fqrkc bash
root@tom-emptydir-7f7d5c875f-fqrkc:/usr/local/tomcat# cat logs/testfile
Thu Jul  5 07:55:50 UTC 2018

```

至此，最常用的 volume 使用方法 nfs hostpath emptydir 介绍结束。这种使用方法比较快速，不需要创建 pv pvc。

在正式的测试生产过程中还是使用pv pvc 方式，更便于存储的查询与管理。

pv pvc 以及 glusterfs ceph 分布式存储的使用方式在后续 volume 中做更多介绍。