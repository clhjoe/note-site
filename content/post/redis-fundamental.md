---
title: "Redis Fundamental"
date: 2019-12-31T22:59:50+08:00
draft: false
tags: ["tips","php","redis"]
description: "Redis 與Memcached兩套是常見的資料的快取服務。藉由將資料存放在記憶體中，可以解決傳統上RDB難以滿足瞬間大量存取的問題。然而因為Redis還提供了豐富的資料型態操作，因此也可以將他作為持久化的資料儲存方案。但是，人生總有個但是，也因為資料是存放在記憶體中，因此如果資料量擴展到一定的程度將對成本有劇烈的影響。所以如何妥善的使用Redis是一個很大的課題。"
---

# Redis 基礎
## Redis資料型態
Redis提供了豐富的資料型態操作

1. **Binary-safe strings**:簡單來說你可以存放字串或是binary。
2. **Lists**: 按照插入順序排序的字串集合。基本上就是一個linked lists.
3. **Sets**: 一群唯一(unique)的且未經排序的字串集合。
4. **Sorted sets**: 與Set集合很像差別在sorted set每一個string都有一個float的score值，Redis會依照Score值來做排序。String element仍然是unique但score可以重複。
6. **Hashes**: 即為一個map的結構，其key/value都是string。Redis的hashs與 Ruby 或 Python hashes 相似。
7. **Bit arrays (or simply bitmaps)**: 簡單的說就是一個連續的二進位數字，每一個位置(offset)在bitmap上可以執行AND/OR/XOR等等操作。
8. **HyperLogLogs**: 簡單的說就是用來估計一個隨機資料結構的集合的基數。更簡單一點譬如說計算每個ip每天的access次數。

但是，人生總有個但是，也因為資料是存放在記憶體中，`因此如果資料量擴展到一定的程度將對成本有劇烈的影響。所以如何妥善的使用Redis是一個很大的課題。`

# Redis 基礎用法
## 1. STRING
 String 是memcached 唯一支援的資料結構。簡單的key/value用法是最多初學者第一個使用的型態。

**常見的使用情境有:**

1. 限制使用者每分鐘的使用次數(限流)
2. 暫存首頁response結果

### 快取資料
譬如說，當一個web page的首頁是靜態的或是不需要頻繁更新的時候，我們可以將結果(HTML or Json)存入cache。這樣一來可以減少許多DB的消耗及計算。

或是我們可以將user的token存入cache中，這樣我們可以很快的比較使用者的token是否合法。
```php
<?php
//SET key value [EX seconds] [PX milliseconds] [NX|XX] ; Time complexity: O(1)
//GET key ; Time complexity: O(1)
$redis->set('user_token:111', 'WFWEWEFEWF',86400);
$token=$redis->get('get user_token:111');
echo $token; // "WFWEWEFEWF"
```

### Page View計算
例如我們可以是用INCR來累加page view. INCR的操作是Atomic的，或是我們也可以使用INCRBY 10來atomic 的將值加10。

另外我們也可以使用GETSET來將某個key設一個新的值同時又回傳舊的值。舉例來說，我們每個小時去取page view的個數然後將他清空，這時候可以用GETSET將這個key的值設為0然後又取得過去一個小時的page view的值。
```php
<?php
//INCR key ; Time complexity: O(1)

$count=$redis->incr('pageview'); //$count=1 if pageview does not exists, otherwise, return pageview+1
$viewLastHour=$redis->getset('pageview',0);
```

### 限流
或是我們可以拿來做限流的設置

```php
$key='call_counter:111';
$redis->incr($key);
$count=$redis->get($key));
if($counter>10){
  //too much request performed
}elseif($count==1){
	$redis->expire($key,60);
}
```

### 取得substring
```php
<?php
//GETRANGE key start end ; Time complexity: O(N)
$redis->set('page_info:home','hello everyone');
$subString=$redis->getrange ('page_info:home', 0, 4);//return 'hello'
```

### 刪除暫存資料(適用所有資料型態)
```php
//DEL key [key ...]; Time complexity: O(N)
$redis->del('user_token:111');
```

### 確認是否已暫存(key是否存在,適用所有資料型態)
```php
<?php
//EXISTS key [key ...]; Time complexity: O(1)
$exist=$redis->exists('user_token:111');//return true if key exists, otherwise, return false
```

### 更改key的名字(適用所有資料型態)
```php
<?php
//RENAME key newkey; Time complexity: O(1)
$redis->rename('usertoken:111','user_token:111');
```

### 查詢符合指定pattern的key list((適用所有資料型態))
**在production環境中禁用**，因為keys會一個個檢查Redis中所有的key，當你的Key非常多的時候會讓你的Redis無法回應其他正常的Requests。
> use only if you're debuing or truibleshooting
```php
<?php
//KEYS pattern; Time complexity: O(N)
$list=$redis->keys('user_token:*');
```

## 2. LIST
Redis 的 List是以Linked List(or ziplist)來實做，因此將一個值插入一個擁有一萬筆List的頭或尾巴跟插入只有10筆List的頭或尾巴都是一樣的，因為只需要常數時間即可完成。然而也正是因為如此，`對於指定某個index的操作(例如刪除第N筆)就不是他所擅長的。` 如果需要常常對index操作建議使用sorted set。

**List可以用來例如：**
1. 某個post的最後幾筆comment
2. 當作queue 來使用(利用lpush將資料塞入list, rpop將資料取出並刪除,或是使用brpop blocking pop當有資料的時候才返回).
3. Top N 的list

我們可以建立一個list儲存top 100的使用者清單。

### 快取Top N排名資料
例如，假設我們有個排行榜，如果每次都去資料庫計算排行那也太浪費資料庫的運算資源了吧？因此我們可以將計算完後的資料快取在Redis。
```php
<?php
//LPUSH key value [value ...]; Time complexity: O(1)
//LRANGE key start stop;Time complexity: O(S+N) where S is the distance of start offset from HEAD for small lists, from nearest end (HEAD or TAIL) for //large lists; and N is the number of elements in the specified range.
$redis->lpush('top_user:100','912020');
$redis->lpush('top_user:100','912021');
$redis->lpush('top_user:100','912022');
$redis->lpush('top_user:100','912023');
$redis->lrange('top_user:100', 0, 2);
/*
1) "912023"
2) "912022"
3) "912021"
*/
```

### 只保留N筆資料
```
ltrim [key] N
redis>ltrim top_user:100 100
```

### 把Redis當Queue用
利用lpush將資料插在List的左邊，Rpop從右邊取出，先進先出這不就是Queue了嘛！？

```
rpop [key]
redis>lpush task_list 912020
redis>lpush task_list 912021
redis>rpop task_list
"912020"
```

## 3. HASHS
hash相當於JAVA 的hashmap或c#的dictionary, 一個key裡面可以有一個map的結構。以一個userinfo為例子，`當常常需要針對userinfo某個值做操作就可以使用hash,否則直接將userinfo以json做encode後存入會比較快速。`

###  快取User Info
假設一個使用者有多個資料，例如 id, nickname,like_count ...等等。我們當然可以把他包成json直接用set存放，可是如果我們想更改其中一個欄位例如like_count怎麼辦呢？用Get把快取拿出來，更新like count在存回去？別鬧了，會有race condition的問題。因次我們可以使用Map來存放資料。
```
hset [key] [map_key] [map_value]
hget [key] [map_key]
redis> hset user_info:111 id 10
redis> hset user_info:111 nickname "jack"
redis> hget user_infp:111 nickname
"jack"
redis> hincr user_infp:111 like_count
redis> hget user_infp:111 like_count
"1"
```

## 4. SETS
redis 的set跟list很像，但最大的差別在`set裡面是不能有重複的值而且是沒有順序性的`。可以把他想像成JAVA的HashSet。利用Set, 我們可以透過Redis的command做到intersection, union or difference between multiple sets 等等的操做。

**常見的使用情境有:**

1. 存放某個tag的集合(e.g.查詢A及B的tag清單)
2. 存放人的朋友清單(e.g. 查詢共同朋友)

### 查詢共同好友
把A的好友放進一個List, B的好友放到另個List, 使用sinter找出交集就可以得到共同朋友啦。

```
redis>sadd friend:jack martin
redis>sadd friend:jack mars
redis>sadd friend:susan mars
redis>sadd friend:susan kenny
redis>sinter friend:jack friend:susan
"mars"
```

##  5. Sorted Set
sorted set顧名思義就是有排序的set. `當不需要排序的時候，還是建議使用set結構。`每一個sorted set裡面的值都包含一個score，而sorted set正是利用score值來做排序。排序的依據如下：
If A and B are two elements with a different score, then A > B if A.score is > B.score.
If A and B have exactly the same score, then A > B if the A string is lexicographically greater than the B string. A and B strings can't be equal since sorted sets only have unique elements.

**常見的使用情境有:**

1. 存放排名列表(e.g. top 100的熱門user or 快速得到某位user的排名)

### 即時排行top 100

```
zadd [key] [score] [value]
zrangebyscore [key] [min] [max] [WITHSCORES(OPTIONL)] [LIMIT offset count (OPTIONAL)]
redis> zadd challenge:#foody 101 post:1101
redis> zadd challenge:#foody 102 post:1102
redis> zadd challenge:#foody 103 post:1103
redis> zadd challenge:#foody 104 post:1104

//取出所有資料
redis> zrangebyscore challenge:#foody "-inf" "+inf"
1) "post:1101"
2) "post:1102"
3) "post:1103"
4) "post:1104"

//取出資料時也回傳score值，並限制從第1筆開始只取出兩筆
redis> zrangebyscore challenge:#foody "-inf" "+inf" withscores LIMIT 0 2
1) "post:1101"
2) "100"
3) "post:1102"
4) "102"
```
## 6. Bitmaps
Bitmap 嚴格說起來不是一個資料型態，相反的它比較像是在string型態上的bit操作。由於String型態是binary safe blobs而且上限是512MB，因此Bitmaps最多支援232個bit。
Bitmap的操作主要分成兩個，一個是常數時間的setbit/getbit操作，另一個是對整個bit group的操作，例如計算幾個bit被設成1。
Bitmap最大的好處是`非常節省memory空間。`舉例來說，紀錄4 billion個user需不需要收到訂閱的資訊只需要512MB的memory。

**常見的使用情境有:**

1. real time的統計分析
2. 需要節省空間且快速的依據object ID來關聯的bool資訊

### 統計每天的user login數
假設每個bit代表一個user e.g. bit 0->uid 1, bit 1->uid 2 依此類推 
```
SETBIT key offset value
GETBIT key offset
BITCOUNT key [start end]
> setbit(login:yyyy-mm-dd, user_id, 1)
(integer) 1
> getbit login:yyyy-mm-dd 10 //取得uid:10的使用者有沒有登入
(integer) 1
> bitcount  login:yyyy-mm-dd //查看今天有多少使用者登入
(integer) 1
```
或是我們可以每位使用者一個key, 第一天有登入bit 0就設1, 第三天有登入 bit 2就設1，最後使用bitcount就可得知使用者登入了幾天。

## 7. HyperLogLog
HyperLogLog 是統計學上的資料結構，他是用來統計一個key中unique的個數。一般來說，計算unique的個數需要很多的記憶體，因為你必須紀錄哪些項目已經計算過。然而在Redis中允許你使用HyperLogLog來計算unique的值，誤差小於1%且最多佔用12K bytes.

**常見的使用情境有:**

1. 統計一天當中有多少不同的search query

### 統計一天中有多少不同的搜尋詞
使用的方式非常簡單，使用pfadd將項目加入到一個key, 並且使用pfcount來取得unique的個數。

```
> pfadd hll a b c d
(integer) 1
> pfcount hll
(integer) 4
```

| command | time complexity |usage|
| -------- | -------- | --------|
| PFADD key element [element ...]| O(1) |將值加入key |
| PFCOUNT key [key ...]|  O(N) N為key的個數 |取得key裡的unique element個數|
| PFMERGE destkey sourcekey [sourcekey ...]|  O(N)  |將多個key merge到destkey|


##  8. Message queue

Redis也支援pub/sub的操作，producer利用PUBLISH 將message publish到redis中，consumer利用subscribe取得message。


### Pub/sub 範例
producer:

```
PUBLISH key Hello
```

consumer:

```
SUBSCRIBE key
```

# 結論
在使用Redis command之前，請務必了解其時間複雜度與影響資料的長度。**錯誤的使用Redis型態、命令將可能導致Redis效能出現瓶頸而影響整個服務！**

條列出不同資料型態適合的場景如下：

**String** 

1. 限制使用者每分鐘的使用次數(限流)
2. 暫存首頁response結果

**LIST**

1. 某個post的最後幾筆comment
2. 當作queue 來使用(利用lpush將資料塞入list, rpop將資料取出並刪除,或是使用brpop blocking pop當有資料的時候才返回).
3. Top N 的list

**HASHS**

1. 需要對結構的filed操作(e.g. userinfo, postinfo)

**SETS**

1. 存放某個tag的集合(e.g.查詢A及B的tag清單)
2. 存放人的朋友清單(e.g. 查詢共同朋友)

**Sorted Set**

1. 存放排名列表(e.g. top 100的熱門user or 快速得到某位user的排名)

**Bitmaps**

1. 快速的、使用較小memory空間紀錄某個ID(uid, pid whatever)例如登入次數、登入天數、或者是是否要收到通知等等紀錄。

**HyperLogLog**

1. 快速的統計一個集合中的unique elements