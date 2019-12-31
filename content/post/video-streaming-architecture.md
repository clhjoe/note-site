---
title: "Video Streaming Architecture"
date: 2019-12-31T22:44:35+08:00
draft: false
tags: ["tips","golang","aws","amazon","s3","video","ffmpeg"]
description: "最近剛好要處理影片上傳並提供串流的需求，這邊分享一下設計的思考方想及參考資料。"
---

# 影片需求
整個流程主要分成四段

1. 上傳
2. 轉檔  
3. 儲存
4. 色情辨識

儲存與色情辨識比較沒有什麼問題，要嘛把須辨識的檔案存到S3要嘛存到EFS後非同步的辨識影片內容。接下來討論前兩個階段的方案。

## 上傳影片方案
上傳到系統分主要有三種方式

* Solution 1: 透過API取得S3 signed URL網址後客戶端將影片上傳到S3, 而這個API可以是API Gateway+Lambda or 自己的API伺服器。
![signed-url-upload-flow](https://pg-media.ksmobile.com/production/material/file/all_111/1577803858.png)
* Solution 2: 客戶端直接將影片透過API上傳到後端
* Solution 3: 在API gateway開一個API然後傳送到Lambda處理



| 比較項目 | S3 sign URL |直接上傳 | API Gateway+Lambda |
| -------- | -------- |-------- |-------- |
| 頻寬損耗   | S3頻寬大，不消耗自有系統頻寬   |佔用API伺服器頻寬   |不佔用API頻寬但Lambda頻寬不確定   |
| 運算負擔   | 幾乎沒有消耗   | 消耗API伺服器運算  | 完全不消耗API伺服器運算  |
| 維護成本   |  小(S3資料傳入頻寬免費, 每次上傳$0.0000051)  | 小量無須新增伺服器   | 稍高   |
| 開發成本   |   中  | 低   | 不可行  |
| 擴充性   |   適用任何Scale需求  | 須隨使用量調整   | 不可行  |
| 限制   |   上傳完成後須再額外通知後台，共需3次API呼叫  | 伺服器須隨使用量調整   |  API 上傳上限10MB  |

## 處理轉檔方案
轉檔可以使用AWS的解決方案或者是自己處理。

* Solution 1: Amazon Elastic Transcoder
* Solution 2: AWS Elemental MediaConvert
* Solution 3: AWS Lambda
* Solution 4: 使用FFMPEG建立自己的轉檔服務，API與轉檔服務間使用EFS共享檔案

| 比較項目 | Amazon Elastic Transcoder |AWS Elemental MediaConvert | Lambda |  自己建立轉檔服務 |
| -------- | -------- |-------- |-------- |-------- |
| 頻寬損耗   | 不佔用API伺服器頻寬   |佔用API伺服器頻寬   |不佔用API頻寬但Lambda頻寬不確定   | EC2<->EFS佔用伺服器頻寬|
| 運算負擔   |不消耗伺服器運算資源   | 不消耗伺服器運算資源   | 不消耗伺服器運算資源   | 消耗伺服器運算資源|
| 開發成本   | 中低| 中低   | 中   | 低|
| 維護成本   | 每分鐘影片$ 0.015| 每分鐘影片$0.0094    | 一個影片大約$0.0000833   | 目前無額外花費|
| 擴充性   |   適用任何Scale需求  |適用任何Scale需求   |  qps< 1,000<br>run time < 900s<br>/tmp < 512M | 須隨使用量調整 |
| 限制   |   轉檔參數有限制  | 轉檔參數有限制   |  轉檔參數無限制  | 轉檔參數無限制 |

# 最終方案
解決方案通常沒有最佳解，只有最適合當下的方案。最終的方案考量 **使用量** 、**開發成本**、**維護成本**、**未來擴充性**決定。整個流程如下：
![Video_Story_Flow](https://pg-media.ksmobile.com/production/material/file/all_112/1577803918.jpg)


