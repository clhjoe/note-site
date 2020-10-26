---
title: "AWS RDS MySQL Performance Monitor"
date: 2020-10-26T14:42:49+08:00
draft: false
tags: ["mysql","RDS"]
description: "當你的業務因為資料庫卡住效能，看了看 Slow Query 看不出所以然只好放生嗎？ 來來，我們繼續看下去"
---
資料庫跟你我寫的程式一樣，他也是跑在機器上(不是 虛擬 就是 實體)，因此監控或排查資料庫效能跟排查自己的程式是非常類似的。在 AWS RDS 中，當遇到效能問題時，我們應該排查哪些指標呢？

## Slow Query
遇到效能不好第一個看下 **Slow query** 並搭配 **Explain** 來判斷是不是 Index 沒命中甚至根本沒設 Index @@。另外藉由優化 SQL 語句不僅能提昇速度更能降低資料庫負載。
**[解法]** 妥善設置 Index 並 優化 SQL 語句

## IOPS
在 RDS 的儲存上一般我們會選擇 **General Purpose SSD** 或 **Provisioned IOPS** 應該很少人會選磁帶吧＠＠ 

1. **General Purpose SSD** 在這篇文章撰寫的時候，100GB以下 IOPS上限是 100, 100GB以上是每1 GB 有 3 IOPS (所以 200 GB 有 200*3=600 IOPS) 上限是 16,000，有額外的 Burst 來應付突發的 IO。 

2. **Provisioned IOPS** 就是看你買了多少 IOPS 就多少

因此，在遇到效能瓶頸的時候也要關注下 Read/Write IOPS有沒有超過你的上限，如果超過了當然效能就上不去了。

**[解法]** 

1. 提升 Storage 大小或買更多的 IOPS。
2. 背景處理使用 Read slave 來降低主庫負載
   
## Network Bandwidth & Latency
1. **Bandwidth：** 每一台 Instance的 **Bandwidth** 都是有上限的，所以當然要看一下你的機器頻寬使用率有沒有超過上限。
2. **EBS Optimized?** 有一點容易被忽略的是 EBS 佔用頻寬，RDS 幾乎都是掛載到 EBS上，但 EBS是透過網路的儲存所以當然就會有頻寬的問題。新一代的 Instance(例如 m**4**, c**4**, m5, c6 ...) 就是數字 **4** 以上的基本上預設都是 **EBS optimized** 也就是 EBS是有獨立的網路頻寬不佔用 Instance的頻寬。但 數字是 **3** 的例如(m**3**, c**3**) 要看規格，有些是支援但要另外開啟有些是根本就不支援(所以會佔用 Instance頻寬)。 如果頻寬不夠用了，只有升級一條路了。
3. **Latency** 通常會建議 Client 跟 DB 在同一個 Region下，如果你的 Client 跟 DB 是跨 Region 或甚至 跨了一個洋，那速度絕對是慢一個量級的。

**[解法]** 

1. 升級至新世代支援 EBS optimized 的 Instance 或 scale up 來提昇頻寬上限
2. 使用 Read Slave避免影響主庫寫入
   
## CPU, Memory
CPU 高通常跟 SQL 的 **量** 和 **寫法** 有關。資料庫操作頻繁當然會提昇 CPU的使用率。 Memory 則跟 Server的 cache大小及連接數多寡有關。如果發生記憶體使用率過高導致開始使用 Swap 速度無法避免一定會掉下來了。

**[解法]** 

1. 在資料庫前加個 Cache來降低資料庫的存取
2. 妥善設置 連接數 上限 及 連線逾時
3. 妥善設置資料庫暫存大小
   
## Client 連接數
為了避免連接數過高，在資料庫設定上通常要設 Pool 上限及 Timeout。 但對於客戶端來說，如果 Server 連接數滿了導致無法連接 或是 Timeout時間過短導致頻繁的重新連接都會大大的影響效能。
**[解法]** 

1. 客戶端使用 connection pool 或 長連接 並妥善的設置 pool大小及 idle timeout時間


