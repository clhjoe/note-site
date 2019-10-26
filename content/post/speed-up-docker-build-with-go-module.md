---
title: "Speed Up Docker Build With Go Module"
date: 2019-10-13T21:23:54+08:00
draft: false
tags: ["tips","docker","multi","stage","go","golang","go module"]
description: "使用小技巧來避免go 重新拉取module加快編譯速度"
---

[上一篇](https://clhjoe.github.io/posts/multi-stage-docker-build-with-go-module/) 說明了如何降低Docker 編譯Go程式產生的image大小，但同時也提到了因為Go 每次都會去抓相依的module導致編譯速度就是慢！
![go mod download](https://pg-media.ksmobile.com/production/material/file/all_90/1571203055.png)
有什麼方法可以加速呢？來看看看優化版本

**optimized.Dockerfile**
```dockerfile
#first stage - builder
FROM golang:1.13.1-stretch as builder

WORKDIR /api

#Step 1. 複製go.mod及go.sum
COPY go.mod go.sum ./

#Step 2. 下載所有的dependencies, 只要go.mod和go.sum不變就不需要重新下載相依
RUN go mod download

# Step 3. 複製source code並編譯
COPY . .

ENV GO111MODULE=on
RUN CGO_ENABLED=0 GOOS=linux go build -o api main.go

#second stage
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /api .
CMD ["./api"]
```

透過Step 1,2 來節省下載相依的時間，試試看吧～

如同前一篇提及，alpine是精簡的fs, 缺少許多程式需要的library例如tzdata等等，如何寫出完整的Dockerfile呢？[請看此](https://clhjoe.github.io/posts/complete-example-of-docker-build-with-go-module/)
