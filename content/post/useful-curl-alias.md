---
title: "Useful Curl Alias"
date: 2019-10-22T10:53:54+08:00
draft: false
tags: ["tool","tips","Linux","shell"]
description: " 常常用curl & jq來Debug？好用的組合技讓你事倍功半"
---

## 前言
常常會需要去檢查API的狀態，包含response header及response body。所以一個好用的command組合可以讓你輕鬆一點

## 組合技法
將alias放到  ~/.bashrc 這樣下次啟動後就可以生效了


```
echo alias c='curl -s --dump-header /dev/stderr' >> ~/.bashrc
source ~/.bashrc

```

## 實際使用

```
c 'https://api.ipify.org?format=json'|jq

or 

c 'https://api.ipify.org?format=json'|jq .ip
```

執行結果
```
joe@server:~$ c 'https://api.ipify.org?format=json'|jq 
HTTP/1.1 200 OK
Server: Cowboy
Connection: keep-alive
Content-Type: application/json
Vary: Origin
Date: Tue, 22 Oct 2019 02:57:35 GMT
Content-Length: 23
Via: 1.1 vegur

{
  "ip": "115.237.31.60"
}

```

是不是很好用？