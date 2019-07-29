---
layout: post
title:  kubernetes 安装istio
category: kubernetes,istio
description: 
---

基于kubernetes环境安装isio


### 1. 下载与安装istio

前提：已有k8s集群

下载istio，步骤参考 https://istio.io/zh/docs/setup/kubernetes/download/  
```bash
curl -L https://git.io/getLatestIstio | ISTIO_VERSION=1.2.2 sh -
cd istio-1.2.2
# 把 istioctl 客户端加入 PATH 环境变量，如果是 macOS 或者 Linux，可以这样实现：
export PATH=$PWD/bin:$PATH
```

在k8s安装istio，步骤参考 https://istio.io/zh/docs/setup/kubernetes/install/kubernetes/  
```bash
# 使用 kubectl apply 安装 Istio 的自定义资源定义（CRD），几秒钟之后，CRD 被提交给 Kubernetes 的 API-Server：
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
# 使用 mutual TLS 的宽容模式，所有的服务会同时允许明文和双向 TLS 的流量。
kubectl apply -f install/kubernetes/istio-demo.yaml
# 确认部署结果
# 如果你的集群在一个没有外部负载均衡器支持的环境中运行（例如 Minikube），istio-ingressgateway 的 EXTERNAL-IP 会是 <pending>。要访问这个网关，只能通过服务的 NodePort 或者使用端口转发来进行访问。
kubectl get svc -n istio-system
kubectl get pods -n istio-system
```

### 2. 部署demo应用bookinfo

参考地址 https://istio.io/zh/docs/examples/bookinfo/  

#### bookinfo 简介
部署一个样例应用，它由四个单独的微服务构成，用来演示多种 Istio 特性。这个应用模仿在线书店的一个分类，显示一本书的信息。页面上会显示一本书的描述，书籍的细节（ISBN、页数等），以及关于这本书的一些评论。

Bookinfo 应用分为四个单独的微服务：
productpage ：productpage 微服务会调用 details 和 reviews 两个微服务，用来生成页面。
details ：这个微服务包含了书籍的信息。
reviews ：这个微服务包含了书籍相关的评论。它还会调用 ratings 微服务。
ratings ：ratings 微服务中包含了由书籍评价组成的评级信息。
reviews 微服务有 3 个版本：

v1 版本不会调用 ratings 服务。  
v2 版本会调用 ratings 服务，并使用 1 到 5 个黑色星形图标来显示评分信息。  
v3 版本会调用 ratings 服务，并使用 1 到 5 个红色星形图标来显示评分信息。  
下图展示了这个应用的端到端架构。  
![avatar](https://istio.io/docs/examples/bookinfo/noistio.svg)
Istio 注入之前的 Bookinfo 应用  
Bookinfo 是一个异构应用，几个微服务是由不同的语言编写的。这些服务对 Istio 并无依赖，但是构成了一个有代表性的服务网格的例子：它由多个服务、多个语言构成，并且 reviews 服务具有多个版本。

#### 部署应用
要在 Istio 中运行这一应用，无需对应用自身做出任何改变。我们只要简单的在 Istio 环境中对服务进行配置和运行，具体一点说就是把 Envoy sidecar 注入到每个服务之中。这个过程所需的具体命令和配置方法由运行时环境决定，而部署结果较为一致，如下图所示：
![avatar](https://istio.io/docs/examples/bookinfo/withistio.svg)
所有的微服务都和 Envoy sidecar 集成在一起，被集成服务所有的出入流量都被 sidecar 所劫持，这样就为外部控制准备了所需的 Hook，然后就可以利用 Istio 控制平面为应用提供服务路由、遥测数据收集以及策略实施等功能。

```bash
# 如果集群用的是手工 Sidecar 注入，使用如下命令：
kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/platform/kube/bookinfo.yaml)
# istioctl kube-inject 命令用于在在部署应用之前修改 bookinfo.yaml。

# 如果集群使用的是自动 Sidecar 注入，为 default 命名空间打上标签 istio-injection=enabled。
$ kubectl label namespace default istio-injection=enabled

# 使用 kubectl 部署简单的服务
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# 确认所有的服务和 Pod 都已经正确的定义和启动：
kubectl get services
kubectl get pods   # 每个pod里有两个容器

# 要确认 Bookinfo 应用程序正在运行，请通过某个 pod 中的 curl 命令向其发送请求，例如来自 ratings：
 kubectl exec -it $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"
<title>Simple Bookstore App</title>
```

####确定 Ingress 的 IP 和端口
现在 Bookinfo 服务启动并运行中，你需要使应用程序可以从外部访问 Kubernetes 集群，例如使用浏览器。一个 Istio Gateway 应用到了目标中。  
```bash
# 为应用程序定义入口网关：
 kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

# 确认网关创建完成：
$ kubectl get gateway
NAME               AGE
bookinfo-gateway   32s

# 根据文档设置访问网关的 INGRESS_HOST 和 INGRESS_PORT 变量。确认并设置。
# istio-ingressgateway svc EXTERNAL-IP 未设置，我们通过nodeport方式访问。
# 即访问istio-ingressgateway 80端口的nodeport，路径在 bookinfo-gateway.yaml 中有定义
# 浏览器访问 nodeip:31380/productpage 来浏览应用的 Web 页面。如果刷新几次应用的页面，就会看到 productpage 页面中会随机展示 reviews 服务的不同版本的效果（红色、黑色的星形或者没有显示）。reviews 服务出现这种情况是因为我们还没有使用 Istio 来控制版本的路由。
```

#### 应用缺省目标规则
在使用 Istio 控制 Bookinfo 版本路由之前，你需要在目标规则中定义好可用的版本，命名为 subsets 。 
运行以下命令为 Bookinfo 服务创建的默认的目标规则：
如果不需要启用双向TLS，请执行以下命令：  
` $ kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml `

如果需要启用双向 TLS，请执行以下命令：
` $ kubectl apply -f samples/bookinfo/networking/destination-rule-all-mtls.yaml `

等待几秒钟，等待目标规则生效。  
你可以使用以下命令查看目标规则：  
` $ kubectl get destinationrules -o yaml `

```bash
 DestinationRule 定义了应用有几个可用版本，每个版本对应的pod label 是什么内容。
 至于请求到底发到哪个版本，是在 VirtualService 中定义。
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
```


以上istio demo应用 bookinfo部署完成，以下开始体验istio的特性。

### 流量管理

#### 请求路由
此任务将说明如何将请求动态路由到多个版本的微服务。

要仅路由到一个版本，请应用为微服务设置默认版本的 virtual service。在这种情况下，virtual service 将所有流量路由到每个微服务的 v1 版本。

前提：已经应用 destination rule

运行以下命令以应用 virtual service：
` kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml `

由于配置传播最终是一致的，因此请等待几秒钟以使虚拟服务生效。

使用以下命令显示已定义的路由：

`  kubectl get virtualservices -o yaml` 

还可以使用以下命令显示相应的 `subset` 定义：

`kubectl get destinationrules -o yaml `

已将 Istio 配置为路由到 Bookinfo 微服务的 `v1` 版本，最重要的是 `reviews` 服务的 v1 版本。

测试新路由配置

通过再次刷新 Bookinfo 应用程序的 `/productpage` 轻松测试新配置

访问页面 nodeip:31380/productpage 

无论您刷新多少次，页面的评论部分都不会显示评级星标。这是因为您将 Istio 配置为将评论服务的所有流量路由到版本 `reviews:v1`，并且此版本的服务不访问星级评分服务。

#### 基于用户身份的路由

接下来，您将更改路由配置，以便将来自特定用户的所有流量路由到特定服务版本。在这种情况下，来自名为 Jason 的用户的所有流量将被路由到服务 `reviews:v2`。

请注意，Istio 对用户身份没有任何特殊的内置机制。这个例子的基础在于， `productpage` 服务在所有针对 `reviews` 服务的调用请求中 都加自定义的 HTTP header，从而达到在流量中对最终用户身份识别的这一效果。

请记住，`reviews:v2` 是包含星级评分功能的版本。

运行以下命令以启用基于用户的路由：

` kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml `

查看路由规则

` kubectl get virtualservice reviews -o yaml `

在 Bookinfo 应用程序的 `/productpage` 上，以用户 `jason` 身份登录。

刷新浏览器。你看到了什么？星级评分显示在每个评论旁边。

以其他用户身份登录（选择您想要的任何名称）。

刷新浏览器。现在星星消失了。这是因为除了 Jason 之外，所有用户的流量都被路由到 `reviews:v1`。

您已成功配置 Istio 以根据用户身份路由流量。

#### 流量转移

本任务将演示如何逐步将流量从一个版本的微服务迁移到另一个版本。例如，您可以将流量从旧版本迁移到新版本。

一个常见的用例是将流量从一个版本的微服务逐渐迁移到另一个版本。在 Istio 中，您可以通过配置一系列规则来实现此目标，这些规则将一定百分比的流量路由到一个或另一个服务。在此任务中，您将 50％ 的流量发送到 `reviews:v1`，另外 50％ 的流量发送到 `reviews:v3`。然后将 100％ 的流量发送到 `reviews:v3` 来完成迁移。

1. 首先，运行此命令将所有流量路由到 `v1` 版本的各个微服务。

   `  kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml `

   

2. 在浏览器中打开 Bookinfo 站点。 URL 为 `http://$GATEWAY_URL/productpage`，其中 `$GATEWAY_URL` 是 ingress 的外部 IP 地址， 其描述参见 [Bookinfo](https://istio.io/zh/docs/examples/bookinfo/#确定-ingress-的-ip-和端口)。

   请注意，不管刷新多少次，页面的评论部分都不会显示评级星号。这是因为 Istio 被配置为将 reviews 服务的的所有流量都路由到了 `reviews:v1` 版本， 而该版本的服务不会访问带星级的 ratings 服务。

3. 使用下面的命令把 50% 的流量从 `reviews:v1` 转移到 `reviews:v3`：

   `  kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml `

   

   等待几秒钟以让新的规则传播到代理中生效。

您可以通过修改规则将 90% 的流量路由到 v3，这样能看到更多带红色星级的评价。

如果您认为 `reviews:v3` 微服务已经稳定，你可以通过应用此 virtual service 将 100% 的流量路由到 `reviews:v3`：

` ` `kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-v3.yaml `



现在，当您刷新 `/productpage` 时，您将始终看到带有红色星级评分的书评。

#### TCP流量转移

本任务展示了如何优雅的将微服务中的 TCP 流量从一个版本迁移到另一个版本。例如将 TCP 流量从旧版本迁移到一个新版本。这是一个常见的场景。在 Istio 中可以通过定义一组规则，将 TCP 流量在不同服务之间进行分配。在这一任务中，首先把 100% 的 TCP 流量发送到 `tcp-echo:v1`；下一步就是使用 Istio 的路由分配能力，把 20% 的流量分配到 `tcp-echo:v2` 服务之中。

应用基于权重的 TCP 路由

第一个步骤是部署 `tcp-echo` 微服务的 `v1` 版本。

1. 使用 `kubectl` 进行服务部署即可：

`  kubectl apply -f samples/tcp-echo/tcp-echo-services.yaml `



2. 下一步，把所有目标是 `tcp-echo` 微服务的 TCP 流量路由到 `v1` 版本：

`  kubectl apply -f samples/tcp-echo/tcp-echo-all-v1.yaml `



3. 确认 `tcp-echo` 服务已经启动并开始运行。

下面的 `$INGRESS_HOST` 变量中保存了 Ingress 的外部 IP 地址，由于通过nodeport方式访问，写任意节点IP。可以使用下面的命令来获取 `$INGRESS_PORT` 的值：

` export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].port}') `



向 `tcp-echo` 微服务发送一些 TCP 流量：

```bash
$ for i in {1..10}; do \
docker run -e INGRESS_HOST=$INGRESS_HOST -e INGRESS_PORT=$INGRESS_PORT -it --rm busybox sh -c "(date; sleep 1) | nc $INGRESS_HOST $INGRESS_PORT"; \
done

one Mon Nov 12 23:24:57 UTC 2018
one Mon Nov 12 23:25:00 UTC 2018
one Mon Nov 12 23:25:02 UTC 2018
one Mon Nov 12 23:25:05 UTC 2018
one Mon Nov 12 23:25:07 UTC 2018
one Mon Nov 12 23:25:10 UTC 2018
one Mon Nov 12 23:25:12 UTC 2018
one Mon Nov 12 23:25:15 UTC 2018
one Mon Nov 12 23:25:17 UTC 2018
one Mon Nov 12 23:25:19 UTC 2018
```



不难发现，所有的时间戳都有一个 `one` 前缀，这代表所有访问 `tcp-echo` 服务的流量都被路由到了 `v1` 版本。

1. 用下面的命令把 20% 的流量从 `tcp-echo:v1` 转移到 `tcp-echo:v2`：

   ```bash
   $ kubectl apply -f samples/tcp-echo/tcp-echo-20-v2.yaml
   ```

   

   需要一定时间完成新规则的传播和生效。

2. 确认该规则已经完成替换：

   ```bash
   $ kubectl get virtualservice tcp-echo -o yaml
   
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: tcp-echo
     ...
   spec:
     ...
     tcp:
     - match:
       - port: 31400
       route:
       - destination:
           host: tcp-echo
           port:
             number: 9000
           subset: v1
         weight: 80
       - destination:
           host: tcp-echo
           port:
             number: 9000
           subset: v2
         weight: 20
   ```

   

3. 向 `tcp-echo` 微服务发送更多 TCP 流量：

   ```bash
   $ for i in {1..10}; do \
   docker run -e INGRESS_HOST=$INGRESS_HOST -e INGRESS_PORT=$INGRESS_PORT -it --rm busybox sh -c "(date; sleep 1) | nc $INGRESS_HOST $INGRESS_PORT"; \
   done
   
   one Mon Nov 12 23:38:45 UTC 2018
   two Mon Nov 12 23:38:47 UTC 2018
   one Mon Nov 12 23:38:50 UTC 2018
   one Mon Nov 12 23:38:52 UTC 2018
   one Mon Nov 12 23:38:55 UTC 2018
   two Mon Nov 12 23:38:57 UTC 2018
   one Mon Nov 12 23:39:00 UTC 2018
   one Mon Nov 12 23:39:02 UTC 2018
   one Mon Nov 12 23:39:05 UTC 2018
   one Mon Nov 12 23:39:07 UTC 2018
   ```

   

   现在应该会看到，输出内容中有 20% 的时间戳前缀为 `two`，这意味着 80% 的流量被路由到 `tcp-echo:v1`，其余 20% 流量被路由到了 `v2`。

理解原理

这个任务里，用 Istio 的权重路由功能，把一部分访问 `tcp-echo` 服务的 TCP 流量被从旧版本迁移到了新版本。容器编排平台中的版本迁移使用的是对特定组别的实例进行伸缩来完成对流量的控制的，两种迁移方式显然大相径庭。

#### 设置请求超时

- 跟随[安装指南](https://istio.io/zh/docs/setup)设置 Istio。

- 部署的示例应用程序 [Bookinfo](https://istio.io/zh/docs/examples/bookinfo/)包含[应用缺省目标规则](https://istio.io/zh/docs/examples/bookinfo/#应用缺省目标规则)。

- 使用下面的命令初始化应用的版本路由：

  ```bash
  $ kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
  ```

  

请求超时

可以在[路由规则](https://istio.io/zh/docs/reference/config/istio.networking.v1alpha3/#httproute)的 `timeout` 字段中来给 http 请求设置请求超时。缺省情况下，超时被设置为 15 秒钟，本文任务中，会把 `reviews`服务的超时设置为一秒钟。为了能观察设置的效果，还需要在对 `ratings` 服务的调用中加入两秒钟的延迟。

1. 到 `reviews:v2` 服务的路由定义：

   ```bash
   $ kubectl apply -f - <<EOF
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: reviews
   spec:
     hosts:
       - reviews
     http:
     - route:
       - destination:
           host: reviews
           subset: v2
   EOF
   ```

   

2. 在对 `ratings` 服务的调用中加入两秒钟的延迟：

   ```bash
   $ kubectl apply -f - <<EOF
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: ratings
   spec:
     hosts:
     - ratings
     http:
     - fault:
         delay:
           percent: 100
           fixedDelay: 2s
       route:
       - destination:
           host: ratings
           subset: v1
   EOF
   ```

   

3. 用浏览器打开网址 `http://$GATEWAY_URL/productpage`，浏览 Bookinfo 应用。

   这时应该能看到 Bookinfo 应用在正常运行（显示了评级的星形符号），但是每次刷新页面，都会出现两秒钟的延迟。

4. 接下来在目的为 `reviews:v2` 服务的请求加入一秒钟的请求超时：

   ```bash
   $ kubectl apply -f - <<EOF
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: reviews
   spec:
     hosts:
     - reviews
     http:
     - route:
       - destination:
           host: reviews
           subset: v2
       timeout: 0.5s
   EOF
   ```

   

5. 刷新 Bookinfo 的 Web 页面。

   这时候应该看到一秒钟就会返回，而不是之前的两秒钟，但 `reviews` 的显示已经不见了。

   

   即使超时配置为半秒，响应需要 1 秒的原因是因为 `productpage` 页面服务中存在硬编码重试，因此它在返回之前调用 `reviews` 服务超时两次。

理解原理

上面的任务中，使用 Istio 为调用 `reviews` 微服务的请求中加入了一秒钟的超时控制，覆盖了缺省的 15 秒钟设置。页面刷新时，`reviews` 服务后面会调用 `ratings` 服务，使用 Istio 在对 `ratings` 的调用中注入了两秒钟的延迟，这样就让 `reviews` 服务要花费超过一秒钟的时间来调用 `ratings` 服务，从而触发了我们加入的超时控制。

这样就会看到 Bookinfo 的页面（ 页面由 `reviews` 服务生成）上没有出现 `reviews` 服务的显示内容，取而代之的是错误信息：**Sorry, product reviews are currently unavailable for this book** ，出现这一信息的原因就是因为来自 `reviews` 服务的超时错误。

如果测试了[故障注入任务](https://istio.io/zh/docs/tasks/traffic-management/fault-injection/)，会发现 `productpage` 微服务在调用 `reviews` 微服务时，还有自己的应用级超时设置（三秒钟）。注意这里我们用路由规则设置了一秒钟的超时。如果把超时设置为超过三秒钟（例如四秒钟）会毫无效果，这是因为内部的服务中设置了更为严格的超时要求。更多细节可以参见[故障处理 FAQ](https://istio.io/zh/docs/concepts/traffic-management/#faq) 的相关内容。

还有一点关于 Istio 中超时控制方面的补充说明，除了像本文一样在路由规则中进行超时设置之外，还可以进行请求一级的设置，只需在应用的外发流量中加入 `x-envoy-upstream-rq-timeout-ms` Header 即可。在这个 Header 中的超时设置单位是毫秒而不是秒。

清理

- 移除应用的路由规则：

  ```bash
  $ kubectl delete -f samples/bookinfo/networking/virtual-service-all-v1.yaml
  ```

  