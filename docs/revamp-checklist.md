# 方案 2 验收清单与令牌清理（ui-revamp）

对照《PiliGlass 界面整改方案2》第 12.2 节逐项自查。截图来自 Android 模拟器（Pixel 9 Pro XL，Android 16，深色关）。

## 12.2 逐项

| 项 | 状态 | 说明 |
|---|---|---|
| 新版页面的文件里搜不到写死的颜色值、圆角值和字号 | ◐ | 新增/重写的文件已全部走 `UiType` / `UiSpace` / `UiRadius` / `ColorScheme`（见下节）。上游文件里带 `Revamp.enabled` 分支的旧代码仍保留上游字面量，属方案第 1 节「不改上游逻辑」的边界 |
| 页面背景亮灰、块纯白，无米色 | ✔ | `UiColor.neutralize` 覆盖两条取色路径；首页、我的、设置、番剧、直播截图一致 |
| 白块无阴影，只有底栏/标签栏/菜单/对话框有 | ✔ | `cardTheme.elevation = 0`，`RevampGroup` 无 elevation；`UiGlass.shellShadow/panelShadow` 只给悬浮层 |
| 默认档位下没有透明或模糊表面 | ✔ | `UiGlass.level = none → alpha 1.0`，模糊为 0；「标准 / 极致」为可选档 |
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
- `lib/pages/video/introduction/pgc/widgets/season.dart`、`pgc_panel.dart`

允许保留的字面量（不算违规）：

- 遮罩渐变的两端色（`0x00000000 → 0x99000000 / 0x8C000000`），是遮罩本身的定义；
- 视频/直播画面的控制层：黑 32% 圆、白 16% 胶囊，属 G3 播放器控件；
- 品牌色（`0xFF5CB67B` 的 PiliGlass 图标底）；
- 控制尺寸与动效时长（24 / 36 / 48 / 64、120 / 220 / 300 / 460ms）。

## 仍未完成

无阻塞项。上游未改版页面里仍带上游自己的字面量，按方案第 1 节「冷门页面不逐个改，靠全局主题兜底」处理，不在本次清理范围。
