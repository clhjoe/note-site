---
title: "Mysql Scan Index vs. Scan Table"
date: 2020-10-26T13:44:40+08:00
draft: false
tags: ["mysql"]
description: "業務上我們有機會需要根據條件在MySQL中把符合條件的資料 Query 出來，教科書總是告訴我們 Index 可以提昇 Query 速度，但真的是這樣嗎？"
---

# 故事開始
假設我們有一個表紀錄著所有 APP 下的所有用戶的FCM token如下:
```sql
CREATE TABLE `fcm_token` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `appid` int(10) unsigned NOT NULL,
  `token` varchar(255) NOT NULL',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_unique_pair` (`appid`,`token`(225),`uid`)
)ENGINE=InnoDB  DEFAULT CHARSET=utf8;

```
當今天我們想要對某個APP下的所有用戶做推送，顯然我們需要Query出所有該APP下所有的Token

```sql

SELECT id,token FROM fcm_token WHERE appid = xxx;
```

這時候，根據教科書，我們如果對APPID做Index應該可以提昇效能。而且也因為我們建了 Unique Key: **uniq_unique_pair** 所以根據 **EXPLAIN** MySQL使用了這個INDEX。

但現實是殘酷的，在AWS的環境中，我們比較上面的SQL 跟 **不使用INDEX** 的Query 也就是:
```sql
SELECT id,token FROM fcm_token USE INDEX() WHERE appid = xxx;

``` 
我們發現後者的效能居然是前者的10倍以上(1,000~2,500 rows/sec vs.  38,000~45,000 rows/sec)，到底發生什麼事了呢！！？？

# 深入了解

## Full Table Scan
兩個SQL很明顯的差別就是在一個用了 INDEX 一個沒使用INDEX。在不使用INDEX 的情況下， MySQL 會全表掃描(Full Table Scan)，也就是會掃描每一筆資料再根據條件過濾，而這個動作是 **sequential reads** ，相對於 **random reads** 來說是非常快的操作。缺點是不管下什麼條件，都必須掃描每一個 row, 所以整個 Table 撈出來 跟 符合條件只有 10 筆， 時間是沒有太大的差異的。

## Full Index Scan
以 MySQL為例，Index 是 B+的結構。特點是 葉節點存放的是 Row的 Address而不是 Row本身的資料。因此掃描 Index是 **sequential reads** 但是讀取該筆的 **token** 必須跳到葉節點紀錄的 address來取得資料，而這個操作是 **random read** 因此 N筆資料會產生額外的 N 次的 random reads 所以速度就慢了。 相反的如果符合的筆數少，因為有 Index 不需要掃描全部的 Rows, 也因為筆數少， random reads也變少，所以速度就會比較快。


# 結論
如果符合條件的筆數少可以考慮使用 Index 來加快速度，但如果筆數大超過一個量級則全表掃描反而會更快！

另個思路是，如果我們把token 放在 Index呢？ 因為 token放在 Index 也就是 B+ Tree裡，在掃描 Index的時候不需要額外的 random read，所以速度自然而然可以比 Full table scan 更快。 同理，假設需要根據 ID 排序， 如果量大 MySQL 需要做 filesort，是一個耗時的操作，如果把 ID也放到 Index中 就可以避免 filesort了。
但缺點是

1. 過多的Index會影響寫入跟更新的速度
2. Index 的資料有長度限制
   
所以具體怎麼選擇，還是得依照業務特性來設計了。



