# 📘 VibeaseMusic 项目交接文档 (Project Handover for Codex)

> **交接日期**：2026-09-22（已复核当前代码并刷新，覆盖 08-19 之后全部改动）
> **工作区状态**：git 主干仍为旧 `Kumone` 基线；`Sources/Kumone`（已跟踪）被删除、新 `Sources/VibeaseMusic` 为未跟踪目录，改动尚未提交；最近一次源码修改为 08-19，之后无其他 agent 动过项目（已按文件时间与关键标记核对）  
> **项目名称**：`VibeaseMusic` (Bundle ID: `com.vibease.music`)  
> **本地仓库路径**：`/Users/mac/Projects/VibeaseMusic`  
> **目标运行环境**：macOS 15.0+ (Sequoia / Sonoma), Apple Silicon & Intel  
> **核心技术栈**：Swift 6, SwiftPM, SwiftUI, AppKit Interop, AVFoundation, Sparkle

---

## 1. 快速上手与构建指南 (Quick Start & Build)

### 常用命令
```bash
# 1. 调试构建并打包为 macOS .app 应用
./Scripts/build-app.sh debug

# 2. 发布构建（Release 模式）
./Scripts/build-app.sh release

# 3. 安装到系统应用程序目录并启动运行
rm -rf /Applications/VibeaseMusic.app
cp -R .build/app/VibeaseMusic.app /Applications/VibeaseMusic.app
open /Applications/VibeaseMusic.app

# 4. 图标生成流水线（如需修改图标）
swift Scripts/generate_icns.swift
# 会自动根据 Resources/AppIconPreviews/ 生成 AppIcon.icns 与 Resources/AppIcon_1024.png
```

### 构建产物结构
- `.build/app/VibeaseMusic.app`：原生 macOS App Bundle。
- `Contents/MacOS/VibeaseMusic`：可执行主程序。
- `Contents/Resources/AppIcon.icns`：原生全尺寸图标包。
- `Contents/Frameworks/Sparkle.framework`：自动更新框架。

---

## 2. 核心代码架构与文件导航 (File Map)

```
VibeaseMusic/
├── Package.swift                                # SPM 依赖管理 (Sparkle, Crypto, etc.)
├── Scripts/
│   ├── build-app.sh                             # 打包脚本：组装 Info.plist、Frameworks、icns
│   └── generate_icns.swift                      # 原生 CoreGraphics 矢量 Squircle 图标生成脚本
├── Sources/VibeaseMusic/
│   ├── VibeaseMusicApp.swift                    # App 入口、单窗口生命周期、菜单栏快捷键
│   ├── Core/
│   │   ├── Player/
│   │   │   ├── PlayerService.swift              # 核心播放服务 (AVPlayer, 队列, 进度, 歌词匹配)
│   │   │   └── NowPlayingManager.swift          # 系统控制中心与锁屏媒体信息 (MPNowPlayingInfoCenter)
│   │   ├── Network/
│   │   │   ├── NeteaseAPI.swift                 # 网易云接口封装 (推荐, 歌单, 专辑, 歌手, 排行榜)
│   │   │   ├── NeteaseClient.swift              # 网络请求客户端
│   │   │   └── NeteaseCrypto.swift              # WEAPI / EAPI 逆向加解密算法
│   │   ├── Account/
│   │   │   └── AccountStore.swift               # 用户状态、Cookie 持久化、喜欢歌曲管理
│   │   ├── WindowManager.swift                  # 窗口生命周期管理 (拦截关闭事件、单实例唤醒)
│   │   └── Storage/
│   │       ├── ImageCache.swift                 # 异步图片内存与磁盘缓存 (CachedAsyncImage)
│   │       └── SettingsManager.swift            # 用户设置与外观持久化
│   ├── DesignSystem/
│   │   ├── Theme.swift                          # 主题规范、设计常量、毛玻璃封装 (compatGlass)
│   │   ├── Cards.swift                          # 卡片通用组件 (CoverCard, ArtistCard, Shelf, CardGrid)
│   │   └── Components.swift                     # 骨架屏、Toast、按钮样式
│   └── Features/
│       ├── MainWindow.swift                     # 主窗口结构 (NavigationSplitView, Overlay 架构)
│       ├── Navigation.swift                     # 路由定义 (Destination, SidebarItem, playerChrome)
│       ├── SidebarView.swift                    # 左侧边栏 (导航项, 创建/收藏歌单列表, 用户卡片)
│       ├── Home/HomeView.swift                  # 推荐首页 (精选雷达, 推荐歌单, 每日推荐)
│       ├── Detail/
│       │   ├── ArtistDetailView.swift           # 歌手主页 (热门歌曲, 专辑, 描述)
│       │   ├── ArtistAlbumsView.swift           # 歌手全部专辑独立网格页面
│       │   ├── AlbumDetailView.swift            # 专辑详情
│       │   └── PlaylistDetailView.swift         # 歌单详情 (歌曲列表, 批量操作)
│       ├── Player/
│       │   ├── PlayerBar.swift                  # 底部常驻毛玻璃播放控制条
│       │   ├── NowPlayingView.swift             # 全屏沉浸歌词页 (大封面, 动态渐变背景, 滚动歌词)
│       │   ├── DesktopLyrics.swift              # 桌面悬浮歌词控制器与窗口
│       │   └── Panels.swift                     # 侧边弹出歌词与播放队列抽屉
│       └── MenuBar/MenuBarView.swift            # macOS 系统顶栏 Mini 播放器
```

---

## 3. 已实现并验证的功能 (Completed Features)

1. **单窗口模式与 Dock 重复点击唤醒**：
   - 采用 `Window("VibeaseMusic", id: "main")` 单窗口声明。
   - `MainWindowDelegate` 拦截 Cmd+W 与红绿灯关闭按钮为 `orderOut`（隐藏窗口而非销毁），再次点击 Dock 图标时通过 `WindowManager.showMainWindow()` 恢复显示，彻底解决了打开两个 App 窗口的 Bug。
2. **歌手页独立专辑视图**：
   - 在歌手主页添加了「查看全部专辑」入口，支持通过独立网格视图 [`ArtistAlbumsView.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Features/Detail/ArtistAlbumsView.swift) 分页浏览全部专辑。
3. **macOS 系统顶栏 Mini 播放器**：
   - [`MenuBarView.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Features/MenuBar/MenuBarView.swift) 提供常驻状态栏控制面板（封面、切歌、进度拖拽、音量、桌面歌词开关）。
4. **全屏沉浸歌词播放页 (`NowPlayingView`)**：
   - 左上角收起按钮已修复：添加 `.ignoresSafeArea()`，与窗口顶部左上角自然对齐（顶边距 16pt，左边距 20pt）。
   - 当前正在演唱的高亮歌词文本清晰度已修复：移除了导致 CoreAnimation 位图二次插值模糊的 `.scaleEffect(1.02)`，完全采用纯矢量字号（26pt）和字重渲染，100% 锐利。
5. **全新 Apple Music 亮红质感 App 图标**：
   - 采用 Apple Music 标志性的透亮珊瑚红（`#FA243C` ~ `#FF2D55`）底色 + 3D 立体陶瓷浮雕音符 + 半色调网点。
   - 彻底修复了 Xcode `actool` 生成白色底板外框的问题，通过标准 [`AppIcon.icns`](file:///Users/mac/Projects/VibeaseMusic/AppIcon.icns) 原生驱动，零白边。
6. **播放失败处理与队列恢复 (P0/P1，09-22 前完成，已验证构建通过)**：
   - `PlayerService` 监听 `AVPlayerItem.status` 与 `failedToPlayToEndTime`，坏音源自动提示并跳过（连续失败 <5 首），失败时清理观察者并移除当前 item；`readyToPlay` 后回填真实时长。
   - 歌词 `nil` = 加载中、空值 = 终态无歌词，`Panels` 与 `NowPlayingView` 均有“暂无歌词”分支，不再永久转圈。
   - `playNextList` 持久化；恢复播放时系统控制中心显示暂停态（`NowPlayingManager.updateMetadata(..., isPlaying:)`）。
   - 账号会话隔离：`AccountStore.sessionVersion` + 切号/登出清空曲库 + 异步回包版本校验；`HomeViewModel` 按账号上下文加载（`loadedContext` + `loadGeneration`），切号不再串数据。
   - Space 长按防重复：`keyDown/keyUp` + `spaceIsDown` 锁存，不依赖 `isARepeat`。
   - 搜索失败可重试（`loadedTabs` 仅成功后标记，综合搜索部分失败容忍，空结果计入专辑/歌单）。
   - 精选分类切换竞态：`loadGeneration` + 分类快照，旧响应直接丢弃。
   - 卡片播放按钮与导航冲突：新增 `NavigationCoverCard`（播放按钮置于 `NavigationLink` 之外），`CoverCardBody` 移除 `onPlay`。
7. **Shelf 翻页按钮 + 滚动条策略 (P1，09-22 前完成)**：
   - 自定义细滚动条已彻底删除（含绘制/拖拽/轨道跳转代码）；纵向滚轮转横向逻辑已移除，纵向滚轮走 AppKit 原生接力传递给外层页面。
   - `Shelf` 左右两侧为 hover 淡入的 liquid glass 圆形翻页按钮（`←`/`→` 字符），点击翻一页（约 85% 视宽、缓动）；底层为 `ShelfNSScrollView` + `pageRequest`/`Coordinator` 驱动。
8. **全应用滚动条 hover 显示 (09-22 前完成)**：
   - 新增 `Theme.swift` 通用 `.hoverScrollIndicators()` 修饰器：默认隐藏、鼠标悬停显示。
   - 已应用于全部主页面纵向 `ScrollView`（首页/精选/排行/搜索/收藏/每日推荐/最近播放/云盘/歌单/专辑/歌手/全部专辑/收藏弹窗）与侧栏 `List`；歌词与队列面板保持无指示器。

---

## 4. 待修复的问题与深度技术剖析 (Unfixed Issues & Root Causes)

### 🔴 问题一：点击左上角侧边栏按钮展开侧边栏（Sidebar Reveal）依然存在卡顿（现状：接受原生行为）

#### 1. 现状（09-22 更新）
* 曾尝试两轮自定义侧栏（SwiftUI `ZStack` 悬浮层 → AppKit `SidebarHost` + `NSVisualEffectView` 毛玻璃），均出现侧栏与首页重叠/遮挡回归，用户要求回滚。
* **当前已完全回滚为原生 `NavigationSplitView`**（`MainWindow.swift:16-22`，`columnVisibility` + `navigationSplitViewColumnWidth`），无任何 `SidebarHost`/`isSidebarVisible` 残留（已 grep 核对）。
* 代价：展开动画的 Detail 逐帧重排卡顿依然存在，暂列为已知问题、按原生行为接受，不再投入自定义侧栏方案。

#### 1. 现象描述
* 点击窗口左上角红绿灯右侧的原生侧边栏展开/折叠按钮（`NavigationSplitView` 控制器）时，当侧边栏从隐藏（宽度 0）向右滑出展开（宽度 220）的过程中，有非常明显的掉帧和卡顿感。

#### 2. 底层根因分析
* **SwiftUI `NavigationSplitView` 与 Detail 列重排的级联冲突**：
  在 macOS 上，`NavigationSplitView` 在侧边栏展开动画（0.25~0.35 秒）期间，会以 60/120fps 不断改变右侧 Detail 区域的有效宽度（例如从 1000px 压缩至 780px）。
* **`HomeView` 内部嵌套视图过度重绘**：
  `HomeView` 包含多个 `Shelf`（水平 `ScrollView`）以及数十个 `CoverCard`。当 Detail 宽度随每一帧改变时，SwiftUI 会递归触发所有卡片的文字折行计算、网格宽度重新测算。
* **`SidebarView` 中 `List` (AppKit `NSTableView`) 的初始化开销**：
  侧边栏展开时，`List` 内部的多级 Section 和歌单列表在瞬间被激活并参与 AppKit 尺寸插值。

#### 3. 推荐给 Codex 的实现方案
1. **方案 A（隔离 Detail 动画重排 - 优先推荐）**：
   在 [`MainWindow.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Features/MainWindow.swift) 中，避免在侧边栏伸缩时让 `detailStack` 进行实时的每一帧重新计算。可为 `detailStack` 设置一个固定的最小安全布局容器宽度，或者使用 `.drawingGroup()` / `.transaction { $0.animation = nil }` 抑制内部水平卡片架在父容器宽度改变时的逐帧重算。
2. **方案 B（自定义轻量级平滑侧边栏）**：
   如果 `NavigationSplitView` 的 AppKit 原生层动画性能无法达到 120fps 满帧，可以将主界面重构为：
   ```swift
   HStack(spacing: 0) {
       if isSidebarVisible {
           SidebarView(...)
               .frame(width: Theme.Layout.sidebarWidth)
               .transition(.move(edge: .leading))
       }
       detailStack
   }
   .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSidebarVisible)
   ```
   这种纯 SwiftUI 结构完全绕过了 AppKit `NSSplitViewController` 复杂的重排逻辑，动画极其轻量丝滑。

---

### ✅ 问题二：横向卡片架（`Shelf`）交互（已按新方案解决，原滚动条需求作废）

#### 1. 最终方案（09-22 更新，用户确认）
* 自定义悬浮细滚动条：已删除，不再实现。
* 纵向滚轮转横向：已移除（`ShelfNSScrollView.scrollWheel` 覆盖已删，无残留）；纵向滚轮恢复 AppKit 原生接力，外层页面滚动正常。
* 横向浏览唯一方式：`Shelf` 左右两侧 hover 显示的 liquid glass 翻页按钮（`Cards.swift`：`pagerButton`/`pageRequest`/`scrollByPage`）。
* 验收标准第 1–4 条（滚动条相关）作废；第 5 条（页面纵向滚动原生流畅）已满足。

#### 1. 现象与历史回滚原因
* 此前尝试实现自定义悬浮细滚动条和横向滚轮支持，但存在两个严重 UX 缺陷被用户要求回滚：
  1. 自定义滚动条悬停检测失效（只显示一次后彻底消失，无法鼠标直接按住 Thumb 拖拽）。
  2. 鼠标垂直滚轮横向滚动卡片架到达最左/最右尽头时，**会自动穿透切换成整个页面的垂直滚动**，违背了用户的操作直觉。
* **目前状态**：[`Cards.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/DesignSystem/Cards.swift) 已安全回滚为原生的 `ScrollView(.horizontal, showsIndicators: false)`。

#### 2. 完整验收标准 (Acceptance Criteria)
1. **默认隐藏与悬停展示**：横向滚动条默认不可见，仅当鼠标光标进入该 `Shelf` 区域时平滑淡入（高度仅 3~4pt，不遮挡卡片），移出时平滑淡出；且必须 100% 长期可靠，绝不能出现只触发一次就永久失效的问题。
2. **滑块拖拽与轨道寻道**：支持鼠标左键直接按住滚动条滑块（Thumb）左右拖动，支持点击轨道任意位置直接跳转。
3. **普通滚轮横向滚动**：鼠标悬停在 `Shelf` 上时，普通的垂直物理鼠标滚轮能够直接驱动卡片水平平移。
4. **尽头受阻阻尼（核心关键）**：
   - 当水平卡片架滚动到最左端或最右端尽头时，**滚轮事件必须被严格拦截/受阻停止**！
   - **绝对不允许穿透并触发外层主页面的垂直上下滚动！**
5. **非 Shelf 区域体验**：鼠标在非 Shelf 区域滚动时，主页面保持 100% 原生流畅的纵向滚动。

#### 3. 推荐给 Codex 的实现方案
* 纯 SwiftUI 的 `simultaneousGesture` 无法有效拦截系统级的滚轮事件穿透。
* **最佳方案**：使用 AppKit `NSScrollView` 包装为 `NSViewRepresentable`：
  - 在自定义的 `ShelfNSScrollView: NSScrollView` 中重写 `scrollWheel(with event: NSEvent)`。
  - 检测水平滚动偏移量：如果 `event.scrollingDeltaY != 0`，将其转化为水平偏移；
  - **关键**：当已处于最左端且继续向左滚，或处于最右端且继续向右滚时，**直接 `return`，不调用 `super.scrollWheel(with: event)`，彻底切断事件向外层 Responder Chain 的传递**。

---

## 5. 未实现的新功能待办清单 (Unimplemented Feature Backlog)

### 📋 功能 1：双击侧边栏「推荐」项立即返回顶部
* **详细需求**：
  - 用户在浏览过程中，如果双击左侧边栏的「推荐 (Home)」按钮：
    1. 如果当前处于二级/三级详情页（如歌单、专辑、歌手），立即清空 NavigationStack 路径（Pop to Root）。
    2. 如果当前已经在「推荐」首页，立即平滑滚动回顶部第一屏（`ScrollViewReader.scrollTo(top)`）。
* **涉及文件**：[`SidebarView.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Features/SidebarView.swift)、[`MainWindow.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Features/MainWindow.swift)、[`HomeView.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Features/Home/HomeView.swift)。

---

### 📋 功能 2：音效均衡器 (Equalizer & Audio DSP)
* **详细需求**：
  - 在播放控制中增加 10 段图形均衡器面板（32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz）。
  - 内置经典 EQ 预设（流行、摇滚、人声、电音、低音增强、古典等）与自定义调节。
  - 基于 AVFoundation `AVAudioUnitEQ` 节点接入音频渲染链。
* **涉及文件**：[`PlayerService.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Core/Player/PlayerService.swift)、新增 `EqualizerView.swift`。

---

### 📋 功能 3：全局快捷键与键盘媒体键支持 (Global Hotkeys)
* **详细需求**：
  - 支持在应用处于后台或最小化时，通过键盘顶部多媒体按键（Play/Pause, Prev, Next）及自定义全局组合热键控制音乐播放。
  - 可基于 `NSEvent.addGlobalMonitorForEvents` 或 `Carbon` 注册全局热键。
* **涉及文件**：[`VibeaseMusicApp.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/VibeaseMusicApp.swift)、[`WindowManager.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Core/WindowManager.swift)。

---

### 📋 功能 4：本地音乐扫描与离线缓存下载
* **详细需求**：
  - 支持用户选取本地音乐文件夹，自动解析 ID3 标签（元数据、内嵌封面）并建立本地音乐库。
  - 支持对在线歌曲一键缓存至本地，断网状态下无缝离线播放。
* **涉及文件**：[`NeteaseAPI.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Core/Network/NeteaseAPI.swift)、新增 `LocalLibraryService.swift`。

---

### 📋 功能 5：桌面歌词高级交互设置
* **详细需求**：
  - 桌面歌词窗口支持鼠标穿透（Mouse Event Pass-through，防止误触）。
  - 支持单行/双行歌词切换、自定义字体、描边宽度及渐变主题色配置。
* **涉及文件**：[`DesktopLyrics.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Features/Player/DesktopLyrics.swift)、[`SettingsView.swift`](file:///Users/mac/Projects/VibeaseMusic/Sources/VibeaseMusic/Features/Settings/SettingsView.swift)。

---

## 6. 调试与诊断命令备忘 (Cheatsheet)

```bash
# 查看当前正在运行的应用进程
pgrep -x VibeaseMusic

# 强杀并重启应用
pkill -x VibeaseMusic && open /Applications/VibeaseMusic.app

# 修复后的标准交付流程（每次改完都执行：打包 → 替换 → 启动 → 确认进程）
./Scripts/build-app.sh debug
pkill -x VibeaseMusic 2>/dev/null || true
rm -rf /Applications/VibeaseMusic.app
cp -R .build/app/VibeaseMusic.app /Applications/VibeaseMusic.app
open /Applications/VibeaseMusic.app
sleep 2; pgrep -x VibeaseMusic

# 查看应用控制台实时日志 (OSLog / NSLog)
log stream --predicate 'process == "VibeaseMusic"' --level debug

# 检查当前 App Bundle 的图标与 Info.plist
defaults read /Applications/VibeaseMusic.app/Contents/Info.plist

# 验证 SPM 编译状态
swift build -c debug
```

---
*本交接文档已同步固化至项目根目录 `handover.md`（09-22 刷新版），可随时提供给 Codex 或其他接手工具直接索引。*

---

## 7. 已知遗留风险（09-22 审查确认，未改动）
- 无测试目标：`swift test` 报告 no tests。
- 发布链路产品名不一致：CI 用 `Kumone`，打包脚本产物为 `VibeaseMusic.app`；Sparkle updater 配置不完整（`startingUpdater: false`，Feed/公钥未写入 Info.plist）；构建产物仅 arm64。
- Cookie 明文存 `Application Support`、注销仅删两个字段；第三方解锁音源走 HTTP 且匹配失败可能播错歌曲（个人自用阶段已接受，暂不修）。
