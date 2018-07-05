# 单yaml 文件多资源共存

同一个 yaml 文件中包含多资源的写法，比如deployment， service ，pv 等

以deployment 和service 并存为例

## deployment 和 service 文件

deployment 文件

```bash
kubectl run tomcat11 --image=registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0 --replicas=2 --port=8080 --dry-run -o yaml > deploy.yaml

[root@master1 feng]# cat deploy.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    run: tomcat11
  name: tomcat11
spec:
  replicas: 2
  selector:
    matchLabels:
      run: tomcat11
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        run: tomcat11
    spec:
      containers:
      - image: registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0
        name: tomcat11
        ports:
        - containerPort: 8080
        resources: {}
status: {}

```

service 文件

```bash
kubectl expose deployment tomcat11 --port=8080 --type=NodePort --dry-run -o yaml > svc.yaml

[root@master1 feng]# cat svc.yaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  labels:
    run: tomcat11
  name: tomcat11
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    run: tomcat11
  type: NodePort
status:
  loadBalancer: {}

```

### 合并方式1

两个对象中间用 --- 隔开，不然会只能识别到一个

```bash
[root@master1 feng]# cat svc.yaml >> add.yaml
[root@master1 feng]# echo "---" >> add.yaml
[root@master1 feng]# cat deploy.yaml >> add.yaml

[root@master1 feng]# kubectl create -f add.yaml
service "tomcat11" created
deployment.extensions "tomcat11" created
```

### 合并方式2

用 kind: List 来定义集合，将其他对象，deployment， service，pvc 等作为子项。

注意 deployment service 等子项每行前面再加2给空格。

```bash

[root@master1 feng]# cat deploy.yaml >> add2.yaml
[root@master1 feng]# cat svc.yaml >> add2.yaml

# 每行前面插入2个空格
[root@master1 feng]# sed -i 's/^/  /g' add2.yaml

vim add2.yaml

增加前三行内容
子项的 apiVersion 行首的第一个空格换成 -

[root@master1 feng]# kubectl create -f add2.yaml
deployment.extensions "tomcat11" created
service "tomcat11" created


[root@master1 feng]# cat add2.yaml
apiVersion: v1
kind: List
items:
- apiVersion: extensions/v1beta1
  kind: Deployment
  metadata:
    creationTimestamp: null
    labels:
      run: tomcat11
    name: tomcat11
  spec:
    replicas: 2
    selector:
      matchLabels:
        run: tomcat11
    strategy: {}
    template:
      metadata:
        creationTimestamp: null
        labels:
          run: tomcat11
      spec:
        containers:
        - image: registry.cn-hangzhou.aliyuncs.com/misa/tomcat:9.0
          name: tomcat11
          ports:
          - containerPort: 8080
          resources: {}
  status: {}
- apiVersion: v1
  kind: Service
  metadata:
    creationTimestamp: null
    labels:
      run: tomcat11
    name: tomcat11
  spec:
    ports:
    - port: 8080
      protocol: TCP
      targetPort: 8080
    selector:
      run: tomcat11
    type: NodePort
  status:
    loadBalancer: {}

```
