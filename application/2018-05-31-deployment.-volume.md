容器有一个特性，当容器重启或删除后，其中的数据就会丢失。

所以对于一些需要保留的数据，需要通过 volume 的方式挂载到网络存储或本地存储。

存储的方式可以是网络存储 nfs ceph glusterfs 等， 也可以是 hostpath emptydir.

## 多 volueme 书写注意

 volumeMounts  volumes 这参数只要写一次

```
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

```
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

```
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

```
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

```

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

```
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

但是 pod 重启后， 如果漂移到其他节点， 那挂载的数据就会丢失，通常配合 nodeselector 使用。 即强制 pod 只运行在某个节点，重启或删除重建后数据不会丢失。

使用场景示例， EFK 中的 elasticsearch 集群， es1 发布到 node1， es2 发布到 node2， es3 发布到 node3

```



```


deployment 针对无状态服务， 为当前最常用的 pod 控制器，可以实现滚动升级与回滚。

Replica Set 用来取代 Replication Controller， ReplicaSet支持集合式的selector。

虽然ReplicaSet可以独立使用，但一般还是建议使用 Deployment 来自动管理ReplicaSet，这样就无需担心跟其他机制的不兼容问题（比如ReplicaSet不支持rolling-update但Deployment支持）。

Replica Set 和 Replication Controller 的写法与 deployment 类似，以下均以 deployment 为例。

## yaml 示例

注意层级，比如  image ports resources 为同一级， 若吧 volume 插入到 port 下面，会导致 port 参数失效。


```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    run: tomcat11   # deployment 的标签
  name: tomcat11   # deployment 的名字
spec:
  replicas: 2    # 副本数，pod 的数量
  selector:
    matchLabels:
      run: tomcat11   # 与下面的template.metadata.labels 匹配，表示 deployment 与 pod 的关系
  template:   # pod 属性
    metadata:
      labels:
        run: tomcat11   # pod 标签
    spec:
      containers:  # 容器属性
      - image: registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0
        name: tomcat11   
        ports:
        - containerPort: 8080
          name: port8080   # 多 port 情况下，要写 name 以区分
        - containerPort: 8090
          name: port8090  
        resources:   # 资源限制
          requests:  
            cpu: 200m 
            memory: 200M
          limits: 
            cpu: 400m
            memory: 400M
        volumeMounts:
        - mountPath: /tmp
          name: tmp-vol    
      volumes:
      - name: tmp-vol
        hostPath:
          path: /tmp
    
```


