---
title: "Complete Example of Docker Build With Go Module"
date: 2019-10-13T21:51:59+08:00
draft: false
tags: ["tips","linux","docker","golang"]
description: "前兩篇介紹了使用multi-stage來降低docker image size 及 加速Docker編譯go 程式，但透過alpine會缺少一些API必要的ssl或tzdata等等的套件，這篇來分享完整的範例吧～"
---

## 前言
前兩篇 [使用multi-stage來降低docker image size](https://clhjoe.github.io/posts/multi-stage-docker-build-with-go-module/) 及 [加速Docker編譯go 程式](https://clhjoe.github.io/posts/speed-up-docker-build-with-go-module/) ，但透過alpine會缺少一些API必要的ssl或tzdata等等的套件，這篇來分享完整的範例吧～

## 舉個例子
直接來看看Dockerfile, 注意步驟4跟步驟5。

**Dockerfile**
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

#Step 4. 安裝tzdata確保時區(time package)可以正常使用
RUN apk add --no-cache tzdata

#Step 5. 複製ca certificates, 確保go 可以正常的連至https的api或網頁
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /api .
CMD ["./api"]
```


好啦～以上就是完整的使用docker來編譯Go程式啦！最後不要忘記撰寫.dockerignore避免不必要的複製讓編譯更快速！