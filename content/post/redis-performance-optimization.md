---
title: "Redis Performance Optimization"
date: 2019-12-31T23:25:42+08:00
draft: false
tags: ["tips","php","redis","performance"]
description: "Redis利用記憶體快取可以大幅度的提昇程式的性能。但是如果不了解Redis的特性就胡亂使用有可能是埋了地雷等待時間引爆。這邊主要介紹幾個Redis提昇效能的方法，避免在未來流量漲起來的時候變成炸彈。"

---

# 1. 使用Pipeline
Redis client跟server之間的溝通是透過TCP來傳輸。每一次的command都有TCP連線傳輸的代價。因此如果有多個command要執行，可以藉由pipeline來減少TCP的overhead.

```php
<?php
$pipe = $redis->multi(Redis::PIPELINE);   
for ($i = 0; $i <  10000; $i++) {   
    $pipe->set("key::$i", str_pad($i, 4, '0', 0));   
    $pipe->get("key::$i");   
}   
$replies = $pipe->exec(); 
```

# 2. 使用 multi-argument commands
因為Redis是single process的程式，因此當一瞬間湧入大量的command時，你會發現平均的latency變長了。這是因為command必須等待前面的command被執行完才輪的到他。因此很明顯的，當如果同時有大量的操作時，使用可同時對多個key/filed操作的command將可以改善這個問題。
例如 
```
set key1 val1
set key2 val2
```
改成更有效率的方式
```
mset key1 val1 key2 val2
```


下面條列出原始和對應優化的方案：

| SingleArgumentCommand | Single-Argument Description |Multi-Argument Alternative| Multi-Argument Description|
| -------- | -------- | -------- | -------- |
| SET   | set the value of key   | MSET   | Set multiple keys to multiple values   |
| GET   | get the value of key   | MGET   | Get the values of all the given keys   |
| LSET   | set value of an element in a list   | LPUSH/RPUSH   | Prepend/append multiple values to a list   |
| LINDEX   | get an element from a list   | LRANGE   | Get a range of elements from a list   |
| HSET   | set the string value of a hash   | HMSET   | Set multiple hash fields to multiple values   |
| HGET   | get the value of a hash field   | HMGET   | Get the values of all the given hash fields   |

# 3. 避免 slow commands for large sets
除了command個數會影響Redis的效能，高時間複雜度的command會大量的使用CPU資源而直接的影響Redis效能。`要記得Redis是single process的程式，而且Redis本身scale out是非常麻煩的。因此當使用大量消耗CPU的command的時候，將會影響Redis的整體表現甚至出現服務中斷。` 因此，避免使用這類的command會是比較好的作法。

如果真的要使用的話，`盡量減少操作的key數或者是資料的大小`。另外由於`List是double linked list的結構，因此對index的操作是沒有效率的。`

| Command| Description |Improve	Performance By|
| -------- | -------- | -------- |
|ZINTERSTORE |取得多個sorted set的交集並存到新的key|降低set的大小或key的個數 |
|SINTERSTORE|取得多個set的交集並存到新的key |降低set的大小或key的個數 |
|SINTER |取得多個set的交集 |降低set的大小或key的個數 |
|MIGRATE |將key從某個redis轉移到新的redis |降低該key的大小 |
|DUMP |取得key值得serialized value |降低大小 |
|ZREM |刪除一個或多個sorted set的element |降低sorted set的element個數 |
|ZUNIONSTORE |將多個sorted set的element聯集存到新的key |降低聯集的key數或sorted set的大小 |
|SORT | 將list/set排序|降低list/set大小 |
|SDIFFSTORE |取得多個sorted set間的差集並存到新的key |降低key數或sorted set的大小 |
|SDIFF |取得多個sorted set間的差集| 降低key數或sorted set的大小|
|SUNION |取得多個sorted set間的聯集 |降低key數或sorted set的大小 |
|LSET |設置list裡某個index的值 |降低list大小 |
|LREM |刪除某個list的某個index |降低list大小 |
|LRANGE |取得list某個區間內的值 |降低list大小 |

#  4. Special encoding of small aggregate data types
Redis 的Set的結構在值比較小的時候(entry 小於 hash-max-ziplist-entries及element 小於 hash-max-ziplist-value)會使用zipmap儲存，而zipmap佔用的memory非常的少。所以舉例來說，如果使用hash來取代key/value的方式紀錄譬如使用者是否要收到通知可以得到更好的memory效率(這個是以計算換取空間，消耗多一點的計算量來降低記憶體的使用，必須自己權衡)。
e.g.
使用key/value紀錄

```php
for($uid=0;$uid<1000000,$uid++){
    $redis->set($uid,1);
}
```

使用set紀錄
```php
for($uid=0;$uid<1000000,$uid++){
    $key=(int)($uid/100);
    $redis->hset($key,$uid,1);
}
```

`使用set儲存可以節省100倍以上的空間(200MB->20MB)`

# 5. 縮短你的key
別忘記key也是需要消耗記憶體的，當你的key一多，加成效應是很恐怖的。例如你的key是 user_access_token:{uid}, 想像一下如果你有一百萬個用戶，這麼多key要耗掉多少記憶體啊？所以縮短一下key名稱會是個好主意。