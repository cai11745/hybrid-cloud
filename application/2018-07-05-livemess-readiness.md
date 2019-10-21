# liveness readiness 健康检查

为了更好的检测容器是否存活及能否对外提供服务。 通常在正式运行的应用中都会配置这两个参数来保障应用的正常运行。

liveness probe  存活探针， 来确定容器何时重启（注意是重启容器，不是杀了pod 重来）。一旦探针检测失败次数达到设定值，就会重启容器。 在 kubectl get pod 的状态中能看到 restart 次数。

readiness 就绪探针， 来确定容器是否就绪能够接受流量。当探针返回0， 即返回结果为正常时， kubelet 会认定容器就绪，可以提供服务，就会把容器加到 service 的负载中。 反之，则会从负载列表中移除容器。

[kubernetes 官方配置文档](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/)

有三种 liveness/readiness probe 可供选择：http、tcp 和 container exec。前两者检查 Kubernetes 是否能使 http 或者 tcp 连接至指定端口。container exec probe 可用来运行容器里的指定命令，并维护容器里的停止响应代码。如下所示的代码片段中,我们使用http probe发送Root URL，使用 GET请求到端口80。

liveness和readiness在参数格式上用法相同，只是作用不通。

## liveness

许多长时间运行的应用程序最终会转换到broken状态，除非重新启动，否则无法恢复。Kubernetes提供了liveness probe来检测和补救这种情况。当探针检测到容器异常时，能自动重启容器。

### exec

```bash
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    image: registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5

```

该配置文件给Pod配置了一个容器。periodSeconds 规定kubelet要每隔5秒执行一次liveness probe。 initialDelaySeconds 告诉kubelet在第一次执行probe之前要的等待5秒钟。探针检测命令是在容器中执行 cat /tmp/healthy 命令。如果命令执行成功，将返回0，kubelet就会认为该容器是活着的并且很健康。如果返回非0值，kubelet就会杀掉这个容器并重启它。

容器启动时，执行该命令：

```bash
/bin/sh -c "touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600"

```

在容器生命的最初30秒内有一个 /tmp/healthy 文件，在这30秒内 cat /tmp/healthy 命令会返回一个成功的返回码。30秒后， cat /tmp/healthy 将返回失败的返回码。

创建Pod：

```bash
root@master1:~/k8s-oc-yaml/application# kubectl create -f pod-liveness-exec.yaml 
pod "liveness-exec" created
```

在30秒内，查看Pod的event：

```bash
kubectl describe pod liveness-exec
```

结果显示没有失败的liveness probe：

```bash
Events:
  Type    Reason                 Age   From               Message
  ----    ------                 ----  ----               -------
  Normal  Scheduled              1m    default-scheduler  Successfully assigned liveness-exec to node1
  Normal  SuccessfulMountVolume  1m    kubelet, node1     MountVolume.SetUp succeeded for volume "default-token-8lv8j"
  Normal  Pulling                1m    kubelet, node1     pulling image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28"
  Normal  Pulled                 18s   kubelet, node1     Successfully pulled image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28"
  Normal  Created                18s   kubelet, node1     Created container
  Normal  Started                18s   kubelet, node1     Started container
```

启动35秒后，再次查看pod的event：

```bash
kubectl describe pod liveness-exec
```

在最下面有一条信息显示liveness probe失败，容器被删掉并重新创建。

```bash
Events:
  Type     Reason                 Age               From               Message
  ----     ------                 ----              ----               -------
  Normal   Scheduled              11m               default-scheduler  Successfully assigned liveness-exec to node1
  Normal   SuccessfulMountVolume  11m               kubelet, node1     MountVolume.SetUp succeeded for volume "default-token-8lv8j"
  Normal   Pulling                11m               kubelet, node1     pulling image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28"
  Normal   Pulled                 10m               kubelet, node1     Successfully pulled image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28"
  Normal   Started                8m (x3 over 10m)  kubelet, node1     Started container
  Normal   Created                6m (x4 over 10m)  kubelet, node1     Created container
  Normal   Killing                6m (x3 over 9m)   kubelet, node1     Killing container with id docker://liveness:Container failed liveness probe.. Container will be killed and recreated.
  Normal   Pulled                 6m (x3 over 9m)   kubelet, node1     Container image "registry.cn-hangzhou.aliyuncs.com/misa/busybox:1.28" already present on machine
  Warning  Unhealthy              1m (x19 over 9m)  kubelet, node1     Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
 ```

再等30秒，确认容器已经重启：
kubectl get pod liveness-exec
从输出结果来RESTARTS值加1了。
NAME            READY     STATUS    RESTARTS   AGE
liveness-exec   1/1       Running   1          1m





