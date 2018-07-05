# yaml 文件导入导出与书写规则

为什么采用yaml，视觉上更直观，但是必须处理好缩进/对齐。

通过 yaml 文件创建应用等资源，最好基于已有的文件修改，不要自己手动书写，容易出错。下面介绍 yaml 文件的常用查询途径及导入导出方法。

## yaml 文件来源

### 本文档

哈，文中写出的基本都是经过验证的。

### [kubernetes 官网](https://kubernetes.io/docs)

需要科学上网，善用搜索，基本没有

### [openshift 官网](https://docs.openshift.com/container-platform/3.9/welcome/index.html)

openshift 是红帽redhat基于kubernetes的二次开发版本，在部署方案及使用上更便捷。
且增加了一些比较方便的资源格式，比如route dc template imagestream 等

### kubectl 命令

通过命令，只输出 deployment 文件，不创建

```bash
[root@master1 ~]# kubectl run tomcat11 --image=tomcat:8.5 --replicas=2 --port=8080 --dry-run -o yaml

tomcat11 为deployment 名称
--image 指定应用镜像
--replicas pod数量，即应用实例数
--port 应用port
--dry-run 测试命令能够正常执行，不会创建对象
-o yaml 把资源输出成yaml格式
```

注意： 如果是openshift 环境, oc run 命令生成的是deploymentconfig，即dc。 如果 deployment 可以用 kubectl 命令

### 通过已有资源导出

kubernetes

```bash
root@instance-1:~# kubectl get deployment tomtest -o yaml

把无用的一些状态信息删掉
```

openshift

openshift 带有一个 export 命令可以导出资源

```bash
[root@master ~]# oc export svc np-31006 -o yaml
```

但是比如svc，导出会把 nodeport 的信息给丢了。。。 - -!

## yaml 书写注意项

下面是本人使用中的一些心得

### 缩进

缩进很重要，重要，重要！

这也是本人重新梳理文档的原因，之前在记录时候使用了word，但是后续使用的时候发现缩进失效了，所有内容前面的空格没了，文件废了。

### 多port 多volume

 ports，volumeMounts，volumes、env、securityContext等，有多个子项的时候。以上参数只能出现一次。 比如

 ```bash
 错误示例：
          volumeMounts:
          - mountPath: /home/netbank/share
            name: share
          volumeMounts:  此行多余，将会导致上面的Volumemounts参数不生效
          - mountPath: /home/netbank/facenas
            name: facenas

 ```

如上，写了两个 volumeMounts: 上面那个会失效，而且创建的时候不会报错。

可以参考 应用 volume 的写法。

### 标签 label

同一应用的资源，pv，pvc，rc，svc最好带上相同的label，便于查找和删除。

### 带namespace

这一条没那么重要，但是在比较正式的环境，一些非全局的资源，比如rc，svc，pvc。最好在文件定义好namespace。防止在执行命令kubectl/oc create -f 的时候所在的project不对，导致一些异常。
