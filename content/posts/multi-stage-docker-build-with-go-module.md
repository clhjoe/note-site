---
title: "Multi Stage Docker Build With Go Module"
date: 2019-10-13T20:53:48+08:00
draft: false
---

## 為什麼要使用Multi-stage來編譯Golang？
假設我們有一個簡單的Golang程式如下

**main.go**
```go
package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})
	r.Run() // listen and serve on 0.0.0.0:8080
}
```
然後我們爲了這支程式寫了個Dockerfile

**Dockerfile**
```dockerfile
FROM golang:1.13.1-stretch 

COPY . /api 
WORKDIR /api

ENV GO111MODULE=on

RUN CGO_ENABLED=0 GOOS=linux go build -o api main.go

CMD ["./api"]
```

編譯他吧！
```shell
docker build . -t api
```

編譯完我們來看一下Image有多大？
```shell
docker images
#REPOSITORY                                   TAG                 IMAGE ID            CREATED              SIZE
#api                                          latest              1f3921830d5a        39 seconds ago       842MB
```
有沒有搞錯？要**842MB**? 怎麼不去搶？

## 瘦身
為什麼會這麼大呢？因為在編譯之前，go會把相依的go module都抓下來，這當然大啊！所以可透過multi-stage來避免這個問題。看一下

**Dockerfile**
```dockerfile
#first stage - builder
FROM golang:1.13.1-stretch as builder
COPY . /api
WORKDIR /api
ENV GO111MODULE=on
RUN CGO_ENABLED=0 GOOS=linux go build -o api main.go

#second stage
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /api .
CMD ["./api"]
```

一樣給他跑一下
```shell
docker build . -t multi-stage-api
#REPOSITORY                                   TAG                 IMAGE ID            CREATED             SIZE
#multi-stage-api                              latest              27fd709e4c9d        7 seconds ago       41.3MB
```

差了快**800MB**! 

寫到這裏，不知道大家有沒有注意到每次編譯go都會去抓新的module, 這好浪費時間啊！來 [繼續往下看](https://clhjoe.github.io/posts/speed-up-docker-build-with-go-module/) 參考

alpine是精簡的fs, 缺少許多程式需要的library例如tzdata等等，如何寫出完整的Dockerfile呢？[請看此](https://clhjoe.github.io/posts/complete-example-of-docker-build-with-go-module/)