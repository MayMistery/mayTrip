# 日图

一次旅行是一张能按天来读的安静地图。把机票（含多段、开口票）、跨城交通、每晚住宿和当天的景点放在同一条路径上，站与站之间记下方式和预估时间，真正出发时把导航交给苹果地图或高德。

这是 iOS 第一版。不做预订商城、广告、预算分账、打包清单、用对话生成行程，也没有实时共编。

## 要求

- macOS 与 Xcode 16 或更高版本（iOS 18 SDK）
- 一部 iPhone，或 iPhone 模拟器

本仓库是在 Linux 上整理的，无法在这里编译 iOS。请在 Mac 上打开并编译。

## 在 Mac 上打开和编译

1. 把整个 `Ritu` 文件夹拷到 Mac。
2. 用 Xcode 打开 `Ritu.xcodeproj`。
3. 在 Signing & Capabilities 里选中你的开发团队（Team）。工程里没有写入 Team ID 或证书。
4. 选一台 iPhone 模拟器或真机，按 ⌘R 运行。

也可以在终端里：

```bash
cd Ritu
xcodebuild -scheme Ritu -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug
```

## 标识

| 项 | 值 |
| --- | --- |
| 显示名 | 日图 |
| Bundle ID | `com.maybemia.ritu` |
| 最低系统 | iOS 18.0 |
| 语言 | 界面默认简体中文，并带英文文案 |

## 第一次打开

新安装是空的。首页可以按「载入示例行程」，会加入一趟 2027 年 4 月的「西班牙与葡萄牙」示例：去程经巴黎转机到马德里、两地住宿、马德里到里斯本的跨城航班，以及回程。示例时刻仅供演示，不会在安装时自动写入。

## TestFlight

上传需要一台 macOS 构建机（例如 GitHub Actions 的 macOS runner、Xcode Cloud，或其他云端 Mac），以及 App Store Connect API 密钥（`.p8`、Key ID、Issuer ID）。本工程还没有配置签名证书或 Team ID。等在 Xcode 里选定团队、Archive 成功后，再用 Fastlane 或 `xcodebuild` 上传到 TestFlight。

## 地图与搜索

地图画布使用 MapKit，不用 Google Maps SDK。地点搜索默认走 `MKLocalSearch`。国内长尾地点搜索预留了高德接口（`AmapPlaceSearchProvider`）：需要在 [高德开放平台](https://lbs.amap.com/) 申请 Web 服务 Key，填入 `Info.plist` 的 `AMAP_WEB_SERVICE_KEY`。在此之前，高德搜索不会发起网络请求。坐标在应用内按 WGS-84 存储；与高德交换时需注意 GCJ-02 转换，相关说明写在 `Services/CoordinateConversion.swift` 和 `Services/AmapPlaceSearchProvider.swift`。
