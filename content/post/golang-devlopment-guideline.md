---
title: "Golang Development Guideline"
date: 2019-12-31T22:34:10+08:00
draft: false
tags: ["tips","golang"]
description: "Golang是我們公司開發API的語言之一，好的開發規範不僅可以讓大家在開發上更順手，也能讓程式保持一定水準甚至確保程式性能。"
---

###  1. 使用uber-go/zap 來印出Log
  a. zap是性能非常好的log套件，避免過度alloc memory及非同步的操作log可以大幅度的避免影響程式效能 
  b. 使用zap來取代fmt.Print
  c. 避免在zap.Debug中使用fmt.Sprintf(fmt.Sprintf仍是消耗較大的API)
  <table><body><tr>
<td style="font-weight:bold;text-align:center;">DON't</td><td style="font-weight:bold;text-align:center;">DO</td></tr>
<tr><td>

```golang
fmt.Println("phoneNumber %s", phoneNumber)
```
OR
```golang
import "uber-go/zap"

zap.Debug(fmt.Sprintf("Update phone number %d ", phoneNumber))
```
</td>
<td>
```golang
import "uber-go/zap"

zap.Debug("Update phone number", zap.String("phone_number", phoneNumber))
```
</td></tr>
</body>
</table>


### 2. 使用defer來釋放資源
  a. 很大程度的避免漏掉關閉或移除建立的資源
  <table><body><tr>
<td style="font-weight:bold;text-align:center;">DON't</td><td style="font-weight:bold;text-align:center;">DO</td></tr>
<tr><td>

```golang
tx := core.DB.Begin()
err = models.ResetPhone(tx, cInfo.UIDStr, "0", false)
if err != nil {
  tx.Rollback()
} else {
  tx.Commit()
}
```
</td>
<td>

```golang
tx := core.DB.Begin()
defer func (){
  if err != nil {
      tx.Rollback()
  } else {
      tx.Commit()
}
}()
err = models.ResetPhone(tx, cInfo.UIDStr, "0", false)
```
</td></tr>
</body></table>

### 3. 處理Type轉換錯誤
 a. 如果不處理錯誤，當型別錯誤時將產生panic
  <table><body><tr>
<td style="font-weight:bold;text-align:center;">DON't</td><td style="font-weight:bold;text-align:center;">DO</td></tr>
<tr><td>

```golang
t := i.(string)
```
</td>
<td>

```golang
t, ok := i.(string)
if !ok {
  // 處理錯誤
}
```
</td></tr>
</body></table>

### 4. 優先使用strconv避免使用fmt
 a. strconv效能是fmt的一倍以上
  <table><body><tr>
<td style="font-weight:bold;text-align:center;">DON't</td><td style="font-weight:bold;text-align:center;">DO</td></tr>
<tr><td>

```golang
for i := 0; i < b.N; i++ {
  s := fmt.Sprint(rand.Int())
}
```
</td>
<td>

```golang
for i := 0; i < b.N; i++ {
  s := strconv.Itoa(rand.Int())
}
```
</td></tr>
</body></table>

### 5. 不要使用Panic
 a. 每個錯誤應該有對應的處理方式而非使用panic
  <table><body><tr>
<td style="font-weight:bold;text-align:center;">DON't</td><td style="font-weight:bold;text-align:center;">DO</td></tr>
<tr><td>

```golang
func foo(bar string) {
  if len(bar) == 0 {
    panic("bar must not be empty")
  }
  // ...
}
```
</td>
<td>

```golang
func foo(bar string) error {
  if len(bar) == 0 {
    return errors.New("bar must not be empty")
  }
  // ...
  return nil
}
```
</td></tr>
</body></table>