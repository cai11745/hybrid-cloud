---
layout: post
title:  使用Helm管理kubernetes应用
category: kubernetes, helm
description: 
---

### 1. Helm用途

Helm把Kubernetes资源(比如deployments、services或 ingress等) 打包到一个chart中，而chart被保存到chart仓库。通过chart仓库可用来存储和分享chart。Helm使发布可配置，支持发布应用配置的版本管理，简化了Kubernetes部署应用的版本控制、打包、发布、删除、更新等操作。

做为Kubernetes的一个包管理工具，用来管理charts——预先配置好的安装包资源，有点类似于Ubuntu的APT和CentOS中的yum。Helm具有如下功能：
- 创建新的chart
- chart打包成tgz格式
- 上传chart到chart仓库或从仓库中下载chart
- 在Kubernetes集群中安装或卸载chart
- 管理用Helm安装的chart的发布周期

Helm有三个重要概念：

- chart：包含了创建Kubernetes的一个应用实例的必要信息
- config：包含了应用发布配置信息
- release：是一个chart及其配置的一个运行实例

### 2. Helm组件

Helm基本架构如下：
![架构图](http://p8whpnduw.bkt.clouddn.com/05-02-helm-1.jpg)


Helm有以下两个组成部分：

Helm Client是用户命令行工具，其主要负责如下：
- 本地chart开发
- 仓库管理
- 与Tiller sever交互
- 发送预安装的chart
- 查询release信息
- 要求升级或卸载已存在的release

Tiller Server是一个部署在Kubernetes集群内部的server，其与Helm client、Kubernetes API server进行交互。

Tiller server主要负责如下：
- 监听来自Helm client的请求
- 通过chart及其配置构建一次发布
- 安装chart到Kubernetes集群，并跟踪随后的发布
- 通过与Kubernetes交互升级或卸载chart

简单的说，client管理charts，而server管理发布release。


### 3. 安装Helm
#### 3.1 前提要求
- Kubernetes1.5以上版本
- 集群可访问到的镜像仓库
- 执行helm命令的主机可以访问到kubernetes集群

#### 3.2 安装步骤

首先需要安装helm客户端

方法1：需要能连外网 
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```
方法2： 我把helm 包和镜像上传到了网盘
```
链接：https://pan.baidu.com/s/168HPcThZQU8SgxDA43_4vg 密码：l4it

tar -zxvf helm-v2.9.1-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin/
chmod +x /usr/local/bin/helm
docker load -i tiller-2.9.0.tar
```

然后安装helm服务端tiller

创建tiller的serviceaccount和clusterrolebinding

tiller的服务端是一个deployment，在kube-system namespace下，会去连接kube-api创建应用和删除，所以需要给他权限
```
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
```

安装server端，如果能连外网，直接helm init，会自动拉取镜像。不能的话，指定镜像，镜像文件在上面的网盘里

```
helm init   或者
helm init -i gcr.io/kubernetes-helm/tiller:v2.9.0

```

为应用程序设置serviceAccount：
```
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```

#### 3.3 检验版本
完成后查看pod状态和helm版本，容器中的为helm server端， 虚拟机的/usr/local/bin/helm为client
```
[root@master1 ~]# kubectl get pod -n kube-system |grep tiller
tiller-deploy-f6585f7d5-k9chk     1/1       Running   0          10m
[root@master1 ~]# helm version
Client: &version.Version{SemVer:"v2.9.1", GitCommit:"20adb27c7c5868466912eebdf6664e7390ebe710", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.9.0", GitCommit:"f6025bb9ee7daf9fee0026541c90a6f557a3e0bc", GitTreeState:"clean"}
```

### 4. helm 使用

 常用命令

查看源
```
helm repo list    #列出所有源，当前还没有添加源
# 添加一个国内可以访问的阿里源，不过好像最近不更新了
helm repo add ali https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts  
如果能连外网，可以加google，f8
helm repo add google https://kubernetes-charts.storage.googleapis.com 
helm repo add fabric8 https://fabric8.io/helm
# 更新源
helm repo update
```

查看chart
```
# 查看chart，即已经通过helm部署到 k8s 平台的应用
helm list    或者  helm ls

# 若要查看或搜索存储库中的 Helm charts，键入以下任一命令
helm search 
helm search 存储库名称 #如 stable 或 incubator
helm search chart名称 #如 wordpress 或 spark

# 查看charm详情
helm inspect ali/wordpress
```

下载chart
```
helm fetch ali/wordpress
[root@master1 ~]# ls wordpress-0.8.8.tgz 
wordpress-0.8.8.tgz
```


部署应用 wordpress， 通过ali源文件
```
helm install --name wordpress-test --set "persistence.enabled=false,mariadb.persistence.enabled=false" ali/wordpress

[root@master1 ~]# kubectl get pod 
NAME                                        READY     STATUS    RESTARTS   AGE
wordpress-test-mariadb-84b866bf95-7bx5w     1/1       Running   1          4h
wordpress-test-wordpress-5ff8c64b6c-hrh9q   1/1       Running   0          4h
[root@master1 ~]# kubectl get svc 
NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
kubernetes                 ClusterIP      10.96.0.1        <none>        443/TCP                      2d
wordpress-test-mariadb     ClusterIP      10.105.71.95     <none>        3306/TCP                     4h
wordpress-test-wordpress   LoadBalancer   10.104.106.150   <pending>     80:30655/TCP,443:32121/TCP   4h

```

访问wordpress，使用node节点ip + nodeport， 192.168.1.181:30655 

![访问wordpress](http://p8whpnduw.bkt.clouddn.com/05-02-helm-2.jpg)


删除应用
```
[root@master1 ~]# helm list
NAME          	REVISION	UPDATED                 	STATUS  	CHART          	NAMESPACE
wordpress-test	1       	Thu May 17 11:35:07 2018	DEPLOYED	wordpress-0.8.8	default  
[root@master1 ~]# helm delete wordpress-test
release "wordpress-test" deleted
```


### 5. 建立自己的chart

创建一个自己的chart，看下文档结构，学习下如何使用

```
root@master1:~# helm create misa86
root@master1:~# tree misa86
misa86
├── charts     #Chart本身的版本和配置信息
├── Chart.yaml    #Chart本身的版本和配置信息
├── templates    #配置模板目录
│   ├── deployment.yaml    #kubernetes Deployment object
│   ├── _helpers.tpl    #用于修改kubernetes objcet配置的模板
│   ├── ingress.yaml    #kubernetes Deployment object
│   ├── NOTES.txt    #helm提示信息
│   └── service.yaml    #kubernetes Serivce
└── values.yaml    #kubernetes object configuration，定义变量

2 directories, 7 files
```

#### 5.1 模板 template
template下包含应用所有的yaml文件模板，这个和openshift的template 有点类似，感觉openshift的使用更简便一些。
应用资源的类型不仅限于deployment 和service这些，k8s支持的都可以。

```
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: {{ template "misa86.fullname" . }}
  labels:
    app: {{ template "misa86.name" . }}
    chart: {{ template "misa86.chart" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ template "misa86.name" . }}
      release: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ template "misa86.name" . }}
        release: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /
              port: http
          readinessProbe:
            httpGet:
              path: /
              port: http
          resources:
{{ toYaml .Values.resources | indent 12 }}
    {{- with .Values.nodeSelector }}
      nodeSelector:
{{ toYaml . | indent 8 }}
    {{- end }}
    {{- with .Values.affinity }}
      affinity:
{{ toYaml . | indent 8 }}
    {{- end }}
    {{- with .Values.tolerations }}
      tolerations:
{{ toYaml . | indent 8 }}
    {{- end }}
```


这是该应用的Deployment的yaml配置文件，其中的双大括号包扩起来的部分是Go template， template "misa86.name"  这类是在 _helpers.tpl 文件中定义的，如果不定义，将来文件名会是随意字符加chart名字。

其中的Values是在values.yaml文件中定义的，应用主要的参数在这边：
```
# Default values for misa86.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

replicaCount: 1

image:
  repository: nginx
  tag: stable
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # kubernetes.io/tls-acme: "true"
  path: /
  hosts:
    - chart-example.local
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

resources: {}
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  # limits:
  #  cpu: 100m
  #  memory: 128Mi
  # requests:
  #  cpu: 100m
  #  memory: 128Mi

nodeSelector: {}

tolerations: []

affinity: {}

```

比如在Deployment.yaml中定义的容器镜像image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"其中的：
```
.Values.image.repository就是nginx 
.Values.image.tag就是stable
```

以上两个变量值是在create chart的时候自动生成的默认值。

将默认的镜像地址和tag改成自己的地址 registry.cn-hangzhou.aliyuncs.com/misa/nginx:1.13


#### 5.2 检查配置和模板是否有效
当使用kubernetes部署应用的时候实际上将templates渲染成最终的kubernetes能够识别的yaml格式。

使用helm install --dry-run --debug <chart_dir>命令来验证chart配置。该输出中包含了模板的变量配置与最终渲染的yaml文件。 deployment service的名字前半截由两个随机的单词组成，随机数加chart名。 这名字也可以改成value方式，自己定义
如果配置等有问题此处会报错
```
[root@master1 ~]# helm install --dry-run --debug misa86/
[debug] Created tunnel using local port: '44114'

[debug] SERVER: "127.0.0.1:44114"

[debug] Original chart version: ""
[debug] CHART PATH: /root/misa86

NAME:   esteemed-wallaby
REVISION: 1
RELEASED: Fri May 18 17:38:49 2018
CHART: misa86-0.1.0
USER-SUPPLIED VALUES:
{}

COMPUTED VALUES:
affinity: {}
image:
  pullPolicy: IfNotPresent
  repository: registry.cn-hangzhou.aliyuncs.com/misa/nginx
  tag: 1.13
ingress:
  annotations: {}
  enabled: false
  hosts:
  - chart-example.local
  path: /
  tls: []
nodeSelector: {}
replicaCount: 1
resources: {}
service:
  port: 80
  type: ClusterIP
tolerations: []

HOOKS:
MANIFEST:

---
# Source: misa86/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: esteemed-wallaby-misa86
  labels:
    app: misa86
    chart: misa86-0.1.0
    release: esteemed-wallaby
    heritage: Tiller
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app: misa86
    release: esteemed-wallaby
---
# Source: misa86/templates/deployment.yaml
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: esteemed-wallaby-misa86
  labels:
    app: misa86
    chart: misa86-0.1.0
    release: esteemed-wallaby
    heritage: Tiller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: misa86
      release: esteemed-wallaby
  template:
    metadata:
      labels:
        app: misa86
        release: esteemed-wallaby
    spec:
      containers:
        - name: misa86
          image: "registry.cn-hangzhou.aliyuncs.com/misa/nginx:1.13"
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /
              port: http
          readinessProbe:
            httpGet:
              path: /
              port: http
          resources:
            {}

```

#### 5.3 部署到kubernetes

在misa86目录下执行下面的命令将应用部署到kubernetes集群上。
```
[root@master1 misa86]# helm install .
NAME:   wizened-jackal
LAST DEPLOYED: Fri May 18 17:44:41 2018
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1beta2/Deployment
NAME                   DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
wizened-jackal-misa86  1        0        0           0          0s

==> v1/Pod(related)
NAME                                    READY  STATUS             RESTARTS  AGE
wizened-jackal-misa86-5dd4fdff49-22rx9  0/1    ContainerCreating  0         0s

==> v1/Service
NAME                   TYPE       CLUSTER-IP    EXTERNAL-IP  PORT(S)  AGE
wizened-jackal-misa86  ClusterIP  10.98.43.164  <none>       80/TCP   0s


NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace default -l "app=misa86,release=wizened-jackal" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl port-forward $POD_NAME 8080:80
```

现在nginx已经部署到kubernetes集群上，本地执行提示中的命令在本地主机上访问到nginx实例。

```
export POD_NAME=$(kubectl get pods --namespace default -l "app=misa86,release=wizened-jackal" -o jsonpath="{.items[0].metadata.name}")

kubectl port-forward $POD_NAME 8080:80
在本地访问http://127.0.0.1:8080即可访问到nginx 
注意： 只能本地访问
```

#### 5.4 查看部署的relaese
```
[root@master1 misa86]# helm list
NAME          	REVISION	UPDATED                 	STATUS  	CHART       	NAMESPACE
wizened-jackal	1       	Fri May 18 17:44:41 2018	DEPLOYED	misa86-0.1.0	default  
[root@master1 misa86]# helm delete wizened-jackal
release "wizened-jackal" deleted
```

#### 5.5 打包分享
我们可以修改Chart.yaml中的helm chart配置信息，然后使用下列命令将chart打包成一个压缩文件。

```
[root@master1 misa86]# helm package .
Successfully packaged chart and saved it to: /root/misa86/misa86-0.1.0.tgz
```
#### 5.6 依赖
我们可以在charts 的目录 requirement.yaml 中定义应用所依赖的chart，例如定义对mariadb的依赖：

这功能还没屡明白

```
dependencies:
- name: mariadb
  version: 0.6.0
  repository: https://kubernetes-charts.storage.googleapis.com
```

使用helm lint .命令可以检查依赖和模板配置是否正确。


#### 5.7 http提供chart
我们在前面安装chart可以通过HTTP server的方式提供，如果不带 address 参数，那只能本机访问

把已安装的chart做server
```
[root@master1 misa86]# helm serve --address 192.168.1.181:80
Regenerating index. This may take a moment.
Now serving you on 192.168.1.181:80
```

指定目录做server
```
helm serve --address "0.0.0.0:8879" --repo-path "/root/.helm/repository/local" --url http://192.168.1.181:8879/chart/

/root/.helm/repository/local目录下得有chart文件，比如nginx1目录，下有values.yaml 和templates等
先把目录打包，库索引文件index只认打包的，  helm package nginx1

更新index文件   
helm  repo index . 
cat index.html
```

任意节点访问 192.168.1.181:80 可以看到安装的chart或者指定的chart库，点击链接即可以下载chart的压缩包。

![chart-http](http://p8whpnduw.bkt.clouddn.com/05-02-helm-3.jpg)

### 6. 注意事项

下面列举一些常见问题，和在解决这些问题时候的注意事项。

#### 6.1 服务依赖管理
所有使用helm部署的应用中如果没有特别指定chart的名字都会生成一个随机的Release name，例如romping-frog、sexy-newton等，跟启动docker容器时候容器名字的命名规则相同，而真正的资源对象的名字是在YAML文件中定义的名字，我们成为App name，两者连接起来才是资源对象的实际名字：Release name-App name。

而使用helm chart部署的包含依赖关系的应用，都会使用同一套Release name，在配置YAML文件的时候一定要注意在做服务发现时需要配置的服务地址，如果使用环境变量的话，需要像下面这样配置。

```
env:
 - name: SERVICE_NAME
   value: "{{ .Release.Name }}-{{ .Values.image.env.SERVICE_NAME }}"
这是使用了Go template的语法。至于{{ .Values.image.env.SERVICE_NAME }}的值是从values.yaml文件中获取的，所以需要在values.yaml中增加如下配置：

image:
  env:
    SERVICE_NAME: k8s-app-monitor-test
```

#### 6.2 解决本地chart依赖
在本地当前chart配置的目录下启动helm server，我们不指定任何参数，直接使用默认端口启动。
```
helm serve
将该repo加入到repo list中。

helm repo add local http://localhost:8879
在浏览器中访问http://localhost:8879可以看到所有本地的chart。

然后下载依赖到本地。

helm dependency update
这样所有的chart都会下载到本地的charts目录下。
```

#### 6.3 设置helm命令自动补全

为了方便helm命令的使用，helm提供了自动补全功能，如果使用zsh请执行：

```
source <(helm completion zsh)
如果使用bash请执行：

source <(helm completion bash)
```



### 参考文档
https://jimmysong.io/kubernetes-handbook/practice/helm.html
http://dockone.io/article/2701



