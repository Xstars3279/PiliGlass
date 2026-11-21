# PiliGlass 界面分区总览

> 这份文档把 PiliGlass 的浮层按「区域」分类，作为后续批量统一的索引。
> 详细清单见三份子文档：
> - [右上角动作区](regions-actions.md)
> - [弹窗 / 面板区](regions-overlays.md)
> - [顶部标签区](regions-tabs.md)
>
> 审计只读完成，`lib/` 的改动以工作区为准；行号会随改动漂移，以 `file:line` 就近查找。

## 1. 三类区域

| 区域 | 典型位置 | 统一外观 | 统一动效 |
|---|---|---|---|
| **右上角动作区** | AppBar / PlayerBar 右侧、页面自绘动作行 | `GlassActionBar`：一颗 `GlassCapsule`，按钮保持裸 `IconButton` | 每个按钮独立 `LiquidPress`：按下膨胀、拖出跟手、松开回弹 |
| **弹窗 / 面板区** | 底部 sheet、播放器设置、发布面板、收藏面板、对话框 | 面板自身沿用 `GlassBox` / `UiGlass.panel` | `GrowFromBottom`（贴底面板）或 `GrowFromRect`（大面板从按钮长出）；菜单内 `LiquidPress(pullPastEdges: true)` |
| **顶部标签区** | 首页 / 动态 / 会员 / 历史 / 收藏 / 搜索 / 直播分区 | `GlassTabStrip`：玻璃胶囊 + 药丸；嵌套层用无胶囊模式 | 药丸跟 `TabController.animation`；标签可点按、可横向拖动（`scrub` / `live`） |

## 2. 现有积木

| 组件 | 文件 | 用途 |
|---|---|---|
| `LiquidPress` | `lib/common/widgets/liquid_glass/liquid_press.dart` | 按压膨胀 + 橡皮筋跟手；受「按压回弹」开关控制 |
| `GlassActionBar` | `lib/common/widgets/liquid_glass/glass_action_bar.dart` | 右上角动作区：胶囊 + 每键 `LiquidPress` |
| `GlassIconButton` | `lib/common/widgets/liquid_glass/glass_icon_button.dart` | 单个裸图标：轻底色 + 玻璃描边 + 按压缩放 |
| `GlassPopupAnchor` | `lib/common/widgets/liquid_glass/glass_menu.dart` | 三点菜单：从按钮弹出、弹簧放大、菜单按压膨胀 |
| `GrowFromBottom` | `lib/common/widgets/grow_from.dart` | 贴底面板从输入条 / 回复按钮向上长 |
| `GrowFromRect` | `lib/common/widgets/grow_from.dart` | 大面板从远处按钮长出 / 缩回；`anchor` 选择生长角 |
| `morphRectOf(context)` | `lib/common/widgets/grow_from.dart` | 取控件全局矩形，写入 `PublishRoute.pendingMorph` |
| `GlassTabStrip` | `lib/common/widgets/liquid_glass/glass_tab_strip.dart`（待建） | 顶部标签：胶囊、药丸、点按、拖动 |
| `CenteredGlassTabs` | `lib/common/widgets/liquid_glass/centered_glass_tabs.dart` | 首页 / 动态的现有玻璃标签（后续退化为 `GlassTabStrip` 包装） |

## 3. 已完成

- 首页 / 动态顶部胶囊、头像、铃铛：`LiquidPress`；
- 底栏搜索按钮：`LiquidPress`；
- 我的页右上角动作组：每键 `LiquidPress`（后续可换成 `GlassActionBar(refraction: false)`）；
- 视频卡片 ⋯：`GlassIconButton` + `GlassPopupAnchor`；
- 视频页顶部 / 折叠栏 ⋯：`LiquidPress`，设置面板 `GrowFromRect`；
- 视频「更多设置」面板：从 ⋯ 按钮长出；
- 视频画质 / 音质 / 解码：从设置行长出（`GrowFromRect`）；
- 视频「发弹幕」条 / 旧「发弹幕」按钮：面板 `GrowFromBottom`；
- 评论「回复」按钮：回复面板 `GrowFromBottom`；
- 播放器倍速 / 画质菜单：按钮膨胀 + 菜单从按钮展开 + 菜单按压膨胀；
- 评论输入条：`LiquidPress`；
- 动态发布按钮、动态卡片 ⋯：`LiquidPress`；
- 收藏详情 / 关注 / 专栏 / 会员（UP 空间）右上角动作行：`GlassActionBar(refraction: false)`，⋯ 换成 `GlassPopupAnchor`；
- 稍后再看 / 历史 / 我的收藏 / 搜索结果顶部标签：`GlassTabStrip`（胶囊 + 药丸 + 拖动）；
- 首页 / 动态 / 会员顶部标签：`GlassTabStrip` 的拖动（scrub）已打开，药丸跟手、松手提交。

## 4. 待迁移（按优先级）

1. **标签区（下一批）**：`live_area` / `live_area_detail` → `follow` → `pgc_review` → 黑名单 / 通讯录 / 弹幕屏蔽 / 会员搜索 / 直播搜索 / 动态详情；其余见 `regions-tabs.md` 的 18 个机械清单。
2. **动作区（下一批）**：`history`（与标签同文件）→ `whisper` → `audio` → `search` → 下载 / 直播列表。
3. **面板区**：动态发布（全高 sheet）、动态卡片「更多」、音频「更多」/播放设置、收藏面板 `FavPanel`、转发面板；需要 `showGrowingSheet` / `showGrowingDialog` 两个 helper。
4. **暂不迁移**：播放器画面上的白色控件、直播 HUD、图片查看器、系统选择器、PGC 时间表（横向列表抢手势）。

## 5. 约束

- `LiquidPress` 只作用于绘制，布局和命中区域不变；锚定菜单 / tooltip 仍看到静止矩形。
- `GlassActionBar` 默认 `refraction: true`；要和「我的」完全一致时传 `refraction: false`。按钮本身不要再套 `GlassIconButton`，避免双层缩放。
- 视频画面上的按钮不要加玻璃币；只用 `LiquidPress` + 裸 `IconButton`。
- `GrowFromRect.from` 是全局坐标；在 `Navigator.push` 前读取，不要在关闭动画中读。
- 标签拖动只接管水平手势；放不下时由标签条内部滚动，避免和 `TabBarView` / 横向列表抢手势。
