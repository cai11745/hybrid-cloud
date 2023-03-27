### Kubernetes & Openshift 实施与学习记录

* 记录在学习及项目实施中用到的k8s/openshift相关技术，做一些解读 。
* gitbook页面有搜索，可以快速定位到自己需要的内容。
* 后续会添加一些公有云相关内容，所以名字改成了hybird-cloud。 2022-09-28

**扫一扫，关注微信公众号，不迷路，实时分享容器平台技术。或者直接搜 老菜 **

<div align="center"><img width="300" height="300" src="./image/gongzhonghao.jpeg"/></div>


#### [gitbook阅读地址点我](https://misa.gitbook.io/k8s-ocp-yaml/)
#### [kubernetes openshift troubleshooting故障诊断 点我](./kubernetes-docs/2019-07-27-openshift-k8s-troubleshooting.md)
#### OCP4 用户手册（openshift4 相关内容将更新到隔壁目录）
https://github.com/cai11745/ocp4-userguide
---

目录
* 微软云 Azure
  * [2022-10-18-Azure Portal创建k8s集群](microsoft-azure/2022-10-18-create-azure-kubernetes-service.md)
  * [2022-10-30-Azure容器镜像仓库](microsoft-azure/2022-10-30-create-container-registry.md)
  * [2023-03-08-基于Policy实现tag批量分配与继承](microsoft-azure/2023-03-08-Azure-policy-manage-tags.md)
  * [2023-02-24-Terraform 安装与简单demo](terraform/2023-02-24-terraform-install-and-simple-demo.md)
  * [2023-03-10-Terraform 创建 private AKS](terraform/2023-03-10-terraform-create-private-aks.md)
  * [2023-03-22-Terraform 离线环境使用](terraform/2023-03-22-terraform-offline-install.md)
  * [2023-03-24-Terraform 踩坑记1-InternalOperationError](terraform/2023-03-24-terraform-debug-InternalOperationError.md)


* yaml文件书写注意项
  * [2018-05-29-yaml文件来源](2018-05-29-yaml-from+write-note.md)
  * [2018-05-29-多资源对象写法](2018-05-29-multi-kind-list.md)

* kubernetes docs
  * [2020-04-24-kubectl-debug插件及openshift debug模式](kubernetes-docs/2020-04-24-kubectl-debug-command.md)
  * [2020-04-23-k8s 利用subpathexpr处理日志落盘](kubernetes-docs/2020-04-23-volume-subpathexpr.md)
  * [2020-04-14-metrics-server 轻量级监控](kubernetes-docs/2020-04-14-metrics-server.md)
  * [2020-03-31-helm3 全新版本带来了什么](kubernetes-docs/2020-03-31-helm3-whats-new.md)
  * [2019-07-27-k8s openshift troubleshooting故障诊断](kubernetes-docs/2019-07-27-openshift-k8s-troubleshooting.md)
  * [2020-02-17-k8s CIS benchmark 安全基准测试](kubernetes-docs/2020-02-17-cis-benchmark-for-kubernetes.md)
  * [2019-10-14-kubernetes 1.16 单机版在线安装](kubernetes-docs/2019-10-14-kubernetes-1.16-install-online.md)
  * [2019-04-19-kubernetes 1.14 离线安装](kubernetes-docs/2019-04-19-kubernetes-1.14-install-offline.md) 
  * [2018-11-20-kubernetes dashboard 免密登陆](kubernetes-docs/2018-11-20-kubernetes-dashboard-enable-http.md)
  * [2018-04-07-kubernetes1.10 install offline](kubernetes-docs/2018-04-07-kubernetes-1.10-install-offline.md)
  * [2018-04-02-kubernetes1.9 install online](kubernetes-docs/2018-04-02-kubernetes-1.9-install-online.md)
  * [2018-04-04-kubernetes1.9 HA install online](kubernetes-docs/2018-04-04-kubernetes-1.9-HA-install-online.md)
  * [2018-05-02-helm2 install](kubernetes-docs/2018-05-02-install-helm.md)

* openshift docs
  * [2021-05-17-podman添加开机自启](openshift-docs/2021-05-17-podman-auto-restart-systemd.md)
  * [2020-06-23-openshift4.4 在线安装（包含allinone）静态ip](ocp4/2020-02-25-openshift4.4-install-online-staticIP-allinone.md)
  * [2020-02-25-openshift 4.3 离线安装--DHCP方式](ocp4/2020-02-25-openshift4.3-install-offline-dhcp.md)
  * [2020-03-18-openshift4 operatorhub 离线部署](ocp4/2020-03-18-openshift4-offline-install-operatorhub.md)
  * [2019-07-02-openshift origin 3.11 在线安装](openshift-docs/2019-07-02-openshift311-origin在线部署.md)
  * [2019-09-24-openshift 对接AD域作为用户系统](openshift-docs/2019-09-24-openshift311-AD.md)
  * [2019-11-13-openshift jenkins slave pod 自定义模板](openshift-docs/2019-11-13-openshift3.11-jenkins-slave-pod-template.md)

* 应用(deployment,rc,rs，volume,readiness,liveness)
  * [2018-05-31-deployment,rc,rs控制器](application/2018-05-31-deployment-rc-rs.md)
  * [2018-05-31-volume 容器存储](application/2018-05-31-volume.md)
  * [2018-07-05-liveness readiness 健康检查](application/2018-07-05-livemess-readiness.md)

* Openshift独有resource
  * [2019-08-08-template模板解读](openshift-docs/2019-08-08--how-to-write-openshift-template.md)

* docker相关文档
  * [2017-08-10-dockerfile 书写注意](docker-docs/2017-08-10-dockerfile-notes.md)
  * [2017-08-10-dockerfile examples](docker-docs/2017-08-10-dockerfile-examples.md)
  * [2017-07-19-dockerfile 命令](docker-docs/2017-07-19-dockerfile-command.md)

* 容器云监控prometheus
  * [2019-10-22-安装部署与监控ingress-controller](prometheus/2019-10-22-prometheus-1-install-and-metricsIngress.md)
  * [2020-05-30-组件功能介绍与监控数据来源](prometheus/2020-05-30-prometheus-2-components-roles.md)
  
* 中间件
  * [2020-03-30-kafka的安装与开启ACL权限控制](middleware/2020-03-30-kafka-install.md)

* others
  * [2020-06-06-树莓派安装docker环境](others/2020-06-06-树莓派安装docker环境.md)
  
#### 联系方式
* 邮箱: 3162003@qq.com
* QQ  : 3162003

有问题可以联系我或者github提issue  
