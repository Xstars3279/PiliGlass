# 方案 2 验收清单与令牌清理（ui-revamp）

对照《PiliGlass 界面整改方案2》第 12.2 节逐项自查。截图来自 Android 模拟器（Pixel 9 Pro XL / MuMu Android 15，深色关）。

## 与方案 2 的差异（用户后续要求）

- **首页左上角头像**：在「直播 / 推荐 / 热门 / 分区 / 番剧 / 影视」这一行的最左侧，与标签栏、铃铛同一行，直径 32、外框 44 的玻璃胶囊；已登录点一下切到「我的」，未登录点一下打开登录页。宽屏用侧栏时不显示——侧栏顶部已经是账号，不必重复。
- **顶部标签栏**：首页与动态页共用 `CenteredGlassTabs`——标签行只占内容自己的宽度、在栏里居中（不再靠左留白）；胶囊跟着左右滑动的页面实时移动；窄屏放不下时整行可横滑、右边缘 24 渐隐，并且把选中的标签尽量滚到中间；一行只有一个标签时给一个小胶囊。
- **顶栏居中开关**：设置 › PiliGlass 特性 › 界面 › 「顶栏标签居中」，默认开；关掉后标签行占满整宽、从左边排起（同上游的 TabBar），切换立即生效。
- **动态页左侧头像栏**：栏宽 56、头像 40、行高 68（原 64 / 44 / 84），头像与名字间距 2、两行之间约 14；栏顶和右侧动态卡片一样留出悬浮顶栏的高度，滚动时从顶栏下穿过。
- **首页顶栏改走 appBar**：`_floatingTabs` 改成 `Scaffold(extendBodyBehindAppBar: true, appBar: …)`，与动态页同一条绘制路径。v0.1.4（`f93e39a9e` 把顶栏浮到 feed 上）之后，顶栏左侧一截的玻璃**底色在、模糊没有**，静止也不恢复；动态页顶栏在 appBar 里一直正常。顺带不再跨帧复用 `ClipRRectLayer` / `BackdropFilterLayer`。
- **默认透明档位**：从「无」改为「极致」（alpha 0.75、模糊、路上折射）。已有安装里若手动选过档位，仍以存下来的值为准。

## 第 5 批（§6.7 / §7 / §11 / §5.2）

| 项 | 做法 | 实机 |
|---|---|---|
| 顶部标签栏（首页 / 动态） | `lib/common/widgets/liquid_glass/centered_glass_tabs.dart`：按文字量出宽度、在栏里居中（开关可关）；胶囊用 `TabController.animation` 逐帧插值，左右滑页面时跟手移动，点标签也走同一条动画，标签颜色同步渐变、字重在中点切换；放不下时横滑 + 右边缘 24 渐隐；居中时选中项尽量滚到中间，到两端就停在边缘；只有一个标签时也套一个小胶囊；标签行铺满 44 高，文字在胶囊正中（原先高出 4） | ✔ 手机 360dp 与 420dpi 宽窗：点击、左右滑都试过（录屏拆帧确认胶囊逐帧跟手）、动态页同款、文字上下居中 |
| 顶栏居中开关 | 设置 › PiliGlass 特性 › 界面 › 「顶栏标签居中」（`GlassFeatures.centerTabsKey`，默认开、立即生效，不用重启）；关掉时整行占满宽、从左边排起 | ✔ 开：只占文字宽、居中；关：整行占满、靠左 |
| 7.2 字幕让位 | 在 `SubtitleView` 外面加一层 `AnimatedPadding`：控件出现时字幕整体上移（全屏 96、竖屏小窗 82，且不超过画面高度的 45%），控件隐藏后 200ms 落回原位 | 未截图对比：模拟器上控件 1 秒左右就自动隐藏，抓不到同一条字幕的前后两帧；逻辑只加了下边距，风险低，可在手机上直接看 |
| 7.3 倍速 / 清晰度菜单 | 不再用 `PopupMenuButton`，改 `lib/common/widgets/player_menu.dart` 的 `PlayerMenuButton`：`LayerLink` 锚在按钮正上方、留 8；黑 72%（`Revamp.playerMenuColor`）+ 12 模糊、圆角 24、宽 120、行高 48、选中项 15 / 600 primary 加白 12% 圆角块；高度按按钮上方的空间取，超出时菜单内部滚动，不盖住顶部那行按钮；两个按钮本身是纯文字 13 / 500 | ✔ 展开位置、行高、内部滚动都对 |
| 6.7 番剧详情 | 选集行右侧按钮固定为「查看全部」，「已完结 / 连载中 · 全N话 · 地区 · 年份」只在信息块出现一次 | ✔ 鬼灭之刃 刀匠村篇、小羊肖恩 第七季 |
| 11.4 账号切换对话框 | 标题行只留「账号切换」；「详细 / 快速」「登录」移到按钮行最左侧，「取消」onSurfaceVariant、「确定」primary，都是 15 / 500；宽 = 屏宽减 64、最多 360，内边距 24 | 已改，代码审查过，未截图 |
| 11.3 评论操作面板 | 举报 / 屏蔽 / 删除排到最后，与上面的项用 1dp 分割线隔开，行高 48 | 上批已实现，未再改动 |
| 5.2 动态话题 | 写成「# 话题名」，13 / 500 primary，去掉前面的橙色图标块 | 已改，代码审查过，未截图 |

## 12.2 逐项

| 项 | 状态 | 说明 |
|---|---|---|
| 新版页面的文件里搜不到写死的颜色值、圆角值和字号 | ◐ | 新增/重写的文件已全部走 `UiType` / `UiSpace` / `UiRadius` / `ColorScheme`（见下节）。上游文件里带 `Revamp.enabled` 分支的旧代码仍保留上游字面量，属方案第 1 节「不改上游逻辑」的边界 |
| 页面背景亮灰、块纯白，无米色 | ✔ | `UiColor.neutralize` 覆盖两条取色路径；首页、我的、设置、番剧、直播截图一致 |
| 白块无阴影，只有底栏/标签栏/菜单/对话框有 | ✔ | `cardTheme.elevation = 0`，`RevampGroup` 无 elevation；`UiGlass.shellShadow/panelShadow` 只给悬浮层 |
| 默认档位下没有透明或模糊表面 | 已改 | 用户后来要求默认就是「极致」（75% + 模糊 + 折射），`UiGlass.level` 的默认值已从 `none` 改为 `extreme`；「无 / 标准」仍可手动选 |
| 主题色只出现在选中项、主按钮、进度条与开关、文字链接 | ◐ | 详情页昵称的会员粉已去掉；番剧「大会员」角标待改粉色；上游未改版页面仍有个别主题色装饰 |
| 首页滚到最花封面处，顶部标签与底栏文字清晰 | ✔ | `_shots/home2.png` |
| 底栏边缘和缝隙没有漏出半截文字 | ✔ | 标签栏 24 渐隐 + 底栏渐变遮罩 |
| 封面数据在纯白封面可见 | ✔ | 视频卡、番剧卡、直播卡均为底部 40% 黑遮罩 + 白色 11/500 |
| 次要文字在白块和灰背景上都看得清 | ✔ | `onSurfaceVariant`（`UiColor.neutralize` 给中性深灰），未再调浅 |
| 同类列表行高、头像、尾部图标一致 | ✔ | 设置页 56 行、我的页 40 图标槽位、右侧箭头同一条竖线 |
| 全屏可点控件 ≤ 15 | ◐ | 重组后：顶部 7（返回/标题/时间/赞/币/藏/⋯）+ 中部 2（锁定/截图）+ 底部 8（播放/弹幕框/弹幕开关/弹幕设置/字幕/倍速/清晰度/退出）＝ 17；「回到主页」「分享」「画中画」「自动（画面比例）」「高能进度条」「翻译」已收进 ⋯，「选集」仍留在竖屏的控件行 |
| 可点击区域 ≥ 40dp 且不重叠 | ◐ | 全屏 48、卡片「更多」40、底栏胶囊 48；上游未改版页面未逐一核对 |
| 深色模式再检查一遍 | ✔ | 首页、设置页、视频详情、我的页已实机检查（`_shots/dark_home.png`、`dark_setting.png`、`dark_video.png`、`dark_mine.png`）：近黑底、深灰块、文字可读、悬浮层用 1dp 描边代替阴影 |
| 同步上游时冲突只在入口文件和主题文件 | ◐ | 现状是「就地加开关」，冲突面比方案设想的大；入口集中在 `main.dart`、`revamp.dart`、`revamp_theme.dart`、`ui_tokens.dart` |

## 新增/重写文件的令牌覆盖

以下文件不含写死的颜色、圆角或字号（控制尺寸如 24 / 36 / 48 / 64 与动画时长除外）：

- `lib/common/ui_tokens.dart`、`revamp.dart`、`revamp_theme.dart`
- `lib/common/widgets/revamp_poster_card.dart`、`revamp_switch.dart`、`badge.dart`
- `lib/common/widgets/video_card/video_card_v.dart`、`video_card_h.dart`
- `lib/pages/mine/revamp_view.dart`、`search/revamp_view.dart`、`video/revamp_view.dart`
- `lib/pages/video/reply_new/revamp_view.dart`、`whisper_detail/revamp_view.dart`
- `lib/pages/video/widgets/comment_sheet.dart`
- `lib/pages/live/widgets/live_item_app.dart`
- `lib/pages/dynamics/widgets/up_panel.dart`、`dynamic_panel.dart`、`action_panel.dart`
- `lib/pages/whisper_detail/widget/chat_item.dart`
- `lib/common/widgets/custom_toast.dart`
- `lib/common/widgets/player_menu.dart`
- `lib/common/widgets/liquid_glass/centered_glass_tabs.dart`
- `lib/pages/video/introduction/pgc/widgets/season.dart`、`pgc_panel.dart`

允许保留的字面量（不算违规）：

- 遮罩渐变的两端色（`0x00000000 → 0x99000000 / 0x8C000000`），是遮罩本身的定义；
- 视频/直播画面的控制层：黑 32% 圆、白 16% 胶囊，属 G3 播放器控件；
- 品牌色（`0xFF5CB67B` 的 PiliGlass 图标底）；
- 控制尺寸与动效时长（24 / 36 / 48 / 64、120 / 220 / 300 / 460ms）。

## 仍未完成

无阻塞项。上游未改版页面里仍带上游自己的字面量，按方案第 1 节「冷门页面不逐个改，靠全局主题兜底」处理，不在本次清理范围。
