# PiliGlass 改版代码审计（第二轮）

审计对象：`ui-revamp` 分支 HEAD（`64a3d6df1`）相对 `git merge-base HEAD upstream/main` 的 `lib/` 改动，128 个文件（+8777 / −1227）。
方法：只读代码，不跑 App。每条都追到了调用链的末端（主题字段、`tool/patches/` 里的三个补丁、上游控制器和 Flutter 框架的相关行为）。
不在范围内：平板左侧玻璃侧栏 `liquid_glass_navigation_rail.dart`，以及工作区里 `main/view.dart`、`home/view.dart` 尚未提交的侧栏接入改动（另一个会话在改）。

严重度：🔴 功能错误　🟠 体验问题或明显不一致　🟡 小问题或清理项

---

## 〇、第一轮条目的状态

| 第一轮 | 状态 | 说明 |
|---|---|---|
| 1 横屏没有发布入口 | 修复中 | HEAD 里 `dynamics/view.dart:228-234` 仍然在 `Revamp.enabled` 时去掉 `+`。新侧栏（工作区未提交）带了「发布动态」按钮，提交后就能补上，以侧栏会话的结果为准。 |
| 2 卡片不受总开关控制 | 不处理 | 用户已定：不需要退回上游原版。 |
| 3 150ms 点击延迟 | 延迟保留 | 延迟本身是有意设计。其中的「双击推两页」已在这一轮确认，见下面第 1 条。 |
| 4 纯黑主题 | 不处理 | 第一轮已更正，真机确认正常。 |
| 5 五个页面的标签样式 | 已修 | `64a3d6df1` |
| 6 设置子页风格 | 已修 | `64a3d6df1`。字体、全屏 SC、日志、设置搜索保留小标题栏，是有意的。 |
| 7 令牌复用 | 仍未处理 | 这一轮又找到两处，见第 10 条。 |
| 8 固定曲线代替弹簧 | 仍未处理 | 清单不变，这里不重复。 |
| A 退出时视频响一下 | 仍未处理，仍需真机 | `comment_sheet.dart:218` 在 `dispose` 里调用 `onCoverPlayer(false)`，进而执行 `video/revamp_view.dart:29-31` 的 `player.play()`。子组件先于页面 `dispose`，所以这次 `play()` 一定会发生在 `plPlayerController.dispose()` 之前（`video/view.dart:350-380`）。会不会听到声音，要看播放器停下来有多快。 |
| B 切后台再回来视频自己播放 | **否定** | `pl_player/view/view.dart:337-353` 只会恢复它自己暂停的播放（`_pauseDueToPauseUponEnteringBackgroundMode`）。面板盖住视频时视频已经被面板暂停，切后台时这个标志不会被设上，回到前台也不会自动播放。 |
| C 转屏后评论面板状态丢失 | 仍未处理，仍需真机 | `comment_sheet.dart:194` 在 `initState` 里仍然执行 `_isOpen.value = false`。 |
| D 横屏评论区实时模糊 | 仍未处理，仍需真机 | `video/reply/view.dart` 的 `_revampHeader` 仍然用 `BackdropFilter(sigma 20)`。 |
| E 两次截图乱序 | 仍未处理 | `comment_sheet.dart:237-239`、`:246-287` 没有改。 |
| F 双击打开两个播放页 | **已确认** | 见下面第 1 条。 |
| G 高分屏截图耗时 | 仍需真机 | 没有改。 |

---

## 一、确定问题（读代码已经能确认）

### 🔴 1. 快速连点视频卡片会打开两个播放页
- **位置**：`lib/common/motion/pressable_scale.dart:33-34`（`delayTap`）；用到它的地方在 `video_card_v.dart:106`、`video_card_h.dart:61`。
- **问题**：`delayTap` 返回 `() => Future.delayed(150ms, onTap)`，没有防重入。150ms 内点两下，会排进两个 `onTap`，各自执行一次 `PageUtils.toVideoPage`。
- **依据**：上游是在手指抬起时直接 push。push 后 `NavigatorState._afterNavigation` 会调用 `_cancelActivePointers()`，同一帧里的第二次点击被吸收；下一帧新页面已经盖在最上层，点击落到新页面上。改版把 push 推迟了 150ms，这段时间里旧页面照常接收点击。而 `toVideoPage` 用的是 `toDupNamed('/videoV')`（`page_utils.dart:568`），允许重复路由，GetX 的 `preventDuplicates` 也挡不住。
- **修法**：保留 150ms 延迟，只加防重入。最简单的做法是在 `delayTap` 里加一个静态标志：

  ```dart
  static bool _pending = false;
  static VoidCallback delayTap(FutureOr<void> Function() onTap) => () {
    if (_pending) return;
    _pending = true;
    Future.delayed(tapDelay, () async {
      try { await onTap(); } finally { _pending = false; }
    });
  };
  ```

### 🟠 2. 打开已经点过赞、投过币或收藏过的视频，图标会自己“爆一下”
- **位置**：`lib/pages/video/introduction/ugc/widgets/action_item.dart:156-170`（`_PopIcon.didUpdateWidget`）
- **问题**：只要 `selected` 从 false 变成 true，就播放弹跳和八颗粒子的动画；变回 false 时播放下沉动画。
- **依据**：`hasLike`、`hasCoin`、`hasFav` 等状态是在进入页面后异步查询回来的，初始都是 false。查询结果一到，`selectStatus` 就从 false 变成 true，触发同样的动画。切换分 P 或相关视频时状态重置成 false，又会播一次下沉动画。用户什么都没点，图标却在动。
- **修法**：只有用户自己点击时才播放动画。`ActionItem` 可以在 `onTap` 里设一个“本次是用户点击”的标志，`_PopIcon` 只在这个标志为真时播放；也可以要求状态变化发生在最近一次点击后的大约 3 秒内才播放。

### 🟠 3. 离线视频全屏时，弹幕开关和弹幕设置都没有了
- **位置**：`lib/pages/video/widgets/header_control.dart:1872`、`:1926`；`lib/plugin/pl_player/view/view.dart:897-900`
- **问题**：改版在全屏时把顶栏的「发弹幕 / 弹幕开关 / 弹幕设置」隐藏了（条件是 `!(Revamp.enabled && isFullScreen)`），改由底部的 `RevampDanmakuBar` 提供。但底栏只在 `isNotFileSource && !isLive` 时出现。
- **依据**：顶栏这一组按钮不在 `if (!isFileSource)` 里面（`header_control.dart:1804` 的 `if (!isFileSource) ...[` 在 `:1852` 之前已经结束），说明上游离线视频全屏时这些按钮是有的。改版后离线视频全屏既没有顶栏按钮也没有底栏，下载时带下来的弹幕在全屏下无法开关，也无法调整。
- **修法**：顶栏的隐藏条件改成 `!(Revamp.enabled && isFullScreen && !videoDetailCtr.isFileSource)`；或者让 `RevampDanmakuBar` 在离线视频时也显示，但去掉发送框，只留开关和设置。

### 🟠 4. 设置页账号卡片的昵称不会跟着切换账号或退出登录更新
- **位置**：`lib/pages/setting/view.dart:231-262`（`_revampAccount`）
- **问题**：头像用 `Obx` 绑定了 `AccountService.face`，会更新；昵称却是在 build 时读一次 `Pref.userInfoCache`。
- **依据**：在卡片里点「切换账号」（`LoginPageController.switchAccountDialog`）、或者点「退出登录」（`_removeAccounts` 只改 `_noAccount`）之后，都不会触发整个设置页重新 build。结果是头像已经换成新账号（或者变成占位图），名字还是旧账号的。上游的设置页没有这张卡片，所以这是新代码引入的问题。
- **修法**：昵称也改成响应式的，比如在 `Obx` 里读 `AccountService` 的 `isLogin`、`face`，再取 `Pref.userInfoCache`；或者在 `switchAccountDialog` 和 `_removeAccounts` 结束后 `setState`。

### 🟠 5. 黑白封面的视频，氛围色会变成谷歌蓝
- **位置**：`lib/common/widgets/cover_palette.dart:224`
- **问题**：`Score.score(result.colorToCount, desired: 1).first`
- **依据**：`material_color_utilities` 里的 `Score.score` 默认 `filter: true`，会去掉色度低于 5 的颜色；一个都不剩时返回 `fallbackColorARGB`，默认值是 `0xff4285F4`（谷歌蓝）。黑白、灰度或者近乎单色的封面（纯色字幕封面、黑白老片），视频页顶部的氛围渐变、状态栏、标题栏和评论面板的玻璃都会染成蓝色，和封面毫无关系。
- **修法**：传 `fallbackColorARGB` 一个哨兵值；拿到哨兵值时返回 null，`AmbientTintBuilder` 就会回到 `colorScheme.surface`。也可以在 `ambient()` 里把色度很低的 seed 当成中性色处理。

### 🟡 6. 首页只剩一个标签时，信息流顶上有一条空白
- **位置**：`lib/pages/home/view.dart:49`、`:82`、`:84`、`:109-110`（HEAD）
- **问题**：标签数 ≤ 1 时 `tabBar` 是 `SizedBox(height: 6)`，但 `_floatingTabs` 仍然给信息流加了 `RevampTopInset(inset: GlassTabBar.extent)`，也就是 58dp。
- **依据**：只保留「推荐」一个首页标签的用户，信息流顶上会有 58dp 的空白，上面什么都没有。下拉刷新的指示器也会多往下偏 58dp（`refresh_indicator.dart:528`）。
- **修法**：`inset: _homeController.tabs.length > 1 ? _floatingTabsHeight : 6`。

### 🟡 7. 屏幕较窄或界面缩放较大时，底栏左边会超出屏幕
- **位置**：`lib/common/widgets/liquid_glass/liquid_glass_navigation_bar.dart:678-680`
- **问题**：`groupX = (w - (_width + _kDockGap + circle)) / 2`，没有下限。三个标签时整组宽 254 + 10 + 64 = 328dp。
- **依据**：`main.dart` 会把 `Pref.uiScale` 设给 `ScaledWidgetsFlutterBinding`，界面放大后逻辑宽度会变小（360dp 的屏放大到 1.15 倍后只剩约 313dp）。小屏手机和分屏也是同样情况。`w < 328` 时 `groupX` 变成负数，底栏左端被推到屏幕外，而且没有任何缩放或裁切。
- **修法**：`_kTabWidth` 按可用宽度收缩，比如 `min(82, (w - 2*edge - gap - circle - 8) / count)`；或者 `groupX` 至少取 `_kDockEdge`，同时缩小标签宽度。

### 🟡 8. 关掉的弹幕开关逻辑复制了三份
- **位置**：`lib/pages/video/revamp_view.dart:80-84`、`lib/plugin/pl_player/widgets/revamp_danmaku_bar.dart:76-80`、`lib/pages/video/view.dart:1475` 附近（还有上游的 `header_control.dart:1900-1908`）
- **问题**：这几处都是 `enableShowDanmaku.value = !on` 加上 `if (!tempPlayerConf) setting.put(...)`，内容一样。
- **依据**：以后上游改这段逻辑（比如加埋点，或者调整临时配置的判断），改版里的两份副本很容易漏改。
- **修法**：在 `PlPlayerController` 外面加一个扩展方法 `toggleDanmaku()`，放在改版自己的文件里（不改上游控制器），三处都调用它。

### 🟡 9. `CoverPalette` 的缓存会把失败结果也永久缓存下来
- **位置**：`lib/common/widgets/cover_palette.dart:196`、`:204`
- **问题**：`_cache[url] ??= _extract(...)`，而 `_extract` 出错时返回 null，所以“失败”也被缓存了；缓存也没有大小上限。
- **依据**：网络抖一下导致缩略图加载失败，这个视频在这次 App 运行期间就再也取不到氛围色。连续刷很多视频，Map 会一直增长（每条只是一个 Future 和一个 int，量不大，但不会释放）。
- **修法**：结果为 null 时 `_cache.remove(url)`；缓存改成 LRU，上限大约 200 条。

### 🟡 10. 新代码里又出现了没用共享令牌的分组样式（第一轮第 7 条的延续）
- `lib/pages/search/revamp_view.dart:23-32`：手写的 `DecoratedSliver(surfaceContainerLow, circular(24))`，和 `RevampGroup` 重复。应该用 `Revamp.groupRadius`，或者抽一个 `RevampSliverGroup`，和 `common_setting.dart` 共用。
- `lib/pages/whisper/view.dart:302-325`（`_revampSessions`）：自己实现了首行、末行圆角，和 `revampGroupRow()` 重复；而且左右用的是固定的 `horizontal: 12`，没有加上 `padding.left/right`。同一个页面里的 `_revampTopItems`（`:228`）加了这两个值，横屏有刘海的手机上两块会对不齐。

### 🟡 11. 标签的「凸起胶囊」有两套实现
- **位置**：`lib/common/widgets/liquid_glass/glass_tab_bar.dart:52-64` 与 `lib/common/revamp_theme.dart:96-149`（`PillTabIndicator`）
- **问题**：首页和动态页的玻璃标签用 `ShapeDecoration`：贴满标签高度，带 `0x14FFFFFF` 描边，阴影是 `shadow@0.08 blur10`。其他页面走主题的 `PillTabIndicator`：上下各内缩 6、左右各内缩 2，没有描边，阴影是 `black@0.12/0.4 blur4`。
- **依据**：从首页进入「收藏」「投稿」等页面，选中胶囊的高度、阴影和描边都不一样。
- **修法**：`GlassTabBar` 改用 `PillTabIndicator`，必要时给它加 `insets` 和 `side` 参数，让两处共用一个实现。

### 🟡 12. 开关也有两套外观
- **位置**：`lib/common/widgets/revamp_switch.dart`（46×28，按住会拉长，弹簧动画）与 `revamp_theme.dart:51-61`（主题里的 Material `Switch`，52×32，框架自带动画）
- **问题**：设置项（`switch_item.dart`）用 `RevampSwitch`，其他页面散落的 `Switch` 用主题样式。两者颜色一致，但尺寸和手感不同。
- **修法**：如果目标是全局只用一种开关，可以在 `RevampTheme` 之外，把高频页面的 `Switch` 逐步换成 `RevampSwitch`；或者把 `RevampSwitch` 的尺寸对齐成 52×32。这一条和「设计取舍」第 3 条有关，可以一起决定。

### 🟡 13. `PublishRoute._eased` 没有释放
- **位置**：`lib/pages/common/publish/publish_route.dart:86-90`
- **问题**：`late final _eased = CurvedAnimation(parent: animation!)` 在路由里没有被 `dispose`。
- **依据**：`CurvedAnimation` 会在 parent 上注册状态监听。路由销毁后 parent 也会被销毁，所以实际影响很小，但不符合「listener 都要释放」的原则。
- **修法**：重写 `dispose()`，在里面调用 `_eased.dispose()`；要注意 `late` 字段在没用到的时候不要去初始化它。

---

## 二、需真机确认

| # | 怀疑的问题 | 依据 | 复现步骤 |
|---|---|---|---|
| H | 🟠 页面切换时，底栏和玻璃按钮的折射位置错开 | `liquid_glass.dart:201-205` 在 **paint 时** 用 `getTransformTo(null)` 算出镜头在屏幕上的位置，再写进 shader。页面转场的位移（`page_transition.dart:149`）作用在路由的 `RepaintBoundary` 外面，页面内容只是整层平移、不会重绘，所以 shader 里的位置会一直停在转场开始那一帧。`custom_toast` 和 `revamp_fab` 有自己的动画，会跟着重绘，不受影响；静止的底栏、首页标签、搜索页底部的输入框会受影响 | 1. 首页开着底栏，点「我的 → 设置」，看左滑转场时底栏边缘的折射有没有和胶囊错位。2. 在设置页右滑返回，手指停在一半，看露出的首页底栏边缘是否正常。3. 搜索页（底部输入框）右上滑返回，看同样的问题 |
| I | 🟡 推荐卡片在大字体或带角标时文字溢出 | `rcmd/view.dart` 把卡片文字区的 `mainAxisExtent` 从 90 改成了 `scale(76)`。按默认字号估算：8 + 两行标题 37.8 + 4 + 一行 UP 18 + 4 ≈ 72，只剩约 4dp 余量。如果 `PBadge` 比 18 高、全局字体比 14 大，或者自定义字体的行高更大，就会溢出 | 设置 → 外观，把字体调到最大，或者换一款行高较大的自定义字体。在首页推荐里找带「已关注」或推荐理由角标、标题两行的卡片，看底部有没有黄黑溢出条或被裁掉的文字 |
| J | 🟡 在视频页里切换到别的视频后返回，飞回卡片的是原来的封面 | `CoverHero` 的标签来自 `args['coverHero']`，在页面里切换相关视频或分 P 后标签不变；`FirstFrameCover` 一直挂在树上（只是透明度为 0）。返回时 Hero 会从播放器位置飞回原卡片，飞行中显示的是 `card.child`，也就是原卡片的封面 | 从首页点开视频 A → 在简介里点相关视频 B（同一页内切换）→ 返回首页，看飞回卡片的是 A 的封面还是 B 的画面 |
| K | 🟡 视频播放时打开评论，面板升到播放器上方后，玻璃里透出的是旧画面 | `_captureBackdrop` 只在打开时截一次图（600ms 后再截一次），截图包含当时的播放器画面。之后面板被拖到播放器上方才暂停视频，玻璃里透出的是打开那一刻的视频帧，不是暂停时的画面。在 Impeller 上，截图里的视频 Texture 还可能是黑的 | 视频播放中打开评论，等几秒后用把手把面板拖到播放器上方，看玻璃透出的是不是几秒前的画面，或者一片黑 |
| A、C、D、E、G | 见「〇、第一轮条目的状态」 | | 复现方法同第一轮 |

---

## 三、设计取舍待定（不是 bug，需要你定）

1. **改版下 Toast 不再使用「Toast 不透明度」设置。** `custom_toast.dart:17-45` 在 `Revamp.enabled` 时用固定透明度的 `GlassCapsule`，`CustomToast.toastOpacity`（设置 → 外观里可以调）只对上游样式生效。选项：保留现状并在设置里隐藏这一项；或者把这个值映射成玻璃的 tint alpha。
2. **视频页（`/videoV`）不支持全屏右滑返回。** `page_transition.dart:20`、`:49-51`：视频页用淡入路由，不经过 `_BackGestureDetector`。原因是右滑会和播放器的进度拖动、简介区的横滑冲突，这很可能是有意的；但其他页面都能整屏右滑，只有视频页只能从系统边缘返回，用户可能感觉不一致。
3. **开关的统一程度**（和第 12 条相关）：是全局统一成 `RevampSwitch`，还是只在设置页使用。

---

## 四、这一轮核对过、没有发现问题的点（避免下一轮重复检查）

- `SpringFollower`、`PressableScale`、`AppearIn`/`RiseIn`、`SpringSlide`、`OffsetSettler`、`RevampSwitch`、底栏的 7 个 follower：ticker、Timer、controller 都在 `dispose` 里释放了。
- `CommentSheet.dispose` 里调用 `_history?.remove()` 会触发 `_onBack → _close → _finishClose`：此时子级的 `DraggableScrollableSheet` 已经先一步 detach，`_isOpen` 也已经是 false，所以会直接返回，不会操作已经释放的 controller。`removeLocalHistoryEntry` 在 `persistentCallbacks` 阶段会推迟到下一帧执行，并且有 `isActive` 保护。
- `_finishClose` 先复制 `_threadHistories` 再清空 threads，所以移除 history 时回调的 `_onThreadBack` 会因为越界检查直接返回，不会重复释放。
- 全屏右滑返回会通过 `ModalRoute.popGestureEnabled` 判断：有 local history（评论面板打开着）或者 `PopScope(canPop: false)` 时不会开始手势，不会出现页面卡在半路的情况。
- `RevampTopInset` 覆盖了首页所有标签类型（直播、推荐、热门、排行、番剧、影视）和动态页。
- `CommentSheet` 横竖屏切换时，`onShowReplies` 和 `_panelOpeners` 会在 `dispose` 里按身份比较后清空，所以横屏时楼中楼和合集会回到上游的 bottom sheet。
- `PublishRoute.pendingMorph`：`onReply` 是同步 push 的，`Future.microtask` 清空之前路由已经读到了这个值。
- `tool/patches/` 三个补丁：玻璃只在颜色 alpha < 1 时生效；M3 默认的 dialog 和 sheet 的 `shadowColor` 是透明的，半透明 Material 下面不会透出阴影；菜单的 elevation 主题已设为 0。
- 应用内所有 `FloatingActionButton` 都已经换成 `RevampFab`。

---

## 处理进度（2026-11-03）

- **已修**：第 1、2、3、4、5、6、7、9、13 条；第 10 条只修了私信页左右没对齐，搜索页的分组令牌还没收拢；第一轮第 1 条（横屏没有发布入口）由新侧栏的「+」补上了。
- **未动**：第 8 条（弹幕开关逻辑复制三份）、第 11 条（标签胶囊两套实现）、第 12 条（开关两套外观），以及「设计取舍」三项，等定下来再做。
- **需真机**：H、I、J、K，以及第一轮的 A、C、D、E、G，仍待确认。

### 2026-11-04 补修

- **评论面板**：退出视频页时不再误调 `play()`（第一轮 A）；底图截取以最后一次为准，旧截图不会盖掉新截图（E）；底图按 1 倍分辨率截，成本减半（G）；面板盖住播放器后 200ms 再截一次，避免停在过时的一帧（K）。
- **横屏评论头**：去掉实时 `BackdropFilter`，改成按封面色调的 94% 不透明底色（第一轮 D）。
- **第 8 条**：弹幕开关收成 `PlPlayerController.toggleDanmaku()` 一处，重排版视频页与弹幕栏共用；上游视频页那份不动。
- **第 10 条**：新增 `RevampSliverGroup`，搜索页分组与通用设置页都走它。
- **第 11 条**：只留 `PillTabIndicator` 一套胶囊，玻璃标签栏也用它，补了 1px 高光描边。
- **第 12 条**：`RevampSwitch` 改为 52×32，与主题开关同尺寸。
- **第一轮第 8 条**：我的页箭头、搜索页分组展开、底栏与侧栏的图标切换，统一换成弹簧曲线，时长给足让弹簧落定。
- **仍需真机**：H（转场中着色器位置）、I（大字体下推荐卡溢出）、J（切换视频后封面 Hero），C（旋转后面板状态丢失）暂按现状保留。

## 建议的修复顺序

1. 第 1 条（双击推两页，改几行）、第 3 条（离线全屏弹幕入口）、第 2 条（点赞爆动画误触发）
2. 第 4、5、6 条（改动小，用户能直接看到）
3. 真机确认 H、A、I，以及第一轮的 C、D
4. 第 7–13 条清理项，以及「设计取舍」三项

---

# 第三轮审计（2026-11-04，HEAD `255ea2bdf`）

范围：`64a3d6df1..HEAD` 的改动（31 个文件），重点是新侧栏 `liquid_glass_navigation_rail.dart`、横屏双栏设置 `_buildRevampWide`、`RevampSliverGroup`、统一后的 `PillTabIndicator`、52×32 的 `RevampSwitch`、`toggleDanmaku`、评论面板截图的 `_captureId`/`_route`；另外评估了未改版的高频页面，以及番剧卡和视频卡的差异。
以下事项不再列出：150ms 点击延迟、纯黑主题、退回上游原版、视频页不支持全屏侧滑返回，以及需真机确认的 H、I、J、C。

## 一、确定问题

### 🟠 3-1. 横屏手机上，侧栏顶部的头像/消息/搜索块会压到导航胶囊上
- **位置**：`lib/common/widgets/liquid_glass/liquid_glass_navigation_rail.dart:401-430`；接入点在 `lib/pages/main/view.dart:457-460`
- **问题**：侧栏的位置是从底部往上排的：`railTop = (height - railHeight - _kGap - _kWidth).clamp(0, height)`。剩下给顶部块的高度是 `railTop - 12`，而这个块（`Align` 里的 `_GlassBlock`）并没有按这个高度压缩自己。
- **依据**：`useBottomNav = isPortrait`（`main/view.dart:84`），所以手机一转横屏就会显示侧栏。按 3 个标签算，导航胶囊 3×60+8 = 188，加上间距 12 和底部圆钮 60，共占 260。顶部块是头像 34 + 消息按钮 48 + 搜索按钮 48 + 间距 12 + 上下内边距 20 ≈ 162。横屏手机的可用高度一般是 360–412dp，减去状态栏和上下边距后大约 320，这时 `railTop ≈ 58`，顶部块只分到约 46dp。`Column(mainAxisSize: min)` 会溢出（debug 下出现黄黑条），由于 `Stack` 设了 `clipBehavior: none`，溢出的部分直接画在导航胶囊上面。标签更多时（4–5 个）平板也可能出现。
- **最小修法**：空间不够时把顶部块折叠起来。比如判断 `railTop - _kGap < 所需高度` 时，只保留搜索按钮，或者把顶部三个按钮横排成一行放在导航胶囊上方；也可以在这种情况下不再从底部排起，改成从顶部开始依次排列，并允许整列滚动（`SingleChildScrollView`）。

### 🟡 3-2. 面板盖着视频时转屏，`_pausedBySheet` 会一直留着
- **位置**：`lib/pages/video/widgets/comment_sheet.dart:235`、`lib/pages/video/revamp_view.dart:21-33`
- **问题**：`dispose` 时只有 `_route?.isCurrent` 为真才调用 `onCoverPlayer(false)`。转屏的那一刻如果视频页上面还盖着一个弹出路由（比如打开了回复框 `PublishRoute`，或者某个对话框），`isCurrent` 为 false，`_pausedBySheet` 就不会被清掉。
- **依据**：以后只要面板再盖住一次视频（这时视频是暂停的，`_pausedBySheet` 不会被重新设置），面板一离开就会执行 `play()`，把用户自己暂停的视频又放出来。
- **最小修法**：`dispose` 里始终通知页面，由页面自己决定要不要播放：`onCoverPlayer(false)` 改成两个回调，或者在 `_onCoverPlayer` 里先 `_pausedBySheet = false`，然后只有在 `ModalRoute.of(context)?.isCurrent == true` 时才 `play()`。

### 🟡 3-3. `delayTap` 的全局锁会持续到网络请求结束
- **位置**：`lib/common/motion/pressable_scale.dart:38-48`；涉及 `video_card_v.dart:52`、`video_card_h.dart:261`
- **问题**：`_tapPending` 要等 `await onTap()` 完全结束才会释放。卡片没有 `cid` 时，`onTap` 里还要 `await SearchHttp.ab2cWithDimension(...)`。
- **依据**：网络慢或请求超时时，整个 App 的所有视频卡片都点不动（锁是 static 的），直到这个请求返回。双击推两页的问题，其实在 push 发起的那一刻就已经挡住了，用不着等异步部分结束。
- **最小修法**：不等待 `onTap` 的结果。延迟到点后先解锁，再调用 `onTap()`；或者把锁的时长限制在 `tapDelay + 一帧`。这样仍然能挡住 150ms 内的连点。

### 🟡 3-4. 只有一个导航页时，仍然显示一个只有一格的侧栏
- **位置**：`lib/pages/main/view.dart:457-460`
- **问题**：底栏分支有 `navigationBars.length > 1` 的判断，侧栏分支没有。只有一格的侧栏仍然有胶囊，按住也会撑开。上游这种情况只显示头像和搜索。
- **最小修法**：`length <= 1` 时只渲染侧栏的顶部块和动作圆钮，或者沿用上游 `_sideBar()` 最后那个分支（`main/view.dart` 中 `Container(width: 80, child: userAndSearchVertical())` 的写法）。

## 二、已改版页面之间仍然割裂的地方

| # | 问题 | 位置 | 最小修法 |
|---|---|---|---|
| 3-5 | **圆角仍然没有令牌**（第一轮第 7 条的后半，到现在还没做）：面板圆角 28 写在三处，回复框 24，菜单 20，竖卡封面 16，横卡封面 14，都是字面量 | `revamp_theme.dart:68/91/103`、`comment_sheet.dart:695`、`reply_new/revamp_view.dart:8`、`video_card_v.dart:144`、`video_card_h.dart:41` | 在 `Revamp` 里补 `sheetRadius = 28`、`menuRadius = 20`、`coverRadius = 16`，几处改成引用；横卡封面可以用现有的 `Revamp.tileCorner`（14） |
| 3-6 | **「选中」的底色有四套**：主题标签胶囊用 `surfaceContainerHighest`；底栏和侧栏用黑/白 10%；宽屏设置左栏的选中行用 `secondaryContainer`（`setting/view.dart:166`）；弹幕开关用 `secondaryContainer`（`video/revamp_view.dart` 弹幕栏） | 同左 | 宽屏设置的选中行改用 `PillTabIndicator` 的颜色 `surfaceContainerHighest`，与标签一致；弹幕开关属于「开关」语义，可以保留 |
| 3-7 | **UP 主空间的标签栏下面多一条分割线**：页面显式设置了 `dividerColor: outline@0.2`，盖掉了主题里的透明分割线，其他页面的胶囊标签下面都没有这条线 | `lib/pages/member/view.dart:155` | `dividerColor: Revamp.enabled ? Colors.transparent : …`，改 1 行 |

## 三、未改版的高频页面（按「收益 ÷ 改动量」排序）

1. **消息四页**（回复我的、@我的、收到的赞、系统通知：`lib/pages/msg_feed_top/{reply_me,at_me,like_me,sys_msg}/view.dart`）。四页都是 `SliverList.separated` 加 `Divider(indent: 72)`，和私信列表改版前的结构一样。
   最小改法：照 `whisper/view.dart` 的 `_revampSessions`，在 `Revamp.enabled` 时改用 `SliverList.builder`，每行用 `revampGroupRow(index, count)` 包起来，去掉分割线。每页大约 10 行；也可以抽一个 `revampGroupedList(...)` 让四页共用。从「消息」页的入口点进来，割裂感最明显。
2. **UP 主空间**（`member/view.dart`）。头部的 `user_info_card` 和投稿列表的卡片（`video_card_h_member_video`）都已经是新样式，只差标签栏那条线（3-7）。改 1 行，收益不错。
3. **动态详情和专栏**（共用 `lib/pages/common/dyn/common_dyn_page.dart`）。动态正文复用的是 `DynamicPanel`（已改版），FAB 已经是 `RevampFab`。剩下评论区的排序头 `SliverFloatingHeaderWidget` 还是不透明的 `surface` 条。
   最小改法：照 `video/reply/view.dart` 的 `_revampHeader`，用 94% 不透明的 `surface` 底色（这里没有封面色调），大约 10 行。楼中楼走的是 `scaffoldState.showBottomSheet`，已经有主题补丁带来的玻璃和弹簧，不用改。
4. **私信详情**（`whisper_detail/view.dart`）。气泡圆角 16，和整体风格基本一致；差别主要在底部输入栏，还是上游的平铺样式。
   最小改法：输入区在 `Revamp.enabled` 时套上 `GlassBox(radius: 24)`，并留出 12 的边距浮在内容上方，和回复框（`reply_new/revamp_view.dart`）一致。大约 20–30 行。
5. **历史、收藏、稍后再看**。标签已经跟随主题，列表卡片（`history/widgets/item.dart`、`fav_video_card.dart`、`video_card_h_later.dart`）也已改版，FAB 是 `RevampFab`。剩下顶栏是小号 `AppBar`，以及多选模式下的底栏。
   最小改法：顶栏换成 `RevampLargeTitle`（参考设置子页）。不过这几页的顶栏里有搜索、多选、清空等操作，换成大标题要重新安排这些按钮，收益一般，建议往后放。
6. **直播间**（`live_room/view.dart`）。它有自己的深色沉浸式界面和单独的播放器，跟改版的浅色玻璃体系关系不大。只建议把播放器上的按钮套上 `Revamp.overlayRound`，做法和视频页一样，其他维持现状。

## 四、番剧卡与视频卡的具体差异

番剧卡共有四个几乎一样的实现：`pgc/widgets/pgc_card_v.dart`、`pgc/widgets/pgc_card_v_timeline.dart`、`pgc_index/widgets/pgc_card_v_pgc_index.dart`、`member_pgc/widgets/pgc_card_v_member_pgc.dart`。都还是上游的写法：

| 项目 | 视频卡 `VideoCardV` | 番剧卡 `PgcCardV*` |
|---|---|---|
| 外框 | 没有卡片底，封面和文字直接放在页面上 | M3 `Card`，有 `surfaceContainerLow` 底色和 elevation 1 |
| 封面圆角 | 16，统一裁切 | `Style.mdRadius` = 10 |
| 封面信息 | 底部渐变遮罩，上面显示播放量、弹幕数和时长 | 没有遮罩，角标放在右上和左下 |
| 标题 | 最多 2 行，`height: 1.35` | 1 行，`letterSpacing: 0.3` |
| 文字区内边距 | `(2, 8, 2, 4)` | `(4, 5, 0, 3)` |
| 按压反馈 | `PressableScale` 按下回弹 | InkWell 水波纹 |
| 列表入场 | `RiseIn` | 没有 |
| 点击 | `delayTap`（150ms，防连点） | 立即跳转 |
| 封面飞入 | `CoverHero` | 没有 |

封面比例 3:4 是番剧海报本来的比例，应该保留。

**最小改法**：抽一个 `RevampPosterCard` 外壳（大约 40 行，写在新文件里）：`Revamp.enabled` 时用 `Material(type: transparency)` 替代 `Card`，封面 `ClipRRect(16)`、`NetworkImgLayer(borderRadius: zero)`，文字区内边距改成 `(2, 8, 2, 4)`，外面套 `Revamp.pressable(...)`（也就是 `RiseIn` 加 `PressableScale`）。四个番剧卡各自只需把外层的 `Card + InkWell` 换成这个外壳，每个文件改 3–5 行。点击延迟和 `CoverHero` 只对视频有意义（番剧页没有首帧封面），可以不加。

## 五、这一轮核对过、没有问题的点

- 侧栏的 5 个 `SpringFollower`、`_RoundGlassButton` 的 follower 都已释放；`_tabAt` 在按下的那一刻（open = 0）计算，坐标是对的；拖动时用 `localDelta / _tabHeight` 计算，不受侧栏撑开的影响；`didUpdateWidget` 只在没有手指按着时同步外部传进来的选中项。
- `useSideBar` 为 true 时，`useBottomNav` 一直是 false，竖屏也显示侧栏；首页的消息胶囊在 `useSideBar` 或横屏时隐藏，这时由侧栏顶部块提供消息入口，没有丢失。
- 宽屏设置：右栏的 `CommonSetting`、`WebDavSettingPage`、`AboutPage` 在 `showAppBar: false` 时都显示大标题，并且不带返回键（`implyLeading`），三者一致；`_toPage` 在横屏时只 `setState` 切换右栏，不会 push 新页面。
- `_revampAccount` 的昵称已经改成 `Obx` 读取（第二轮第 4 条确认已修）。
- 评论面板截图：`_captureId` 能保证只采用最后一次截图；1 倍分辨率时模糊 sigma 改成 24，和原来 `24×dpr` 在物理像素上的效果一样；盖住视频后 200ms 的补截有 `mounted && _covering && _isOpen` 保护。
- `_route?.isCurrent`：页面被 pop 的时候它的 entry 已经不算 present，所以离开页面时不会再调用 `play()`（第一轮 A 确认已修，只剩 3-2 这个边界情况）。
- `CoverPalette`：LRU 上限 200，失败的结果不缓存，灰色封面返回哨兵值（不缓存为蓝色）；`_noColor = 0` 不会和真实颜色冲突，因为参与量化的像素都是 alpha = 255。
- `toggleDanmaku` 写成扩展方法放在改版自己的文件里，没有改上游控制器；改版里的两处都改成调用它了。
- 离线视频全屏时，顶栏的弹幕按钮已经恢复（`header_control.dart` 的条件里加了 `!isFileSource`）。

## 第三轮建议修复顺序

1. **3-1**：横屏手机上侧栏顶部块压到导航胶囊。横屏手机必定出现，所有登录用户都能看到。
2. **3-3**：网络慢时全部视频卡片点不动。改动只有两三行。
3. **消息四页改成分组列表**，以及 **3-7** UP 主空间标签栏的分割线（改 1 行）。这两项最能减少高频页面之间的割裂感。

其后：3-2、3-4，番剧卡外壳，3-5 圆角令牌，3-6 选中色。

## 第三轮处理进度（2026-11-04）

- **已修**：3-1（顶部块放不下时在自己的空间里滚动，连一个按钮都放不下时不显示）、3-2（每次盖住时重新判断，不再沿用旧标记）、3-3（锁最多持续 1 秒）、3-4（只有一页时不显示导航胶囊，只留顶部块和动作钮）、3-5（`Revamp.sheetRadius / fieldRadius / menuRadius / coverRadius / thumbRadius`）、3-6（宽屏设置选中行改用 `surfaceContainerHighest`）、3-7。
