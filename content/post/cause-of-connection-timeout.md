---
title:       "Timeout原因整理-以Golang為例"
subtitle:    ""
description: "網路連線中有各種timeout, connection timeout, readtimeout, writetimeout等等，到底這些錯誤是什麼情況造成的呢？這邊以Go為例子整理出常見的timeout原因"
date:        2019-10-26
author:      "Joe"
image:       ""
tags:        ["golang", "go","timeout","network","aws","mysql","rds"]
draft: false

---

## 前言
網路連線中有各種timeout, connection timeout, readtimeout, writetimeout等等，到底這些錯誤是什麼情況造成的呢？這邊以Go為例子整理出常見的timeout原因

## connnection timeout
在建立連線的時候，如果遇到 **JAVA** java.net.ConnectException: Connection timed out: connect 或是 **Golang** dial tcp IP:PORT: connect: connection timed out通常是什麼原因呢？ 其實原因不外乎
* 與目的地網路不通
* 沒有權限連入(e.g. MySQL, Redis etc.)
* 連到錯誤的IP(??)
  
  前兩個比較好理解，第三個又是什麼意呢？以AWS為例，當你在EC2在照著官方的權限設定(VPC, Security Group配置)下想要連到RDS好了，假設你的RDS是my-rds.ld2kfdi343.us-west-2.rds.amazonaws.com, 這時候AWS的DNS伺服器給你的會是這一台的 **Private IP** ，但假設你把DNS改成8.8.8.8呢？你會發現你拿到的會是 **Public IP** ，這時候你就連不進去了！ 提供我常用檢查的SOP

### Ping工具檢查
假設你要連的目的地是 10.2.3.1，可以試試Ping一下
```shell
ping 10.2.3.1
```
如果可以ping通代表網路是通得，但如果不通呢？也不一定是不通，因為對方可能沒打開ICMP。(但如果有通就代表不是網路連接問題))
### telnet Port檢查
以MySQL來說，可以直接用telnet 連檢查是否可以連線，如果可以連線，則可以往MySQL權限檢查，如果不行，可以檢查一下防火牆、security group, 或是VPC。

```
telnet my-rds.ld2kfdi343.us-west-2.rds.amazonaws.com 3306
```
### 權限檢查
如同上一條提到，網路如果是通得，就檢查一下MySQL裡的權限設定。

### DNS檢查
我們都知道假設需要連到某個域名，例如my-rds.ld2kfdi343.us-west-2.rds.amazonaws.com，必須先轉換成IP才能溝通。如果是無法解析，在Ping的時候就會發現了。那又為什麼要獨立寫呢？以Golang為例，目前版本預設是pure Go resolver(也就是Go自己寫的)去讀系統的/etc/hosts及 /etc/resolve.conf得到DNS清單，當程式裡需要連線的時候，假設/etc/hosts沒有就會按照順序去詢問/etc/resolve.conf的DNS,第一台解析錯誤就會問第二台。所以假設你在/etc/resolv.conf設定兩個DNS <br>
```
# aws dns server
nameserver 10.2.0.2

# google dns server
nameserver 8.8.8.8
```
當第一台掛掉的時候，Go會去詢問8.8.8.8，以剛剛的例子my-rds.ld2kfdi343.us-west-2.rds.amazonaws.com就會得到public IP，然後程式試著要去連public ip就會遇到connection timeout.

## read/write 或 i/o timeout
read/write or i/o timeout 通常是發生在connection pool裡(但不是絕對)，情境有可能是：
### 程式實做問題
  就超過你設定的timeout，檢查一下是不是程式或資料庫語法沒寫好

### 程式端time out時間比伺服器長
  假設程式端連到MySQL的read/write timeout設成10s好了，但你在MySQL(也就是目的地)timeout設成8，這個時候你只要read/write超過8秒對方就把你斷線，這時候你就會遇到類似 **packets.go:33: read tcp x.x.x.x:x->x.x.x.x:x: i/o timeout** 。這時候記得程式端的timeout時間最好短於伺服器端。(MySQL or Redis等等都是)