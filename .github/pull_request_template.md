## 📝 Summary
<!-- 簡要說明這個 PR 的目的與背景 -->
<!-- 範例：新增 IMU 校正與 CSV 輸出功能 -->

---

## 🔍 Related Issues
<!-- 若有相關 issue 或任務，請在此連結，例如：
Closes #12
Fixes #34
-->

---

## 💡 Changes
<!-- 以條列方式描述主要修改項目 -->
- 新增 fl_chart 即時顯示 x/y/z 三軸數據
- 新增 path_provider + share_plus 以支援 CSV 輸出
- 加入動作提示卡（方形路徑／翻轉）
- 改善 UI 配色與圖例標示

---

## ✅ Test Plan
<!-- 說明你如何驗證這些變更是有效的 -->
- [ ] Android 模擬器測試感測器值更新
- [ ] 實機錄製與 CSV 檔案比對正確
- [ ] 檢查 share 功能可運作
- [ ] 通過 `flutter analyze` 無錯誤
- [ ] 程式排版符合 `dart format .`

---

## 📸 Screenshots (Optional)
<!-- 若有 UI 變更，請附上對比截圖 -->

| Before | After |
|--------|--------|
| ![Before](link1) | ![After](link2) |

---

## 📦 Checklist
請在完成項目前打勾 ✅  
- [ ] 我已閱讀並遵守 [CONTRIBUTING.md](../CONTRIBUTING.md)
- [ ] PR 專注單一主題、修改合理
- [ ] Commit 訊息符合 Conventional Commits
- [ ] 程式碼已通過基本測試與靜態分析

---

## 🧩 Reviewer Notes
<!-- Reviewer 可在此區留言或備註 -->
