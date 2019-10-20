---
title: "Migrate API to Go"
date: 2019-10-20T19:26:31+08:00
draft: false
---
大家應該或多或少都有經驗要將某個語言實做的API搬到另一種語言重寫。原因總是有千千百百種，但是有時候當專案很大，沒辦法一次搬完的時候又該怎麼辦呢？分享一下我們的例子，原先的API是使用PHP來撰寫，但因為幾個原因所以我們決定把他搬到Golang。

1. 原始PHP版本留在PHP 5.3，是一個效能不好(compare to PHP 7)以及不被維護的版本，要升級得顧慮沒有人維護的framework所以是個大工程。
2. 因為業務的需要，一個API request有很多平行可以處理的事情，如果一步步來其實速度慢又浪費資源。
3. 我們原始業務一直是使用Golang，所以也很熟了。

因此最後決定新的API就以Golang撰寫，有需要動到舊有的API且時間足夠再搬到Golang。這時候就遇到一個問題啦，同時兩套語言寫成的API要怎麼共存的？分成幾個維度來看～
## 切分域名

| 考量維度  |      切分域名              |  使用同個域名但routing切開 |
|----------------|:-----------------------------:|------:|
| 修改舊有API |  <img width=20/>只有新版的APP才會使用到新的API。舊版用戶得等版本到達率整個慘。 | <img width=20/>因為API path不變，因此新舊版同時生效|
| 新增API |    直接切開，清爽   |   透過設定routing來切分，比較瑣碎 |

因為我們必須讓使用舊版的用戶也可以馬上生效，最後我們選擇使用同個域名。如果不在乎這個，其實切分域名還是比較方便的。
    


## 切分Routing

### 透過CDN切分

![透過Cloudfront可以將不同的PATH Route到不同的Origin](https://pg-media.ksmobile.com/production/material/file/all_92/1571574856.png)


### 透過Nginx切分

```
# /v1/user forward到PHP
location /v1/user {
    proxy_set_header X-Request-Id $request_id;
	if (!-e $request_filename) {
		rewrite ^/(.*)$ /index.php last;
	}
}
# /v1/user/points 則forward到golang
location  /v1/user/points {
    proxy_set_header X-Request-Id $request_id;
	proxy_pass http://localhost:19002;
}

```

### 透過Golang切分

這邊以Gin為例

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
			req.URL.Scheme = "http"
			req.Header.Add("Host", "php.api")//php.api替換成你的PHP url
			req.Host = "php.api" //同上
		}
		proxy := &httputil.ReverseProxy{Director: director}
		proxy.ServeHTTP(c.Writer, c.Request)
	})
	r.Run() // listen and serve on 0.0.0.0:8080
}

```

最後比較一下不同方法的優缺點

1. 在CDN切 
<br>**好處：**像Cloudfront可以提供route到不同的origin, 分別設ttl, cache條件等等很方便。
<br>**壞處：**換CDN或不同國家使用不同的CDN就GG，不是每家CDN都支援。每次有新的API都得確認一次routing很煩  

2. 前面放個Proxy e.g.Nginx
<br>**好處：** Nginx熟悉的人很多，也很直覺
<br>**壞處：** 每次有新的API都得確認一次routing，量一多挺亂的 

3. 在Golang裡面切
<br>**好處：** 在程式裡設routing，都不中則proxy到PHP，不須額外設定第三方或其他套件
<br>**壞處：** 要寫程式＠＠？

