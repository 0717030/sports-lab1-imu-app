# 🏸 Contributing Guide — *sports-lab1-imu-app*

感謝你對本專案的貢獻！  
本文件說明如何在多人協作環境下正確進行開發、同步、提交與合併。  
請所有開發者遵守以下流程與命名規範，以保持版本歷史乾淨一致。

---

## 🧭 Repository 結構

- **主線 (upstream)**：[`yuxuanjian/sports-lab1-imu-app`](https://github.com/yuxuanjian/sports-lab1-imu-app)  
  → 組員主要開發與合併的版本。  
- **個人 fork (origin)**：每位開發者 fork 後的個人倉庫（如 `0717030/sports-lab1-imu-app`）。  
  → 自行開發、測試與發 PR 的地方。

### 🔗 Remote 範例
```bash
git remote -v
origin    https://github.com/0717030/sports-lab1-imu-app.git (fetch)
upstream  https://github.com/yuxuanjian/sports-lab1-imu-app.git (fetch)
```

---

## 🚀 開發前準備

1️⃣ **Fork 本專案**
> 點選右上角「Fork」，建立你的個人副本。

2️⃣ **Clone 你的 fork**
```bash
git clone https://github.com/<你的帳號>/sports-lab1-imu-app.git
cd sports-lab1-imu-app
```

3️⃣ **綁定 upstream**
```bash
git remote add upstream https://github.com/yuxuanjian/sports-lab1-imu-app.git
```

4️⃣ **檢查遠端設定**
```bash
git remote -v
```
應該顯示：
```
origin    https://github.com/<你的帳號>/sports-lab1-imu-app.git
upstream  https://github.com/yuxuanjian/sports-lab1-imu-app.git
```

---

## 🔄 同步最新主線

每次開始新功能或修 bug 前，請先同步組員主線：

```bash
git fetch upstream
git checkout main
git pull --rebase upstream main
git push origin main
```

---

## 🌿 建立開發分支

請**不要直接在 main 開發**。  
以最新 main 為基底，建立獨立 feature 分支：

```bash
git checkout -b <你的名字>/<類型>-<主題> main
```

### 分支命名規範

| 類型 | 用途 | 範例 |
|------|------|------|
| `feature/` | 新功能 | `rita/feature-imu-calibration` |
| `fix/` | 修 bug | `yuxuan/fix-sensor-stream` |
| `refactor/` | 程式重構 | `rita/refactor-ui-layout` |
| `doc/` | 文件更新 | `rita/doc-readme-update` |

---

## 💬 Commit 規範

遵循 [Conventional Commits](https://www.conventionalcommits.org) 標準，  
確保 commit 訊息清晰可追蹤：

```
<type>: <簡短說明>

[可選] 詳細說明
```

### 常見 type
| type | 用途 | 範例 |
|------|------|------|
| feat | 新功能 | `feat: add CSV export and Share button` |
| fix | 修錯誤 | `fix: gyroscope label update on pause` |
| refactor | 重構 | `refactor: unify color theme for x/y/z axis` |
| docs | 文件 | `docs: update contributing guide` |
| chore | 環境設定 | `chore: update flutter_lints to v5.0` |

---

## 🧪 測試與檢查清單

在發出 PR 前，請確保：

- [ ] 程式能在 Android 模擬器正常啟動  
- [ ] 感測器值隨旋轉變化  
- [ ] CSV 正確輸出，檔名與時間戳一致  
- [ ] Share 功能可用  
- [ ] 沒有多餘的 debug print / console.log  
- [ ] 透過 `flutter analyze` / `dart format .` 檢查無誤

---

## 🧩 提交 Pull Request（PR）

1️⃣ 推送分支到你的 fork  
```bash
git push -u origin <你的名字>/<feature-branch>
```

2️⃣ 到 GitHub → 你的 fork 頁面 → 會看到  
**“Compare & pull request”** 按鈕

3️⃣ 設定目標：
```
base repository: yuxuanjian/sports-lab1-imu-app
base branch:     main
head repository: <你的帳號>/sports-lab1-imu-app
compare branch:  <你的名字>/<feature-branch>
```

4️⃣ 撰寫 PR 描述（範例模板）：

```markdown
### Summary
新增 IMU 校正與 CSV 輸出功能

### Changes
- 新增 fl_chart 即時顯示
- 新增 path_provider + share_plus
- 加入動作提示卡（方形路徑／翻轉）

### Test Plan
- 模擬器測試感測器數據更新
- 錄製後檢查 CSV 檔案內容
```

---

## 🔄 同步更新後的流程

主線更新後（PR 被 merge、或組員推新功能）：

```bash
git fetch upstream
git checkout main
git pull --rebase upstream main
git push origin main
```

若你有進行中的分支，可更新基底：

```bash
git checkout <你的名字>/<feature-branch>
git rebase main
# 解決衝突後
git push -f origin <你的名字>/<feature-branch>
```

---

## 🧹 清理舊分支

PR 合併後請清理本地與遠端分支：

```bash
git branch -d <你的名字>/<feature-branch>
git push origin --delete <你的名字>/<feature-branch>
```

---

## 🧱 專案結構建議

```
lib/
 ├── main.dart          # App 進入點
 ├── widgets/           # 自訂 UI 元件
 ├── pages/             # 各功能頁面（例如 SensorRecorderPage）
 ├── services/          # 感測器與檔案 I/O 處理
 └── utils/             # 工具函式（轉換、格式化等）
```

---

## 🛡️ Code Review 與協作守則

- 每個 PR 專注單一主題（避免太大）。  
- Reviewer 可要求修改並附上建議。  
- 不要直接 push 到別人分支。  
- 合併策略採「Squash and merge」，保持 main 線性歷史。  
- 請保持友善、簡潔的討論風格 😊

---

## 🧾 常用 Git 指令速查表

| 操作 | 指令 |
|------|------|
| 同步 upstream | `git pull --rebase upstream main` |
| 建立功能分支 | `git checkout -b rita/feature-imu-calibration main` |
| 推到 fork | `git push -u origin rita/feature-imu-calibration` |
| 合併後刪除 | `git branch -d rita/feature-imu-calibration` |
| 強制刪除（不推薦） | `git branch -D <branch>` |

---

## ❤️ 感謝

感謝所有貢獻者的努力與參與！  
請記得保持分支乾淨、commit 清晰、PR 集中，  
讓我們一起維護一個穩定又漂亮的 Flutter IMU 專案 🚀
