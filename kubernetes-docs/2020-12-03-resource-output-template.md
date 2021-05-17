## 标准化输出 openshift/k8s 资源指定内容

当我们使用 kubectl get 相关资源，可以使用 -o yaml 或者 -o json 查看完整内容，如何获取我们想要的关键内容，k8s 提供了参数 -o=go-template 及 -o jsonpath 可以很好的进行标准输出。

比如获取所有 node 的CPU MEM 信息。

以下内容同时适用于 openshift 和 k8s 平台。

### -o go-template




### 参考文档

https://kubernetes.io/docs/reference/kubectl/jsonpath/
