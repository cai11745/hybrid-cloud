### Kubernetes & Openshift yaml 解读 及部署实施记录

* 记录在学习及项目实施中用到的k8s及openshift yaml文件，做一些解读。 及部署实施记录。
* gitbook页面有搜索，可以快速定位到自己需要的内容。

#### [gitbook阅读地址点我](https://misa.gitbook.io/k8s-ocp-yaml/)
#### [kubernetes openshift troubleshooting故障诊断 点我](./kubernetes-docs/2019-07-27-openshift-k8s-troubleshooting.md)
---
#### 联系方式
* 邮箱: 3162003@qq.com
* 微信: misa_cf
* QQ  : 3162003

有问题可以联系我或者github提issue  

目录
* yaml文件书写注意项
  * [yaml文件来源](2018-05-29-yaml-from+write-note.md)
  * [多资源对象写法](2018-05-29-multi-kind-list.md)

* 应用(deployment,rc,rs，volume,readiness,liveness)
  * [deployment,rc,rs控制器](application/2018-05-31-deployment-rc-rs.md)
  * [volume 容器存储](application/2018-05-31-volume.md)
  * [liveness readiness 健康检查](application/2018-07-05-livemess-readiness.md)
  
  * [rc未完成]()
  * [Daemonset未完成]()

* 存储(pv,pvc)


* Openshift独有resource
  * [route未完成]()
  * [template模板解读](openshift-docs/2019-08-08--how-to-write-openshift-template.md)

* kubernetes docs
  * [kubernetes 1.16 单机版在线安装](kubernetes-docs/2019-10-14-kubernetes-1.16-install-online.md)
  * [kubernetes 1.14 离线安装](kubernetes-docs/2019-04-19-kubernetes-1.14-install-offline.md) 
  * [kubernetes dashboard 免密登陆](kubernetes-docs/2018-11-20-kubernetes-dashboard-enable-http.md)
  * [kubernetes1.10 install offline](kubernetes-docs/2018-04-07-kubernetes-1.10-install-offline.md)
  * [kubernetes1.9 install online](kubernetes-docs/2018-04-02-kubernetes-1.9-install-online.md)
  * [kubernetes1.9 HA install online](kubernetes-docs/2018-04-04-kubernetes-1.9-HA-install-online.md)
  * [helm install](kubernetes-docs/2018-05-02-install-helm.md)
  * [k8s openshift troubleshooting故障诊断](kubernetes-docs/2019-07-27-openshift-k8s-troubleshooting.md)
 

* openshift docs
  * [openshift origin 3.11 在线安装](openshift-docs/2019-07-02-openshift311-origin在线部署.md)
  * [openshift 对接AD域作为用户系统](openshift-docs/2019-09-24-openshift311-AD.md)
  * [openshift jenkins slave pod 自定义模板](openshift-docs/2019-11-13-openshift3.11-jenkins-slave-pod-template.md)


* docker相关文档
  * [dockerfile 书写注意](docker-docs/2017-08-10-dockerfile-notes.md)
  * [dockerfile examples](docker-docs/2017-08-10-dockerfile-examples.md)
  * [dockerfile 命令](docker-docs/2017-07-19-dockerfile-command.md)

