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
