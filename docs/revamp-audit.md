# PiliGlass 改版代码审计（第一轮）

审计对象：`ui-revamp` 分支相对上游 `upstream/main` 的 117 个文件改动（+8147 / −901）。
方法：按六条设计理念逐条核对代码，不跑 App。标记为「需真机」的条目只能从代码推断，要上手确认。

严重度：🔴 影响功能/明显割裂　🟠 体验不一致　🟡 小问题/清理项

---

## 一、确定问题（读代码已能确认）

### 🔴 1. 横屏/平板下「发布动态」入口消失
- `lib/pages/dynamics/view.dart`：`Revamp.enabled` 时把顶栏的 `+` 按钮去掉了，理由是“底栏圆钮负责发布”。
- 但 `lib/pages/main/view.dart` 在横屏或开启侧边栏（`useBottomNav == false`）时不显示底栏，只显示侧边栏，而侧边栏里没有发布按钮。
- 结果：平板、横屏手机、开了侧边栏的用户，动态页没有任何发布入口。
- 修法：去掉 `+` 的条件改成 `Revamp.enabled && _mainController.useBottomNav`。

### 🔴 2. 视频卡片改版不受总开关控制
- `video_card_v.dart` / `video_card_h.dart`：去掉卡片底、16/14 圆角、`PressableScale`、`delayTap` 都是无条件生效的，`Revamp.enabled` 只控制了 `RiseIn`。
- 关掉「液态玻璃底栏」后，首页、搜索、历史等列表仍是新卡片，违背“关掉即回原版”。
- 同样无条件生效的还有：`ugc/widgets/action_item.dart`（点赞投币图标 18→22、`_PopIcon` 动画）。
- 修法：卡片把原版 `Card` 分支保留在 `!Revamp.enabled` 下（git 历史里有原代码）。

### 🟠 3. 点视频卡片固定延迟 150ms 才跳转
- `PressableScale.delayTap` 用 `Future.delayed(150ms)` 等按压动画回弹再跳转，**所有**视频卡片都有，每次打开视频都慢 150ms。
- 延迟期间没有防重入，快速双击会推两次播放页（原版直接 `onTap` 时窗口很小，现在拉长了）。
- 建议：延迟降到约 60–80ms，或者按下就跳转、让回弹和转场同时走；加一个 `_pushing` 标志防双击。

### ~~🟠 4. 纯黑主题把所有玻璃浮层都盖成了不透明~~（更正：结论夸大）
> 复核：`darkenTheme` 没有覆盖 `modalBackgroundColor`，所以底部弹出面板在纯黑模式下仍是玻璃。真正变成不透明的只有对话框和长按菜单；它们本来就叠在纯黑背景上，模糊后的差别几乎看不出来，实际体验正常（已由真机确认）。降级为 🟡，不处理。

原描述：
- `theme_utils.dart`：`darkenTheme` 在 `RevampTheme.apply` **之后**执行，把 `dialogTheme`、`bottomSheetTheme`、`popupMenuTheme` 的背景重设为不透明色。
- 结果：纯黑模式下弹窗、菜单、底部面板没有玻璃效果，而且失去了 rim 边框以外的所有改版观感。
- 另外 `surfaceContainerLow`（`RevampGroup` 的底色）没被压暗，纯黑背景上分组卡片是普通深灰，和其他被压暗的卡片色阶不一致。
- 修法：改版开启时，`darkenTheme` 用带 alpha 的颜色（保持 0.72/0.82/0.85），并补上 `surfaceContainerLow`。

### 🟠 5. 五个页面的标签栏还是旧胶囊样式
`search_result` 已经改为跟随主题的凸起 pill，但下面这些页面仍在本地写死 `indicator: BoxDecoration(secondaryContainer…)` + `labelColor: onSecondaryContainer`，绕过了 `RevampTheme` 的 `tabBarTheme`：
- `lib/pages/fav/note/view.dart`
- `lib/pages/fav/pgc/view.dart`
- `lib/pages/member_contribute/view.dart`（UP 主空间「投稿」）
- `lib/pages/pgc/view.dart`
- `lib/pages/pgc_review/view.dart`

修法与 `search_result/view.dart` 相同：`Revamp.enabled` 时 indicator/labelColor 传 null。

### 🟠 6. 设置的二级页面风格不一致
- `common_setting.dart` 改成了大标题 + 圆角分组，但 `lib/pages/setting/pages/` 下的 7 个页面（底栏设置、取色、显示模式、字体、全屏快捷、日志、倍速）以及 webdav、sponsor_block、login_devices、whisper_settings、space_setting、settings_search 仍是普通 `AppBar` + 平铺列表。
- 从「设置」一路点进去，会在新旧两种风格间来回跳。

### 🟡 7. 令牌没被复用
- `common_setting.dart` 手写了一份 `DecoratedSliver` + `circular(24)`，和 `RevampGroup` 重复；应改成引用 `Revamp.groupRadius`，或抽一个 `RevampSliverGroup`。
- 改版代码里写死的圆角有 28/24/20/16/14/10/8/6 共 8 种。建议在 `Revamp` 里补上 `sheetRadius = 28`、`menuRadius = 20`、`coverRadius = 16`，避免各处自行取值。

### 🟡 8. 部分动效仍用固定曲线模拟弹簧
理念是“统一用 Springs”，但这些地方用了 `Duration + Curves.easeOutBack/easeOutCubic`：
- `mine/revamp_view.dart`（250ms easeOutBack、320ms easeOutCubic）
- `search/revamp_view.dart`（520ms easeOutBack）
- `liquid_glass_navigation_bar.dart`（AnimatedSwitcher 260ms easeOutBack）
- `comment_sheet.dart` 里 4 处 260–320ms 曲线动画
- `ambient_background.dart`（600ms easeOut）、`publish_route.dart`

颜色/透明度渐变用曲线没问题；**位移和缩放**建议换成 `Springs.*`，否则被打断时会跳变，不能接住手势速度。

---

## 二、可疑点（需要真机确认）

| # | 怀疑的问题 | 依据 | 复现方法 |
|---|---|---|---|
| A | 🔴 退出视频页时视频/音频又响了一下 | `comment_sheet.dart` 的 `dispose` 里，如果面板正盖着播放器，会调用 `onCoverPlayer(false)`，进而执行 `player.play()` | 评论面板上拉盖住视频（视频暂停）→ 直接按返回退出。开了后台播放时更容易听出来 |
| B | 🟠 盖着播放器时切后台再回来，视频在面板下面自己播放 | `_pausedBySheet` 只管面板，没管 App 生命周期；上游有回前台自动续播的逻辑 | 面板上拉盖住视频 → 切到桌面 → 回来 |
| C | 🟠 旋转屏幕后评论面板状态丢失 | 横屏宽屏时 `video/view.dart` 不再包 `CommentSheet`，回到竖屏时重建，`initState` 里会把 `_isOpen` 重置为 false | 打开评论 → 进入某条楼中楼 → 转横屏 → 转回竖屏 |
| D | 🟠 平板/横屏下评论区掉帧 | 非面板版评论区的置顶头（`reply/view.dart` 的 `_revampHeader`）是实时 `BackdropFilter(sigma 20)`，视频在旁边同时播放；这正是理念 6 想避免的情况 | 平板横屏播视频，滑评论区，看帧率（低端 OpenGLES 机型更明显） |
| E | 🟡 评论面板模糊底图偶尔是旧画面 | `_captureBackdrop` 在打开时和 600ms 后各截一次图，两次异步可能乱序完成，早的结果覆盖晚的 | 网络慢时打开评论，看面板后面透出的是不是图片还没加载完的样子 |
| F | 🟡 快速双击视频卡片打开两个播放页 | 见确定问题 3 | 快速连点封面两下 |
| G | 🟡 面板截图在高分屏上耗时 | 按 `devicePixelRatio` 全分辨率截图，再做 sigma 24×dpr 的模糊，2K 屏一张约 1440×3200 | 低端机上点开评论，看第一帧有没有卡顿 |

---

## 三、未覆盖改版的页面

全局主题（标签 pill、菜单/弹窗/面板玻璃、开关、FAB）对所有页面生效，但下面这些页面没做专门的改版。按使用频率排序：

**高频，割裂感最明显**
- `member/` UP 主空间（只改了 `user_info_card`，页面骨架和标签仍是原版）
- `dynamics_detail/` 动态详情
- `msg_feed_top/`（回复我的、@我的、收到的赞、系统通知）
- `whisper_detail/` 私信聊天页（列表页改了，点进去是原版）
- `history/`、`fav/`、`later/` 的页面外壳（只有列表卡片改了，顶栏、标签、编辑模式是原版）
- `article/` 专栏
- `live_room/` 直播间

**中频**
- `follow/`、`fan/` 列表项（只改了按钮颜色）
- `pgc_index/`、`popular_series/`、`popular_precious/`、`subscription/`
- `search_panel/` 中除视频外的 user、live、pgc、article 结果页
- `login/`

**低频**：其余 60 多个页面（各种 `*_search`、`*_sort`、`member_*` 子页、日志页等）。建议靠全局主题兜底，不逐个改。

---

## 四、工程层面

- **上游合并风险最大的文件**：`video/view.dart`（+201）、`reply/view.dart`（+155）、`dynamics/view.dart`（+137）、`mine/view.dart`（+140）、`about/view.dart`（407 行改动）。其中 `about/view.dart` 改动量和新文件差不多，可以考虑像 `mine` 一样拆出 `revamp_view.dart`。
- **开关语义**：`Revamp.enabled` 和 `MainController.dockSearch` 是同一个条件（`floatingNavBar && liquidGlassNavBar`），但 `mine`、`search`、`home` 用 `dockSearch`，其他地方用 `Revamp.enabled`。建议统一用 `Revamp.enabled`；`dockSearch` 再加上 `useBottomNav` 判断，横屏问题（确定问题 1）会自然消失。

---

## 建议的修复顺序

1. 确定问题 1、2，可疑点 A（功能性 / 开关承诺）
2. 确定问题 3、4、5（改动小，体验提升明显）
3. 可疑点 B–D 真机确认后修
4. 未覆盖页面里的「高频」组：UP 主空间、动态详情、消息、私信详情
5. 令牌收拢、曲线换弹簧、`about` 拆文件
