# 自己动手改：开发环境与热重载

## 一次性设置（Android Studio）

1. **安装 Flutter 插件**：Android Studio → File → Settings → Plugins → Marketplace，搜索 `Flutter`，安装（会自动连带安装 Dart 插件），重启。
2. **指定 Flutter SDK**：Settings → Languages & Frameworks → Flutter → Flutter SDK path 填 `D:\dev\flutter`。
   - 这个 SDK 被 PiliPlus 的补丁改过，是本项目专用的。
   - **不要**点 IDE 里的 "Upgrade Flutter"，也不要运行 `flutter upgrade` / `flutter pub upgrade`，否则补丁和依赖版本会被冲掉。
3. **打开项目**：File → Open → 选 `D:\dev\PiliPlus`。
4. 用户环境变量 `PUB_CACHE=D:\dev\pub-cache` 已经设好。如果 Android Studio 是在设置环境变量之前就打开的，**完全退出后重新打开**一次，它才读得到。

## 每次开发

1. 手机用数据线连电脑，顶部工具栏的设备下拉框里选 **V2408A**（iQOO 13）。
2. 入口选 `main.dart`，点绿色的 **Run ▶**（或 **Debug 🐞**）。第一次编译要几分钟。
   - 调试版的包名是 `com.example.piliplus.debug`，和官方版、dev 版共存。
3. 改代码 → **Ctrl+S 保存** → 1～2 秒后手机上的界面就变了，这叫**热重载（Hot Reload）**。

### 热重载不生效时

| 改了什么 | 怎么让它生效 |
|---|---|
| `build()` 方法里的界面代码、颜色、尺寸、文字 | Ctrl+S 热重载就行 |
| 控制器的 `onInit`、`initState`、全局变量、主题（`revamp_theme.dart`） | 工具栏的 **Hot Restart**（绿色圆圈箭头），App 重启但不重新编译，几秒钟 |
| 着色器 `.frag`、图片资源、`pubspec.yaml`、Android 原生代码 | 停止后重新 Run |

### 找到"手机上这块界面是哪段代码"

工具栏 → **Flutter Inspector** 面板 → 点 **Select Widget Mode**（准星图标）→ 在**手机上**点任意一块界面 → 编辑器会**直接跳到**写这块界面的代码行。这是读懂陌生代码最快的方法。

### 关于流畅度

调试模式（Debug）为了支持热重载，跑的是解释执行，**动画会明显卡**，这是正常的。判断流畅度要用 **Profile** 模式运行（Run 下拉菜单里选，或命令行 `flutter run --profile`），或者让我编 release 版。

## 用 Git 保护自己

改之前先提交一次，改坏了随时可以回去：

- Android Studio 左侧 **Commit** 面板（Alt+0）：能看到改了哪些文件、每处改动的对比。
- 改坏了：右键文件 → Git → **Rollback**，回到上次提交的样子。
- 满意了：在 Commit 面板写一句说明，点 Commit。

## 改版代码地图

| 想改什么 | 去哪里 |
|---|---|
| 全局组件风格（Tab、菜单、弹窗、按钮） | `lib/common/revamp_theme.dart` |
| 新界面的总开关、分组卡片、图标方块、大标题 | `lib/common/revamp.dart` |
| 弹簧参数（Q 弹程度） | `lib/common/motion/springs.dart` |
| 按压回弹、页面转场、封面飞入、卡片入场 | `lib/common/motion/` 下各文件 |
| 液态玻璃底栏、搜索按钮 | `lib/common/widgets/liquid_glass/liquid_glass_navigation_bar.dart` |
| 液态玻璃折射着色器 | `shaders/liquid_glass_lens.frag` |
| 视频卡片 | `lib/common/widgets/video_card/video_card_v.dart`（竖版）、`video_card_h.dart`（横版） |
| 首页、搜索、我的、设置、播放页 | `lib/pages/<页面>/view.dart` |
| 改版进度和待办 | `docs/revamp.md` |

所有改版代码都包在 `if (Revamp.enabled)` 或 `Revamp.enabled ? 新 : 旧` 里，旧代码原样保留，对照着读能看出改了什么。

## 编译安装 release 版（看真实流畅度）

```bash
powershell -File tool/patch_local.ps1 android   # 只在 Flutter 或依赖更新后需要
flutter build apk --release --target-platform android-arm64 --android-project-arg dev=1 --no-pub
```
