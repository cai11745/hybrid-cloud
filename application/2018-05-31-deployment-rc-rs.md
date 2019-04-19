# deployment（pod控制器）

deployment 针对无状态服务， 为当前最常用的 pod 控制器，可以实现滚动升级与回滚。

Replica Set 用来取代 Replication Controller， ReplicaSet支持集合式的selector。

虽然ReplicaSet可以独立使用，但一般还是建议使用 Deployment 来自动管理ReplicaSet，这样就无需担心跟其他机制的不兼容问题（比如ReplicaSet不支持rolling-update但Deployment支持）。

Replica Set 和 Replication Controller 的写法与 deployment 类似，以下均以 deployment 为例。

## yaml 示例

注意层级，比如  image ports resources 为同一级， 若吧 volume 插入到 port 下面，会导致 port 参数失效。

```bash
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

需要注意的是创建的deployment 下会以rs作为二级控制器实现版本管理。

```bash
macbook :: ~ » kubectl run tomcat --image=tomcat:9.0 --port=8080

macbook :: ~ » kubectl get deployment
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
tomcat    1         1         1            1           41m
macbook :: ~ »
macbook :: ~ » kubectl get rs
NAME                DESIRED   CURRENT   READY     AGE
tomcat-7bddb697fc   1         1         1         41m
```

## 应用升级 

升级镜像版本，set image 可以通过 --help 查看更多参数。  tomcat=tomcat:8.5  前面是容器名称，后面是镜像名称

升级会新增一个rs，记录了版本信息

```bash
macbook :: ~ » kubectl set image deployment/tomcat tomcat=tomcat:8.5 
deployment.apps "tomcat" image updated
macbook :: ~ »
macbook :: ~ » kubectl get rs -o wide
NAME                DESIRED   CURRENT   READY     AGE       CONTAINERS   IMAGES       SELECTOR
tomcat-7bddb697fc   0         0         0         50m       tomcat       tomcat:9.0   pod-template-hash=3688625397,run=tomcat
tomcat-879cdf45     1         1         0         2m        tomcat       tomcat:8.5   pod-template-hash=43578901,run=tomcat
```

## 版本回退

```bash
macbook :: ~ » kubectl rollout undo deployment tomcat  
deployment.apps "tomcat"
macbook :: ~ »
macbook :: ~ » kubectl get rs -o wide
NAME                DESIRED   CURRENT   READY     AGE       CONTAINERS   IMAGES       SELECTOR
tomcat-7bddb697fc   1         1         1         54m       tomcat       tomcat:9.0   pod-template-hash=3688625397,run=tomcat
tomcat-879cdf45     0         0         0         6m        tomcat       tomcat:8.5   pod-template-hash=43578901,run=tomcat
```

openshift的dc 同理，每个dc会有下一级rc，来做版本管理



