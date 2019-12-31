---
title: "PHP Process Tuning"
date: 2019-12-31T22:24:10+08:00
draft: false
tags: ["tips","nginx","php","PHP-FPM","tuning"]
description: "PHP是常見的後端程式語言，在業務初期使用預設的配置通常不會有太大的問題。但是一旦業務開始成長後，沒有經過調校的配置不僅讓你的後端效能不彰更可能造成API access的錯誤。一起來了解怎麼調校你的PHP吧！"
---

# Nginx and PHP-FPM
Nginx是一個輕量的網頁伺服器，他可以高效能的處理靜態檔案。但是如果是動態頁面就必須交由後端例如GO、Python 或是PHP來進行了。現行的Nginx與PHP是通過fast-cgi(Fast Common Gateway Interface) 來進行，不同於CGI為每個Request都建立一個Process造成效能低落，FastCGI透過一個統一管理的Process管理背後的Worker避免過度頻繁建立、關閉Process。
<img src="https://pg-media.ksmobile.com/production/material/file/all_108/1576647093.jpg"</img>


# PHP Process Manager(PM)

PHP process manager有三種模式，分別為
1.  **static**：固定process數量（數量為 pm.max_children）。
2. **dynamic**：動態process數量（根據 pm.max_children、pm.start_servers、pm.min_spare_servers、pm.max_spare_servers 動態調整）。
3. **ondemand**：動態process數量（根據 pm.max_children、pm.process_idle_timeout 動態調整）。


**static** 就是固定process數量。如果網站流量單純，沒有明顯流量高峰或低峰就可以選用**static** 。

**ondemand**會根據實際流量來決定process數，但是因為建立process是需要時間的，所以**效能較差**。但是當流量低的時候，他只會保留所需的process數，所以**節省記憶體**。通常用在比較不重要的服務上。

**dynamic** 跟 **ondemand**很容易稿混，**dynamic**可以設定規則，隨時**保留足夠的預備process(min_spare_servers)** 處理突波，而在結束後也可以**確保記憶體不會被過度使用(max_spare_servers)** ， 因此較適合在忙碌的服務上。

接下來我們著重在**dynamic** 的配置優化。

# PHP Process Manager(PM) Dynamic模式配置優化

### pm.start_servers(初始 process數)
決定初始process重要的因數就是服務實際的流量。假設服務需要10個processes, 我們一開始只給1，那系統啟動後就要一直fork process到滿足需求，期間就會造成效能瓶頸。所以比較好的方式是啟動的時候就滿足流量最大的需求個數。
預設值是 min_spare_servers + (max_spare_servers - min_spare_servers) / 2


### pm.max_children(最大process 數)
 pm.max_children限制了系統最多可以啟動多少process, 決定process的重要因素就是**你的記憶體有多大？**  每一個process都需要消耗記憶體，因此要計算你的機器能承受多少process的記憶體使用量。

因此簡單的公式就是

**max_children** = (**system_memory** - **memory_used_by_other_services** - **buffer** ) / **memory_used_per_process**

**計算記憶體**
一個PHP-FPM 使用了多少記憶體？

```
ps --no-headers -o "rss,cmd" -C php-fpm | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"Mb") }'

#50Mb
```

所以假設我們系統有 8G的記憶體，然後保留1G的記憶體給系統，因此我們可以得到
**max_children**= ( 8192 -1024 ) / 50  = 143


### pm.min_spare_servers( 最小閒置process數)
這個參數的意思是 **最少保留多少的閒置process** 而不是**閒置的時候保留多少process** 。這個值得用意是當你的request有暴衝的時候可以忍受多大的突波。簡單來說，當min_spare_servers=10, 現形的request需要5個process, 這時候PHP就會啟動 15個process。 因此你的系統可以承受10個process可以處理的量。


### pm.max_spare_servers( 最大閒置process數)
當突波結束後要保留多少閒置的process呢？保留越多的process就會用到越多的記憶體。因此這邊可以隨著業務的進行然後觀察調整(重點就是不要把機器的記憶體弄爆了)。


### pm.max_requests(單一process可以處理多少process)
max_requests的行為是當process累計處理的request數到達這項設定時就關掉這個process。為什麼會有這個設定出現呢？原因是PHP先天有memory leak的問題，所以往往會發現process跑越久，所佔用的記憶體就越多。因此我們可以實際觀察memory的使用曲線，觀察PHP在跑多久後會失去控制？進而設定max_requests。
<img src="https://pg-media.ksmobile.com/production/material/file/all_106/1576640042.png"/</img>



# 常見錯誤處理
1.  seems busy (you may need to increase pm.start_servers, or pm.min/max_spare_servers), spawning 32 children, there are 25 idle, and 107 total children
  如同字面上的意思，現行的可用process太少了，建議調高start_servers, min/max_spare_servers數。因此我們可以根據上述的原則去調整。

2. PHP 502 Error
   5xx通常是伺服器的錯誤，當你的process不足的時候有機會5xx, 系統的記憶體不足也有可能造成5xx。而以我們自身的案例，調整max_requests也可以處理5xx的產生。
  <img src="https://pg-media.ksmobile.com/production/material/file/all_107/1576640102.png"/</img>

