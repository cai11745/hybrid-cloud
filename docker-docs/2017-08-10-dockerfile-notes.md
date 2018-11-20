---
layout: post
title:  Dockerfile书写注意事项
category: docker
description: 
---

## Dockerfile书写注意事项

1. 镜像支持的层，最大数是127。

2. 不常变动的部分写在dockerfile上面，以便后续变更时可以利用缓存，减少build时间和磁盘占用。

3. 大的rpm包，如果要安装到镜像中，可以做成yum 源，yum install xx之后yum clean all，如果ADD XX.rpm /xx，这样rpm会使镜像增大。 

4. RUN rm xxx  去删除上一层产生的文件不会减小镜像大小，因为包含文件的那层会一直存在。

5. 尽量不在dockerfile去修改文件权限，修改权限后的文件会生成一份新的文件导致镜像变大，修改权限在本地直接改好或写在启动脚本中。

6. 添加文件夹到指定目录，如果想把tomcat文件夹添加到home，要写成ADD tomcat/ /home/tomcat/ ， home后必须带tomcat。

7. yum install或者apt-get install 要执行clean，清除缓存，减小镜像。

8. 暴露多个端口或者设置多个环境变量或者RUN多条命令，分别写到同一层
