<div align="center">

# VibeaseMusic

**原生 macOS 网易云音乐客户端 · 纯粹、沉浸、轻量**

SwiftUI 编写 · 直连网易云真实 API · 深度适配 macOS 体验

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue?logo=apple)](#构建)
[![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?logo=swift&logoColor=white)](Package.swift)
[![License](https://img.shields.io/badge/license-LGPL--3.0--only-orange)](LICENSE)

</div>

## 特性亮点

- 🪟 **完善的窗口生命周期** — 关闭窗口音乐后台静默播放，点击 Dock 图标秒级恢复唤醒
- 🎛️ **顶部菜单栏控制器 (MenuBar Extra)** — 动态菜单栏状态图标，支持浮窗控制切歌、拖动进度、调音量与桌面歌词开关
- 🔐 **扫码登录** — 网易云 App 扫码，Cookie 本地持久化，自动续期
- 🏠 **丰富推荐** — 每日推荐、私人漫游、心动模式、推荐歌单、雷达歌单、排行榜、新碟上架
- 🎵 **高保真播放** — 原生 AVPlayer 引擎，标准 ~ Hi-Res 音质，支持黑胶 VIP 无损音质
- 🔓 **灰色歌曲解锁** — 原生实现第三方音源匹配（酷我 / 酷狗 / pyncmd 等），无版权歌曲无缝补全
- 🖼 **沉浸播放页** — 封面取色动态渐变背景 + 大封面 + 大字同步歌词
- 📝 **双重歌词系统** — 侧边毛玻璃歌词面板 + 置顶悬浮桌面歌词（支持翻译、全屏跨 Space 显示）
- 📚 **完整音乐库** — 我喜欢的音乐、歌单管理、收藏专辑、关注歌手、音乐云盘

## 快速构建与运行

要求：macOS 15+、Xcode 16+（Swift 6+）

```bash
# 编译
swift build

# 打包应用为 .app Bundle
./Scripts/build-app.sh debug

# 一键打包并启动应用
./Scripts/compile_and_run.sh
```

## 协议与致谢
- 基于 LGPL-3.0 协议开源。
- 感谢 [Kumone](https://github.com/missuo/kumone)、[YesPlayMusic](https://github.com/qier222/YesPlayMusic)、[LyricsX](https://github.com/ddddxxx/LyricsX) 等开源项目的启发。
