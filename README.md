<div align="center">
    <img width="160" height="160" src="assets/images/logo/logo.png">
</div>

<div align="center">
    <h1>PiliGlass</h1>
    <p>液态玻璃风格的第三方 B 站客户端，基于 <a href="https://github.com/bggRGjQaUbCoE/PiliPlus">PiliPlus</a> 的界面改版</p>

![GitHub release](https://img.shields.io/github/v/release/Xstars3279/PiliGlass?include_prereleases&label=release)
![GitHub downloads](https://img.shields.io/github/downloads/Xstars3279/PiliGlass/total)
![License](https://img.shields.io/github/license/Xstars3279/PiliGlass)

</div>

<br/>

## 这是什么

PiliGlass 是 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的一个分支。PiliPlus 的功能、接口和播放能力都原样保留，PiliGlass 只在这之上重新做了界面和交互：

- 💧 **液态玻璃**：悬浮的玻璃底栏、平板/横屏的玻璃侧栏、玻璃评论面板，边缘会折射背后的内容
- 🌊 **弹簧动效**：按压回弹、页面视差转场、面板吸附、卡片依次浮现，动画都由弹簧驱动
- 🎨 **统一的设计语言**：大标题、圆角分组列表、胶囊标签栏，全应用一致
- 🎬 **播放页**：封面取色的氛围背景、可拖拽的玻璃评论面板、全屏底部弹幕栏
- ⬇️ **应用内更新**：多连接下载、内置安全 DNS、后台下载、SHA-256 校验
- ⚙️ **可开关**：每项新特性都在「设置 › PiliGlass 特性」里有独立开关，关掉即回到 PiliPlus 原版的样子

功能上的问题（播放、登录、接口等）大多来自上游，修复也会定期从 PiliPlus 同步过来。

<br/>

## 下载

从 [Releases](https://github.com/Xstars3279/PiliGlass/releases) 下载。目前只提供 **Android arm64** 安装包，仍是预览版。

PiliGlass 的包名与 PiliPlus 不同，两者可以同时安装，互不影响。

<br/>

## 反馈

欢迎在 [Issues](https://github.com/Xstars3279/PiliGlass/issues) 反馈问题和建议。提交前可以先确认一下：

- 界面、动效、玻璃效果相关的问题 → 这里
- 在 PiliPlus 原版上也能复现的问题 → 更适合反馈给 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus/issues)

<br/>

## 声明

此项目是个人为了兴趣而开发，仅用于学习和测试，请于下载后 24 小时内删除。
所用 API 皆从官方网站收集，不提供任何破解内容。

<br/>

## 致谢

PiliGlass 站在这些项目的肩膀上，没有它们就没有这个应用：

- [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)：PiliGlass 的上游，几乎所有功能都来自这里
- [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)：PiliPlus 的上游
- [guozhigq/pilipala](https://github.com/guozhigq/pilipala)：最初的原作
- [SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)：液态玻璃底栏和折射效果移植自这里
- [Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)：液态玻璃折射算法的原作
- [compose-miuix-ui/miuix](https://github.com/compose-miuix-ui/miuix)：液态玻璃底栏的原型
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [media-kit](https://github.com/media-kit/media-kit)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [dio](https://pub.dev/packages/dio)
- 以及更多开源库

感谢各位作者的开源精神。

<br/>

## 许可证

与上游相同，以 [GPL-3.0](LICENSE) 协议开源。

PiliGlass 是 PiliPlus 的修改版本，自 2026 年起由 Xstars3279 修改，主要改动在界面和交互，每一处改动都记录在 git 历史中。仓库中包含的第三方代码（液态玻璃、Flutter 框架、Anime4K 等）及其协议见 [NOTICE](NOTICE)，协议原文在 [LICENSES](LICENSES) 目录；应用内可在「关于 › 开源许可」查看所有依赖的协议。
