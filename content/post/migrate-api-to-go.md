---
title: "Migrate API to Go"
date: 2019-10-20T19:26:31+08:00
draft: false
tags: ["tips","golang","architecture","aws","cloudfront","nginx","proxy","go"]
description: "大家應該或多或少都有經驗要將某個語言實做的API搬到另一種語言重寫。原因總是有千千百百種，但是有時候當專案很大，沒辦法一次搬完的時候又該怎麼辦呢？分享一下我們的例子。原先的API是使用PHP來撰寫，但因為幾個原因所以我們決定把他搬到Golang。這裡分享我們搬到Golang的前因後果及方案分析。"
---

## 前言
大家應該或多或少都有經驗要將某個語言實做的API搬到另一種語言重寫。原因總是有千千百百種，但是有時候當專案很大，沒辦法一次搬完的時候又該怎麼辦呢？分享一下我們的例子。<br>
原先的API是使用PHP來撰寫，但因為幾個原因所以我們決定把他搬到Golang。

1. 原始PHP版本留在PHP 5.3，是一個效能不好(compare to PHP 7)以及不被維護的版本。要升級得顧慮沒有人維護的framework，所以是個大工程。
2. 因為業務的需要，一個API request有很多可以平行化處理的事情，如果一步步來其實速度慢又浪費資源，改用Golang可以帶來大幅度的效能提昇。
3. 我們原始業務一直是使用Golang，在QPS > 2w的環境上驗證過，所以成熟度完全不是問題。

因此最後決定新的API就以Golang撰寫，有需要動到舊有的API且時間足夠再搬到Golang。這時候就遇到一個問題啦，同時兩套語言寫成的API要怎麼共存的？當時想到透過切分域名或切分request path也就是routing來達成，分成幾個維度來看～

## 切分域名
切分域名就如字面上的意思，舊的API用原有的域名，新的API用心的域名。簡單明瞭不囉唆。但同時也有不便之處。

### 優缺點分析
#### 優點
* 新舊API切分乾淨，新的API不會影響舊版的APP。
* 針對新舊API可以有完全不同的API設定，例如快取規則、HTTPS的SSL版本、及開啟HTTP/2等等

#### 缺點
* 如果僅僅是想要優化API以Golang改寫，將只有新版的APP用戶會拉取，而一般APP的版本到達率...慘
* 萬一同個API以Golang實做了，在未來如果要更改邏輯則必須兩個語言都要同時更改，增加開發及測試的複雜度
    


## 切分Routing

### 透過CDN切分
以Cloudfront為例，透過Cloudfront可以將不同的PATH Route到不同的Origin，甚至我們可以針對不同的PATH設定不同的快取時間、通訊協定、要cache的query parameter或header等等。
<img src="https://pg-media.ksmobile.com/production/material/file/all_92/1571574856.png" style="height:550px"></img>

### 透過Proxy(Nginx)切分
我們可以在Proxy例如Nginx來設定不同的PATH要使用PHP或者是forward到Go API。

```nginx
# /v1/user forward到PHP
location /v1/user {
	if (!-e $request_filename) {
		rewrite ^/(.*)$ /index.php last;
	}
}
# /v1/user/points 則forward到golang
location  /v1/user/points {
	proxy_pass http://localhost:19002;
}

```

### 在Golang裡切分

這邊以Gin為例，我們把所有的request都導到Go API，如果API在golang裡面有實做則直接由GO處理，否則就proxy到原有的PHP API處理

```go

package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "pong",
		})
    })
    //放你所有的API
    //...
    
    //當上面的PATH都沒命中則pass到PHP
    r.NoRoute(func(c *gin.Context) {
		director := func(req *http.Request) {
			req.URL.Scheme = "http"//使用http省下ssl解析時間
			req.Header.Add("Host", "php-api.xxx.com")//php.api替換成你的PHP url
			req.Host = "php-api.xxx.com" //同上
		}
		proxy := &httputil.ReverseProxy{Director: director}
		proxy.ServeHTTP(c.Writer, c.Request)
	})
	r.Run() // listen and serve on 0.0.0.0:8080
}

```

## 方案分析及結論

| 考量維度    |                            切分域名                            |            使用同個域名但routing切開 |
| :---------- | :------------------------------------------------------------: | -----------------------------------: |
| 修改舊有API | 只有新版的APP才會使用到新的API。舊版用戶得等版本到達率整個慘。 | 因為API path不變，因此新舊版同時生效 |
| 新增API     |                         直接切開，清爽                         |      透過設定routing來切分，比較瑣碎 |

因為我們必須讓使用舊版的用戶也可以馬上生效，最後我們選擇使用同個域名。如果不在乎這個，其實切分域名還是比較方便的。

最後比較一下透過PATH切分不同方法的優缺點：

1. 在CDN切 
<br>**好處：**像Cloudfront可以提供route到不同的origin, 分別設ttl, cache條件等等很方便。
<br>**壞處：**換CDN或不同國家使用不同的CDN就GG，不是每家CDN都支援。每次有新的API都得確認一次routing很煩  

2. 前面放個Proxy e.g.Nginx
<br>**好處：** Nginx熟悉的人很多，也很直覺
<br>**壞處：** 每次有新的API都得確認一次routing，量一多挺亂的 

3. 在Golang裡面切
<br>**好處：** 在程式裡設routing，都不中則proxy到PHP，不須額外設定第三方或其他套件
<br>**壞處：** 要寫程式＠＠？

