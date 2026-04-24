⚡️ TrollSpeed
一个专为 TrollStore 打造的、极具现代感的 iOS 全局网速悬浮窗工具。

✨ 全新版本亮点
此版本对原始项目进行了彻底的视觉与底层重构，旨在提供媲美 iOS 原生系统的交互体验：

控制中心美学： 抛弃了传统的滚动列表，采用全新的磁贴网格 (Tile Grid) 布局。所有功能一屏呈现，无需滑动，视觉上与 iOS 18 控制中心高度统一。

极致交互反馈： 深度集成 Taptic Engine。每一个开关动作都伴随着物理层面的微缩放动画与精准的力量感触觉反馈。

解除系统手势拦截： 针对底层悬浮窗拦截“下拉控制中心/通知中心”的顽疾进行了专项修复，确保屏幕边缘滑动依然丝滑顺畅。

原生级汉化： UI 组件深度集成中文本地化，告别生硬的翻译。

全自动发版： 完美集成 GitHub Actions 构建流水线，每次推送代码后都会自动生成带版本号的 .tipa 安装包并发布至 Releases 页面。

🚀 核心功能
您可以通过简洁的磁贴面板实时控制：

精准定位： 支持锁定至左上角、右上角或顶部居中（完美适配灵动岛与刘海屏）。

触摸穿透： 开启后悬浮窗将完全忽略触摸，不影响点击其下方的任何 App 界面。

外观定制： 支持单行模式、大字体显示、颜色反转以及上下行流量箭头指示。

智能行为： 支持截图时自动隐藏悬浮窗、忽略屏幕旋转固定位置显示等高级特性。

🛠 工作原理
TrollSpeed 结合了 TrollStore + UIDaemon + NetworkSpeed13 的技术优势：

利用 TrollStore 权限产生具有 Root 权限 的 HUD 进程，防止被系统掉签或清理。

通过分离进程逻辑（不调用 waitpid），确保悬浮窗独立持久运行。

利用 assistivetouchd 的权限（Entitlements）实现窗口的全局置顶显示。

注意： 必须使用 Root 权限运行，否则进程会在设备解锁时被 SpringBoard 强制杀死。

📦 构建与安装
推荐方法
直接前往本项目的 Releases 页面，下载由 GitHub Actions 自动构建的最新版本 .tipa 文件，并使用 TrollStore 安装。

手动编译
如果您希望自行修改代码并编译，请使用 theos 工具链：

# 构建完整安装包
FINALPACKAGE=1 make package

编译生成的 .tipa 文件将存放在 ./packages 目录下。

🙏 特别鸣谢

* [TrollStore](https://github.com/opa334/TrollStore) - [@opa334dev](https://github.com/opa334)
* [UIDaemon](https://github.com/limneos/UIDaemon) - [@limneos](https://github.com/limneos)
* [NetworkSpeed13](https://github.com/johnzarodev/NetworkSpeed13) - [@johnzarodev](https://github.com/johnzarodev)
* **Original Logic** - [@Lessica](https://github.com/Lessica) & [@jmpews](https://github.com/jmpews)
* **Design & Refactor** - 重构版交互设计基于现代 iOS 视觉规范

📄 开源协议
本项目采用 MIT License 开源协议。