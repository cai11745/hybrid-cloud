---
layout: post
title:  Dockerfile中命令解读
category: docker
description: Dockerfile中一些命令的解读。
---

dockerfile 常用命令解读  

### Docker build

```
docker build -t omartech/ubuntu-clean .
```

要注意的是，这个命令会把当前文件夹内的所有文件包括子文件夹都传递给docker程序，于是，最好的办法是新建一个空文件夹，然后写Dockerfile，然后再执行该命令。  
 -t xxx来给该镜像打个标签

### 1. FROM

```
FROM <image> OR
FROM <image>:<tag>
```

都可以用，例如FROM ubuntu 和 FROM docker.cn/docker/ubuntu:14.04.1
如果构建的时候没有传递tag给它，默认用latest做为tag  
如果需要创建多个镜像，FROM可以在Dockerfile中出现多次的

### 2. MAINTAINER

这个命令用来写自己的名字，是谁创建的这个镜像

```
MAINTAINER <name> 
MAINTAINER feng pdhh@163.com
```

### 3. RUN

RUN命令是用来做具体的操作，它有两种形式
```
RUN <command> (the command is run in a shell - /bin/sh -c - shell form)
RUN ["executable", "param1", "param2"] (exec form)
```
RUN命令执行完之后会被commit，就跟源代码管理一样，会有个commit的编号，方便后续从任何一个命令之后checkout出来。  
RUN命令会带cache，例如执行 RUN apt-get dist-upgrade -y, 如果不想用cache，可以这样docker build --no-cache  
每一条语句在Dockerfile中都是独立的，也就是说，如果第一条语句写RUN cd /tmp,对第二条语句是没有作用的。  

```
RUN cd /home
RUN touch test.txt
```

最终test.txt是在/目录下，而不是在/home  
所以每次RUN 都要使用绝对路径
或者一次写完

```
RUN cd /home && touch test.txt
``` 

### 4. CMD

CMD命令有三种格式
```
CMD ["executable","param1","param2"] (exec form, this is the preferred form)
CMD ["param1","param2"] (as default parameters to ENTRYPOINT)
CMD command param1 param2 (shell form)
```
但是，CMD只能在Dockerfile中出现一次，如果你写了多次，也只有最后一个生效  
CMD主要是是用来启动该容器下需要执行的那个程序，作为main入口用。  
如果CMD执行的命令式shell，那么会默认用/bin/sh -c 例如：  
```
FROM ubuntu
CMD echo "This is a test." | wc -  
```
如果不想用shell执行，需要写成json格式  
```
FROM ubuntu
CMD ["/usr/bin/wc","--help"]
```

### 5. ADD添加文件到容器

```
ADD <src> <dest>
```
` ADD 将文件从路径 <src>复制添加到容器内部路径 <dest>.  `
`<src> 必须是想对于源文件夹的一个文件或目录，也可以是一个远程的url`  
`<dest> 是目标容器中的绝对路径。 `  
`事实上如果 <src> 是一个远程文件URL，那么目标文件的权限将会是600。 `   
Note: 如果你填写的远程URL需要验证，那么使用 RUN wget, RUN curl 或者其他工具，因为ADD指令是不提供验证的。  
`Note: 当资源内容中的<src>发送改变的时候，ADD指令会将所有的缓存置为失效，同时包括 RUN 指令的缓存  `  
`<src> 必须在build的资源目录中; 不可以使用 ADD ../something /something, 因为 docker build 的第一步就需要帮资源目录和子目录发送给 docker daemon.`  
`如果 <src> 是一个URL 同时 <dest> 不是斜线结尾, 那么文件会被先下载然后复制到 <dest>.`  
`如果 <dest> 不是以斜线结尾的,文件就会以普通文件形式写入到目标。`  
`如果 <dest> 不存在, 文件会被创建在默认不存在路径下。`  

ADD /home/test22.txt  /home/testjueduilujing/  fail，不支持绝对路径  
ADD ../tool/docker-1.12.3.tar /home/test/  不支持路径格式   
ADD alt.tar.gz /home/test22/  ADD alt.tar.gz /home/test22  不管test22后面带不带斜线，都会把tar.gz解压缩后add到test22文件夹  
ADD 33.txt /home/tttt1/  把33.txt 复制到/home/tttt1/目录下，文件名还是33.txt  
ADD 33.txt /home/tttt1 把33.txt复制到/home 目录，文件名为tttt1  
ADD test /home/t1/   ADD test/ /home/t1/  都是把test目录中的文件copy到/home/t1/目录中  

 
### 4. COPY，基本同于add

格式为
```
COPY <src> <dest>
```
复制本地主机的 <src>（为 Dockerfile 所在目录的相对路径）到容器中的 <dest>。
当使用本地目录为源目录时，推荐使用 COPY。  

### 5. volume

格式为 
```
VOLUME ["/data"]
```
创建一个可以从本地主机或其他容器挂载的挂载点，一般用来存放数据库和需要保持的数据等。  
由于没有指定挂载到的宿主机目录，因此会默认挂载到宿主机的 /var/lib/docker/volumes 下的一个随机名称的目录下，在这里为 /mnt/sda1/var/lib/docker/volumes/8827c361d103c1272907da0b82268310415f8b075b67854f27dbca0b59a31a1a/_data。  
因此Dockerfile中使用VOLUME指令挂载目录和 docker run 时通过 -v 参数指定挂载目录的区别在于，run的 -v 可以指定挂载到宿主机的哪个目录，而Dockerfile的VOLUME不能，其挂载目录由docker随机生成。

移除无用的挂载目录
```
docker volume rm $(docker volume ls -qf dangling=true)
```
### 6. USER

格式为 
```
USER daemon
```
指定运行容器时的用户名或 UID，后续的 RUN 也会使用指定用户。   
当服务不需要管理员权限时，可以通过该命令指定运行用户。并且可以在之前创建所需要的用户，例如：RUN groupadd -r postgres && useradd -r -g postgres postgres。  
要临时获取管理员权限可以使用 gosu，而不推荐 sudo

### 7. WORKDIR

格式为 
```
WORKDIR /path/to/workdir
```
为后续的 RUN、CMD、ENTRYPOINT 指令配置工作目录。
可以使用多个 WORKDIR 指令，后续命令如果参数是相对路径，则会基于之前命令指定的路径。例如
```
WORKDIR /a
WORKDIR b
WORKDIR c
RUN pwd
```
则最终路径为 /a/b/c

### 8. EXPOSE公开端口
两个Docker的核心概念是可重复和可移植。镜像应该可以运行在任何主机上并且运行尽可能多的次数。在Dockerfile中你有能力映射私有和公有端口，但是你永远不要通过Dockerfile映射公有端口。  
通过映射公有端口到主机上，你将只能运行一个容器化应用程序实例。（译者注：运行多个端口不就冲突啦）  
```
＃private and public mapping
EXPOSE 80:8080
＃private only
EXPOSE 80
```
如果镜像的使用者关心容器公有映射了哪个公有端口，他们可以在运行镜像时通过 -p 参数设置，否则，Docker会自动为容器分配端口。  
切勿在Dockerfile映射公有端口。

### 9. CMD与ENTRYPOINT的语法  
CMD如果不是完成shell格式，要带中括号，写成数组格式  
CMD和ENTRYPOINT指令都非常简单，但它们都有一个隐藏的容易出错的“功能”，如果你不知道的话可能会在这里踩坑，这些指令支持两种不同的语法。  
```
CMD /bin/echo
＃or
CMD ["/bin/echo"]
```
两种方式差距很大。如果你使用第二个语法：CMD（或ENTRYPOINT）是一个数组，它执行的命令完全像你期望的那样。如果使用第一种语法，Docker会在你的命令前面加上/bin/sh -c  
如果你不知道Docker修改了CMD命令，在命令前加上/bin/sh -c可能会导致一些意想不到的问题以及难以理解的功能。因此，在使用这两个指令时你应当使用数组语法，因为数组语法会确切地执行你打算执行的命令。  
使用CMD和ENTRYPOINT时，请务必使用数组语法。  
```
FROM ubuntu:trusty
ENTRYPOINT ["/bin/ping","-c","3"]
CMD ["localhost"]
```
比如生成镜像叫ubuntu11
docker run -t ubuntu11    执行的结果是/bin/ping -c 3 localhost   
docker run -t ubuntu11 ww.baidu.com  结果是/bin/ping -c 3 www.baidu.com


### 10. CMD和ENTRYPOINT 结合使用更好
```
ENTRYPOINT ["/usr/bin/rethinkdb"]
CMD ["--help"]
```

### 11. Dockerfile和构建缓存
Docker将每一步结束之后提交的镜像层当作缓存。  
然而有些时候我们必须确保之前的缓存被覆盖掉。例如，如果已经缓存了之前的第三步，即 apt-get update 但是我们必须确保接下来安装的软件是最新版本，那就必须忽略缓存功能。可以使用docker build 的–no-cache 标志。  
```
docker build --no-cache -t="zhangyang/static_web" .
```

### 12. Dockerfile和构建缓存Dockerfile指令运行失败
```
docker run -i -t e8ec593f1475 /bin/bash 
```
使用失败前的镜像建立容器调试  
进入该容器进行调试，解决了该问题之后再退出容器修改Dockerfile文件相应的出错位置。
