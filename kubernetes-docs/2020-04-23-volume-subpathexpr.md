---
layout: post
title:  k8s 利用subpathexpr更好处理日志持久化落盘
category: kubernetes, subpathexpr
description: 
---

在k8s中，有些服务日志除了标准输出，还有写入日志文件，若要对这些日志文件进行持久化，不管是通过网络文件存储还是hostpath，都会面临一个问题，多个pod会往同一个文件写入，日志就乱了。

解决方法通常是在存储上先以pod hostname 建个目录，再往里写日志，使用sidercar pod 或者 修改启动脚本，但都不够简便或者太费资源。

现在可以通过subpathexpr 方式，在deployment 的yaml文件中，把pod name 以变量方式取出来，作为存储卷上的子目录来使用。

### subpathexpr 用法说明
使用 subPathExpr 字段从 Downward API 环境变量构造 subPath 目录名。 在使用此特性之前，必须启用 VolumeSubpathEnvExpansion 功能开关。 subPath 和 subPathExpr 属性是互斥的。 VolumeSubpathEnvExpansion 从k8s 1.15 开始就默认开启，1.17 GA.

在这个示例中，Pod 基于 Downward API 中的 Pod 名称，使用 subPathExpr 在 hostPath 卷 /mnt 中创建目录 pod1。 主机目录 /mnt/pod1 挂载到了容器的 /logs 中。

这是官方demo，注意hostpath 的路径需要在节点上已存在，而且不要用官方写的 /var/log/pods , 可以换成 /mnt 或者 /tmp ，原因见最后

```bash
apiVersion: v1
kind: Pod
metadata:
  name: pod1
spec:
  containers:
  - name: container1
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: metadata.name
    image: busybox
    command: [ "sh", "-c", "while [ true ]; do echo 'Hello'; sleep 10; done | tee -a /logs/hello.txt" ]
    volumeMounts:
    - name: workdir1
      mountPath: /logs
      subPathExpr: $(POD_NAME)
  restartPolicy: Never
  volumes:
  - name: workdir1
    hostPath:
      path: /mnt

```

所以上面一共有三个关键点
* 第一是 VolumeSubpathEnvExpansion 这个功能开关必须要打开，k8s 1.15 开始默认开启，1.17 GA

|Feature|	Default|	Stage|	Since|	Until|
|---|---|---|---|---|
|VolumeSubpathEnvExpansion|	false|	Alpha|	1.14|	1.14|
|VolumeSubpathEnvExpansion|	true|	Beta|	1.15|	1.16|
|VolumeSubpathEnvExpansion|	true|	GA|	1.17|	-|

官方说明  
https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/

* 第二就是 subpathexpr 这个参数，支持带拓展的环境变量

* 第三是 POD_NAME 的值获取，使用到了downwardapi，通过这个特性可以获取到pod的 name，namespace, uid, podIP, nodeName 等； 以及cpu，mem的request 和limit， 这个在一些java应用中经常会用到。  
还可以把 label annotations 以文件的方式挂载到容器内。

官方说明  
https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/

通过yaml 创建pod 测试一下
```bash
[root@k8s ~]# kubectl apply -f pod1.yaml
pod/pod1 created
[root@k8s ~]# ls /mnt/
pod1
[root@k8s ~]# ls /mnt/pod1/
hello.txt

[root@k8s ~]# kubectl exec -it pod1 sh
/ # ls /logs/
hello.txt

```
证实了 /mnt/pod1 挂载到了容器的 /logs 

### deployment 示例
如果还想在目录里把namespace 加上，来通过一个deployment 测试下

先看下文件，增加了一个环境变量，用于读取 namespace，并添加到了volumeMounts 

```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    run: subpath
  name: subpath
spec:
  replicas: 3
  selector:
    matchLabels:
      run: subpath
  template:
    metadata:
      labels:
        run: subpath
    spec:
      containers:
      - name: container1
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        image: busybox
        command: [ "sh", "-c", "while [ true ]; do echo 'Hello'; sleep 10; done | tee -a /logs/hello.txt" ]
        volumeMounts:
        - name: workdir1
          mountPath: /logs
          subPathExpr: $(POD_NAMESPACE)/$(POD_NAME)
      volumes:
      - name: workdir1
        hostPath:
          path: /mnt

```

通过文件创建deployment
```bash
[root@k8s ~]# kubectl apply -f subpath-deploy.yaml

[root@k8s ~]# kubectl get pod
NAME                      READY   STATUS    RESTARTS   AGE
subpath-79dd95cff-8pmz4   1/1     Running   0          20m
subpath-79dd95cff-mtc59   1/1     Running   0          19m
subpath-79dd95cff-mwwqw   1/1     Running   0          20m

[root@k8s ~]# tree /mnt/
/mnt/
└── default
    ├── subpath-79dd95cff-8pmz4
    │   └── hello.txt
    ├── subpath-79dd95cff-mtc59
    │   └── hello.txt
    └── subpath-79dd95cff-mwwqw
        └── hello.txt

4 directories, 3 files

```

可以看到存储目录 /mnt 下，首先是namespace ，然后是pod name， 每个pod写入的文件都在各自目录，不会出现多个pod 写入同一文件的情况。

### hostpath 使用 /var/log/pods 出现的情况

在第一次测试的时候，我按照官方的示例，hostpath 使用/var/log/pods , 等我进入容器的时候，发现进入不了 /logs 目录

```bash
[root@k8s ~]# kubectl exec -it pod1 sh
/ # cd logs/
sh: getcwd: No such file or directory
```

而在宿主机上，/var/log/pods 下也不见 pod1 目录。   
把pod1 删了，重新创建，并且持续观察 /var/log/pods 目录，会发现pod1 目开始是创建了的，不到一分钟就被自动删了，查阅资料，应该是被回收机制给清除了，不过我并没有找到相关的清除日志。

/var/log/pods 目录下，都是这种严格规范，按照namespace-podname-id 规则命名的文件夹  
kube-system_calico-kube-controllers-b7fb7899c-29sd8_b44230ae-1001-44c0-b661-1f43aac39130

也可以手动在 /var/log/pods 下面建一个目录测试下，一会就被删了。

kubelet 会通过每隔一分钟清理容器，同样，对于这种没有归属pod 的文件夹，也会被清除。可以参考下面的文章，介绍的很好。

垃圾回收机制介绍  
https://blog.csdn.net/shida_csdn/article/details/99734411