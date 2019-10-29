---
title: "Linux Dns Debug"
date: 2019-10-29T11:54:32+08:00
draft: false
tags: ["dns","linux","go","golang","aws"]
description: "Linux上DNS常常是一個神秘的謎團，API呼叫失敗我們會看到錯誤可以即時的發現，但是DNS解析失敗呢？常常在retry後或是查詢下一個測試的DNS server就取得結果，但無形中其實增加了你的lantency。這篇主要來紀錄一下Linux下的DNS 解析"
---

## 我到底用了哪台DNS server?
在Linux上，不管是使用glibc dns resolver或是golang自己實做的dns resolver, 他們都會去查看系統下的 **/etc/hosts** 及 **/etc/resolv.conf** 。/etc/hosts沒什麼好說的，下面舉個/etc/resolv.conf的例子
```
nameserver 127.0.0.53
nameserver 8.8.8.8
```
這邊的結果代表他會先去查詢 **127.0.0.53** 如果查不到再去查 **8.8.8.8**，如果也失敗了再重頭來直到嘗試三次都查不到才宣告放棄。想想，這時候如果是在第三輪才藉由8.8.8.8查到IP，那都浪費多少生命了。

## AWS上的DNS 查詢

### AWS DNS有哪些？
在AWS上，可以使用的DNS server有 **169.254.169.254** 跟 **VPC IPv4 network range加2**(假設你的IP range是 10.2.0.0/16 ，你就可以用10.2.0.2當DNS server).差別在前者在某些OS上是不能使用的(例如 Windows Server 2008) 但是在Linux上是沒有問題的。

### AWS DNS限制
AWS DNS有每秒不能超過1024次query的限制，假設超過了就會把你throttle。建議的作法是安裝 **dnsmasq** 他會cache住查詢結果，這樣就不用一直去問啦～預設cache時間是DNS設置的ttl時間，要注意的是，自己延長TTL是有風險的。假設你使用了RDS的服務，他是透過DNS來切換Master/Slave的，當你延長了TTL也就代表當今天Master掛了，你需要花更久的時間才能連到新的Master。

## DNS除錯方法
### 查詢域名是否可以解析
常見的方式是使用dig來看，例如
```
dig www.google.com

```
結果會類似

```
; <<>> DiG 9.11.3-1ubuntu1.9-Ubuntu <<>> www.google.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 43990
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;www.google.com.                        IN      A

;; ANSWER SECTION:
www.google.com.         22      IN      A       216.58.200.228

;; Query time: 0 msec
;; SERVER: 127.0.0.53#53(127.0.0.53)
;; WHEN: Tue Oct 29 12:18:14 CST 2019
;; MSG SIZE  rcvd: 59

```
當中的 **216.58.200.228** 就是解析出來的IP。如果想要指定某台DNS來解析呢？加個 @DNS-IP 例如
```
dig www.google.com @1.1.1.1
```

### 查詢本機域名查詢多頻繁？
上面提到的，AWS會針對DNS查詢限流。那我們要怎麼知道有沒有超過限制呢？可以使用這個command。使用時要替換 **/<file_name.pcap>**
```
sudo tcpdump  -r /tmp/<file_name.pcap> -nn dst port 53 | awk -F " " '{ print $1 }' | cut -d"." -f1 | uniq -c
```
輸出的內容會是
```
2 06:40:34
2 06:40:42
```
第一個欄位是查詢次數，第二個欄位是查詢時間。這樣就可以知道查詢的多頻繁了。

另外，你也可以執行下面的command來看一下都在針對哪個域名查詢   
```
sudo tcpdump -i any port 53  -W 123 -C 100 -n -K -Z root

```  

### DNS查詢好慢？問題出在那？
有時候我們用 **httpstat**來檢查整個API查詢是慢在那，結果發現居然是DNS lookup慢了！這時候我們可以用下面的查詢來試試看DNS 查詢到底有多慢。
```
dig @8.8.8.8  www.cmcm.com  +noall +answer +stats |   awk '$3 == "IN" && $4 == "A"{ip=$5}/Query time:/{t=$4 " " $5}END{print ip, t}'
```
結果出現
```
107.155.25.117 245 msec
```
奇怪到底慢在那呢？最方便的作法是直接用 [ultratools](https://www.ultratools.com/tools/dnsHostingSpeedResult  "ultratools") 來看，以這個例子來說，我們可以知道整個解析是慢在..**dnsv5.com** 也就是dnspod的服務... <img src="http://pg-media.ksmobile.com/wiki/dns.png" style="height:550px"></img> 