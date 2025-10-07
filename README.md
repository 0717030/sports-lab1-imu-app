# flutter_application_1
```
lib/
├─ main.dart                    # App 入口，掛上 RecorderPage
├─ models/
│  ├─ sample.dart               # ImuSample 資料模型（從 main.dart 抽出）
│  └─ series_bundles.dart       # 裝三個序列與 Y 軸標籤
├─ services/
│  ├─ sensor_service.dart       # 訂閱 sensors_plus、維護最新值、定時寫入 buffer、start/stop
│  └─ integration_service.dart  # 數值積分：a→v、v→x、ω→θ（沿用你原本梯形法＋t0修正）
├─ widgets/
│  └─ imu_chart.dart            # 可重用三軸折線圖 + 離屏繪圖 renderLinesToImage()
└─ pages/
   └─ recorder_page.dart        # UI（滑桿/按鈕/圖例/提示卡/圖表）＋ 分享 CSV/ 分享所有 PNG 邏輯
```