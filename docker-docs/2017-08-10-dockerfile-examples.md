---
layout: post
title:  Dockerfile优秀示例
category: docker
description: 收集写的比较好的Dockerfile
---

收集写的比较好的Dockerfile

范例1：
```
FROM ubuntu:14.04.2
MAINTAINER minimum@cepave.com
ENV GOLANG_VERSION=1.4.1 \ 
    GOLANG_OS=linux \
    GOLANG_ARCH=amd64 \
    GOROOT=/home/go \
    GOPATH=/home/workspace \
    PATH=$GOROOT/bin:$GOPATH/bin:$PATH
WORKDIR /home
RUN \ 
  apt-get update && \
  apt-get install -y wget vim git && \
  wget https://storage.googleapis.com/golang/go$GOLANG_VERSION.$GOLANG_OS-$GOLANG_ARCH.tar.gz && \
  tar -xzf go$GOLANG_VERSION.$GOLANG_OS-$GOLANG_ARCH.tar.gz && \
  mkdir -p workspace/src && \
  apt-get remove -y wget && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* go$GOLANG_VERSION.$GOLANG_OS-$GOLANG_ARCH.tar.gz
```
范例2：

```
FROM buildpack-deps 
MAINTAINER Peter Martini <PeterCMartini@GMail.com> 
RUN apt-get update \ 
&& apt-get install -y curl procps \ 
&& rm -fr /var/lib/apt/lists/* 
RUN mkdir /usr/src/perl COPY *.patch /usr/src/perl/ 
WORKDIR /usr/src/perl 
RUN curl -SL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.22.2.tar.bz2 -o perl-5.22.2.tar.bz2 \ 
&& echo 'e2f465446dcd45a7fa3da696037f9ebe73e78e55 *perl-5.22.2.tar.bz2' | sha1sum -c - \ 
&& tar --strip-components=1 -xjf perl-5.22.2.tar.bz2 -C /usr/src/perl \ 
&& rm perl-5.22.2.tar.bz2 \ 
&& cat *.patch | patch -p1 \ 
&& ./Configure -Dusethreads -Duse64bitall -Duseshrplib -des \ 
&& make -j$(nproc) \ && TEST_JOBS=$(nproc) make test_harness \ 
&& make install \ 
&& cd /usr/src \ 
&& curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \ 
&& chmod +x cpanm \ && ./cpanm App::cpanminus \ 
&& rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/* 
WORKDIR /root 
CMD ["perl5.22.2","-de0"]
```
