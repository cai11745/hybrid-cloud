---
layout: post
title:  openshift4 operatorhub离线部署
category: openshift，ocp4, operatorhub
description: 
---

openshift4 console 页面集成了operator管理，并支持构建私有的operator仓库。

本篇主要介绍在离线环境下如何构建一个私有的operator仓库。

ocp4 console 页面，在 Operators -- OperatorHub 页面，看到一共有121个 operator, 前几天我看的时候还是30个，应该是联网自动下载了。因为其他朋友的文章里说离线部署初始应该是看到0个。  
不过这都没关系，点开一个部署就会发现，没镜像，跑不起来。  

![operatorhub-121](./images/operator-hub-trafik/operatorhub-1-121.png)

以下记录如何手动添加一个operator 并能够成功运行，这样将能够帮助我们在离线环境下导入operator。

### 禁用默认的 OperatorSources
ocp4 安装完成后，默认安装了operatorhub， 并配置了默认源。  
把他屏蔽掉。

```bash
oc patch OperatorHub cluster --type json \
    -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'

oc get operatorhub -o yaml
# 可以看到三个source, disabled 的值变成了true，已禁用
```

然后 console 页面，operatorhub里面的内容都自动清空了。

### 创建私有 operatorhub

要获取默认OperatorSource的软件包列表，在可以联网的机器运行以下命令：

```bash
curl https://quay.io/cnr/api/v1/packages?namespace=redhat-operators> redhat-operators-packages.txt
curl https://quay.io/cnr/api/v1/packages?namespace=community-operators > community-operators-packages.txt
curl https://quay.io/cnr/api/v1/packages?namespace=certified-operators > certified-operators-packages.txt
```

都是json格式的，可以用jq命令格式化一下方便看，或者使用在线工具
` cat community-operators-packages.txt |jq  `

在线解析  
https://www.json.cn/


导入一个traefik 试试，traefik 功能同ingress和ocp的router，用于应用流量的入口  
建议测试的弄个etcd，这个traefikee后面发布比较麻烦，还需要license

```bash
[root@bastion operatorhub]# cat * |jq |grep traefikee -A 4
    "name": "certified-operators/traefikee-certified",
    "namespace": "certified-operators",
    "releases": [
      "6.0.0",
      "5.0.0",
--
    "name": "certified-operators/traefikee-redhat-certified",
    "namespace": "certified-operators",
    "releases": [
      "1.0.0"
    ],
--
    "name": "community-operators/traefikee-operator",
    "namespace": "community-operators",
    "releases": [
      "2.0.2",
      "0.4.1",
```      

这几个的区别我还不是很清楚，就选第一个来测试下。

```bash
# 格式
curl https://quay.io/cnr/api/v1/packages/<namespace>/<operator_name>/<release>
# 替换成我们第一个traefik就是
curl https://quay.io/cnr/api/v1/packages/certified-operators/traefikee-certified/6.0.0
[{"content":{"digest":"30860da0b1ccb047b06cc03f156103ee4d723c7054b863d59b758ba4b08eb80b","mediaType":"application/vnd.cnr.package.helm.v0.tar+gzip","size":106028,"urls":[]},"created_at":"2020-02-14T05:10:22","digest":"sha256:81321ce3f20ad784e983d63976efb54d64f67d121be191f49c121d6772f65c47","mediaType":"application/vnd.cnr.package-manifest.helm.v0.json","metadata":null,"package":"certified-operators/traefikee-certified","release":"6.0.0"}]

# 用这条命令获取文件. 注意 sha256/ 后面的参数，是对应上面digest 
curl -XGET https://quay.io/cnr/api/v1/packages/certified-operators/traefikee-certified/blobs/sha256/30860da0b1ccb047b06cc03f156103ee4d723c7054b863d59b758ba4b08eb80b \
    -o traefikee-certified.tar.gz

# 新建一个目录，把文件解压到下面
# 解压如果出错要么文件没下完整，要么 sha256 后面参数不对
mkdir -p manifests/traefikee-certified
tar -xf traefikee-certified.tar.gz -C manifests/traefikee-certified/

# 查看解压后的文件，如果一个 bundle.yaml ，需要做文件拆解
~ tree manifests/traefikee-certified/
manifests/traefikee-certified/
└── traefikee-certified-gg5v9t1n
    └── bundle.yaml

```

bundle.yaml 内容有 data.clusterServiceVersiondata.customResourceDefinition和data.Package 三部分。  
我们需要把他们切割成三个文件。  

第一个文件 clusterserviceversion.yaml ，注意把 apiVersion 前面的 '-' 删除
```bash
apiVersion: operators.coreos.com/v1alpha1
kind: ClusterServiceVersion
[...]
```

第二个文件 customresourcedefinition.yaml , 同样 apiVersion 前面的 '-' 删除
```bash
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
[...]
```

第三个文件 package.yaml , 同样去掉前面的 '-'
```bash
channels:
- currentCSV: traefikee-certified.v0.4.1
  name: alpha 
defaultChannel: alpha 
packageName: traefikee-certified
```

在 traefikee-certified 下新建一个版本号的目录，把clusterserviceversion.yaml和customresourcedefinition.yaml放进去  
最终目录结构如下  
```bash
~ tree manifests/
manifests/
└── traefikee-certified
    ├── 6.0.0
    │   ├── clusterserviceversion.yaml
    │   └── customresourcedefinition.yaml
    └── package.yaml
```

获取镜像，查看下 yaml 文件中定义的镜像，这个是dockerhub的镜像，我们需要把他下载来，推送到我们的私有仓库，并且在yaml文件中把image改成指向私有仓库

```bash
~ cd manifests
~ grep image -R *
traefikee-certified/6.0.0/clusterserviceversion.yaml:            "image": "store/containous/traefikee:v2.0.0",
traefikee-certified/6.0.0/clusterserviceversion.yaml:      - description: TraefikEE image to install
traefikee-certified/6.0.0/clusterserviceversion.yaml:        displayName: image
traefikee-certified/6.0.0/clusterserviceversion.yaml:        path: image
traefikee-certified/6.0.0/clusterserviceversion.yaml:    mediatype: image/png
traefikee-certified/6.0.0/clusterserviceversion.yaml:                image: containous/traefikee-operator:v0.4.1
traefikee-certified/6.0.0/clusterserviceversion.yaml:                imagePullPolicy: IfNotPresent
traefikee-certified/6.0.0/clusterserviceversion.yaml:                image: containous/traefikee-operator:v0.4.1
traefikee-certified/6.0.0/clusterserviceversion.yaml:                imagePullPolicy: IfNotPresent
```

拉取镜像，改tag，推到私有仓库，docker.io 拉不动换成azure的加速器试试，嗖嗖的  
```bash
podman pull docker.io/containous/traefikee-operator:v0.4.1
podman pull docker.io/store/containous/traefikee:v2.0.0
# 或者 podman pull dockerhub.azk8s.cn/containous/traefikee-operator:v0.4.1
 podman tag docker.io/containous/traefikee-operator:v0.4.1 registry.example.com:5000/containous/traefikee-operator:v0.4.1

 podman tag docker.io/store/containous/traefikee:v2.0.0 registry.example.com:5000/containous/traefikee:v2.0.0

 podman login https://registry.example.com:5000 -u root -p password 
 podman push registry.example.com:5000/containous/traefikee-operator:v0.4.1
 podman  push registry.example.com:5000/containous/traefikee:v2.0.0 
```

这边是 Azure China docker 加速器，有docker.io gcr.io quay.io 下载不了的镜像可以替换试试

|global|proxy in China|format|example|
|-|-|-|-|
|dockerhub(docker.io)|dockerhub.azk8s.cn|dockerhub.azk8s.cn/repo-name/image-name:version|dockerhub.azk8s.cn/microsoft/azure-cli:2.0.61dockerhub.azk8s.cn/library/nginx:1.15|
|gcr.io|gcr.azk8s.cn|gcr.azk8s.cn/repo-name/image-name:version|gcr.azk8s.cn/google_containers/hyperkube-amd64:v1.13.5|
|quay.io|quay.azk8s.cn|quay.azk8s.cn/repo-name/image-name:version|quay.azk8s.cn/deis/go-dev:v1.10.0|

修改yaml 文件，把images: 改成指向私有仓库，或者 ImageContentSourcePolicy 把外部仓库地址指向内部，不过这个yaml images 里面缺省 了docker.io 不确定  ImageContentSourcePolicy 还是否有效，直接改yaml文件来的比较靠谱些。

```bash
# 修改yaml文件
grep image -rl . |xargs sed -i 's/containous\/traefikee-operator\:v0.4.1/registry.example.com:5000\/containous\/traefikee-operator\:v0.4.1/g'
grep image -rl . |xargs sed -i 's/store\/containous\/traefikee:v2.0.0/registry.example.com:5000\/containous\/traefikee\:v2.0.0/g'

# 确认下已经改过来了
 grep image -R * 
```

在manifests 目录同级创建文件 custom-registry.Dockerfile
```bash
FROM registry.redhat.io/openshift4/ose-operator-registry:v4.2.24 AS builder

COPY manifests manifests

RUN /bin/initializer -o ./bundles.db

FROM registry.access.redhat.com/ubi7/ubi

COPY --from=builder /registry/bundles.db /bundles.db
COPY --from=builder /usr/bin/registry-server /registry-server
COPY --from=builder /bin/grpc_health_probe /bin/grpc_health_probe

EXPOSE 50051

ENTRYPOINT ["/registry-server"]

CMD ["--database", "bundles.db"]

```

使用podman命令构建镜像，并推送仓库
```bash
~ ls
custom-registry.Dockerfile  manifests

podman build -f custom-registry.Dockerfile -t registry.example.com:5000/ocp4/custom-registry 
podman push registry.example.com:5000/ocp4/custom-registry  
```

如果出现这个错误，是clusterserviceversion.yaml  customresourcedefinition.yaml这两个文件没有切割好  
```bash
FATA[0000] permissive mode disabled                      error="error loading manifests from directory: error checking provided apis in bundle : couldn't find containo.us/v1alpha1/Traefikee (traefikees) in bundle. found: map[]"
```

创建 my-operator-catalog.yaml 文件
```bash
# 文件内容
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: my-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: My Operator Catalog
  sourceType: grpc
  image: registry.example.com:5000/ocp4/custom-registry  

# 创建
oc create -f my-operator-catalog.yaml
```

正常情况应该这样。如果不正常看下文
```bash
[root@bastion ~]# oc get pods -n openshift-marketplace
NAME                                   READY   STATUS    RESTARTS   AGE
marketplace-operator-554cffcfd-bgxcv   1/1     Running   12         23d
my-operator-catalog-hmcdj              1/1     Running   4          10h
[root@bastion ~]# oc get catalogsource -n openshift-marketplace
NAME                  DISPLAY               TYPE   PUBLISHER   AGE
my-operator-catalog   My Operator Catalog   grpc               10h
[root@bastion ~]# oc get packagemanifest -n openshift-marketplace
NAME                  CATALOG               AGE
traefikee-certified   My Operator Catalog   10h
```

如果看不到新的pod，而且 packagemanifest 也没有，检查下这里面的pod是否正常，不正常就把pod删了重启下
```bash
oc -n openshift-operator-lifecycle-manager get pod
```

控制台 Operators - Installed Operators 里面 Package Server 的status "cannot update" ,不是issue。  
https://access.redhat.com/solutions/4937981

然后看console 控制台，traefik出来了，安装试试
![trafik1.png](./images/operator-hub-trafik/trafik1.png)

traefik 介绍页
![trafik-install.png](./images/operator-hub-trafik/trafik-install.png)

安装参数页，不要选default，会在所有项目下创建
![trafik-install-2.png](./images/operator-hub-trafik/trafik-install-2.png)

这样，traefik operator装完了，后面如果要安装traefik，需要添加一个  kind: Traefikee 的资源
![traefik-installed.png](./images/operator-hub-trafik/traefik-installed.png)

Installed Operators 页面点开 Traefikee Operator，选Create Instance，创建之后才是真正创建了traefik，这边发现我选择的是traefik的企业版，还要搞license及一堆初始化动作，页面有提示。 license 页面打不开。。。 看下pod已经有了，到此为止。

```bash
[root@bastion operatorhub]# oc -n kube-system get pod
NAME                                  READY   STATUS     RESTARTS   AGE
traefikee-controller-0                0/1     Pending    0          19m
traefikee-operator-6bffccfc76-rkgmt   2/2     Running    0          22m
traefikee-proxy-5f47757f84-rj66d      0/1     Init:0/1   0          19m
```

### 一次添加多个operator及版本

一次添加多个的版本，在做镜像之前， manifests 目录里面可以写多个operator和多个版本，可以参照这个

https://www.openshift.com/blog/openshift-4-3-managing-catalog-sources-in-the-openshift-web-console


###  参考文档
https://docs.openshift.com/container-platform/4.2/operators/olm-restricted-networks.html#olm-restricted-networks-operatorhub_olm-restricted-networks

https://www.cnblogs.com/ericnie/p/11777384.html?from=timeline&isappinstalled=0

https://github.com/wangzheng422/docker_env/blob/master/redhat/ocp4/4.2.disconnect.operator.md


关注我的github，后续更新会同步到github

https://github.com/cai11745/k8s-ocp-yaml

