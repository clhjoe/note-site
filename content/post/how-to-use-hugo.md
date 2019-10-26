---
title: "How to Use Hugo"
date: 2019-10-13T19:57:19+08:00
draft: false
tags: ["tips","hugo"]
description: "Hugo是一個靜態網頁產生的工具。你可以透過markdown編輯內容，透過現成的theme或自己撰寫，Hugo可以將你編輯的內容轉為靜態網頁。而放置這些靜態網頁最方便的方法莫過於github.io了"
---

## 甚麼是Hugo?
Hugo是一個靜態網頁產生的工具。你可以透過markdown編輯內容，透過現成的theme或自己撰寫，Hugo可以將你編輯的內容轉為靜態網頁。而放置這些靜態網頁最方便的方法莫過於github.io了。

## 安裝Hugo
**For Mac**
```shell
brew install hugo
```

**For Linux** 
```shell
snap install hugo --channel=extended

or 

sudo apt-get install hugo

```

## 建立新的網站

```sh
#將new-site 替代成你要的網站名稱
hugo new site new-site
```

## 使用Theme

```shell
#將new-site 替代成你的網站名稱,這裡以anake為例。
cd new-site
git init
git submodule add https://github.com/budparr/gohugo-theme-ananke.git themes/ananke
echo 'theme = "ananke"' >> config.toml
```
更多的Theme可以到 [https://themes.gohugo.io/](https://themes.gohugo.io/) 參考

## 新增一篇內文
```shell
hugo new posts/my-first-post.md
```
執行後會在content/posts/ 產生這份md檔，直接編輯內容就好了。如果要刪除這篇文章，也可以直接刪除檔案即可。

## 預覽一下網站吧
```shell
hugo server -D
```
執行後打開瀏覽器，輸入 http://localhost:1313/ 就可以預覽你的網站啦～


## 放置到github
這邊比較tricky。假設你的github帳號是handsomeboy, 如果要把文章放到handsomeboy.github.io，你必須建立**handsomeboy.github.io** 這個repo然後把public這個資料夾(而非整個hugo網站資料夾)推到這個repo。那hugo資料夾的git要怎麼辦呢？你可以再建個repo放整個hugo資料夾。因此更新一個文章，你必須push到兩個repo～

1. 建立 **handsomeboy.github.io**(handsomeboy記得換成妳自己的帳號名稱) 及 hugo-web兩個repo。
2. 將public資料夾推到 **handsomeboy.github.io**
   ```shell
   hugo   #將md檔轉成靜態資料
   cd public
   git init
   git remote add origin git@github.com:handsomeboy/handsomeboy.github.io.git
   git add .
   git commit 
   git push -u origin master
   
   #push完後打開瀏覽器輸入 https://handsomeboy.github.io 應該就要可以看到你的文章啦～(如果沒看到可以檢查一下.md檔，記得把開頭的drafte改成false) 

   ```
   
3. 將hugo送進git
   ```shell
   cd ..
   git remote add origin git@github.com:handsomeboy/hugo-web.git
   git add .
   git commit 
   git push -u origin master
```