# 右上角动作区 / 顶栏动作行改造清单

> 审计范围：`lib/pages` 下所有页面级 AppBar、SliverAppBar、`PlayerBar` 以及页面内自绘的右上角动作行。
> 本文只做记录，不修改 `lib/` 下任何代码。
> 参考外观：我的页 `lib/pages/mine/revamp_view.dart:10-18` + `lib/pages/mine/view.dart:160-259`。

## 0. 参考实现与组件现状

### 0.1 我的页的右上角块

`_buildHeaderActions` (`lib/pages/mine/view.dart:160-259`) 用 `PlayerBar` 承载：

- 右侧 `_headerGroup` (`lib/pages/mine/revamp_view.dart:10-18`) 在 `_modern` 时套 `GlassCapsule`；
- `GlassCapsule` 内是 `Row(spacing: 5, mainAxisSize: min)`；
- 每个按钮由 `press()` (`view.dart:165-166`) 包一层 `LiquidPress(maxGrowth: 8)`；
- 按钮本身是裸 `IconButton`：`iconSize: 22`、`padding: EdgeInsets.all(8)`、`tapTargetSize: shrinkWrap`；
- `GlassCapsule` 使用 `padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2)`，且未传 `refraction`，即 `false`。

这正好对应 `GlassActionBar` 的默认值（`padding` h4/v2、`spacing` 5、每个 action 自动包 `LiquidPress(maxGrowth: 8)`），唯一的差异是 `GlassActionBar.refraction` 默认 `true`，而我的页当前是 `false`。要“一模一样的我的页”，迁移时显式传 `refraction: false`。

### 0.2 新组件使用现状

| 组件 | 文件 | 现状 |
|---|---|---|
| `GlassActionBar` | `lib/common/widgets/liquid_glass/glass_action_bar.dart:8` | 只有定义，仓库内尚无调用 |
| `GlassIconButton` | `lib/common/widgets/liquid_glass/glass_icon_button.dart:14` | 已用于 `lib/common/widgets/video_popup_menu.dart:324` 和 `lib/pages/video/view.dart:1268` |
| `GlassPopupAnchor` | `lib/common/widgets/liquid_glass/glass_menu.dart:17` | 已用于 `lib/common/widgets/video_popup_menu.dart:47` 和 `lib/pages/video/view.dart:1214` |
| `GrowFromRect` | `lib/common/widgets/grow_from.dart:150` | 由 `PageUtils.showVideoBottomSheet` (`lib/utils/page_utils.dart:498-502`) 使用 |
| `GrowFromBottom` | `lib/common/widgets/grow_from.dart:9` | 由回复面板 `lib/pages/video/reply_new/revamp_view.dart:21-27` 使用 |

### 0.3 推荐判定规则

- 一行 **2 个及以上**动作：`GlassActionBar(actions: [...])`；按钮保持裸 `IconButton`，不要再用 `GlassIconButton`（会双层 `LiquidPress`）。
- **单个裸图标**：`GlassIconButton`；如果它本来就在 `GlassCapsule` 里（如首页消息铃），保留原样。
- **三点菜单**：`GlassPopupAnchor`，锚点可以是裸 `IconButton`、`GlassIconButton` 或整颗胶囊。
- **打开面板 / 底部弹层**：先取按钮的 `RenderBox`，写 `PublishRoute.pendingMorph = rect`，再走 `PublishRoute` / `PageUtils.showVideoBottomSheet`，面板侧用 `GrowFromRect`；从底部输入栏长出来的回复面板用 `GrowFromBottom`。
- **播放器画面上的白色控件**：不要加玻璃币。玻璃底色和 lit rim 会在视频上显形，保留 `LiquidPress` + 裸 `IconButton` 即可。

## 1. 总表

| 页面 | 文件:行 | 当前容器 | 按钮 / 动作 | 打开 | 建议 |
|---|---|---|---|---|---|
| 我的（modern） | `pages/mine/view.dart:167-259`；`mine/revamp_view.dart:10-18` | `PlayerBar` 右侧 + `GlassCapsule` + 每键 `LiquidPress` | 搜索 181-188；消息 190；评论记录 193-201；无痕 203-218；切换账号 220-229；主题 231-241 | `/search`、`/whisper`、`/myReply`、对话框、toggle | **参考实现**；改用 `GlassActionBar(refraction: false)`，删掉每键 `press()` |
| 我的（legacy） | 同上 | 裸 `Row`，无胶囊 | 同上（含设置 244-253） | 同上 + `/setting` | 保持裸排；只在 `_modern` 分支启用玻璃 |
| 首页（dock） | `pages/home/view.dart:172-231` | 左侧头像 `GlassCapsule`；右侧消息 `GlassCapsule` + `LiquidPress` | 头像 185-186 / 235-281；消息 207-226 / `msgBadge` 459-491 | 我的/登录；`/whisper` | 单动作，保留；不要为了凑行做 `GlassActionBar` |
| 首页（legacy） | `pages/home/view.dart:283-332` | 搜索框 + 裸 `Row` | 搜索 287；消息 289；头像 291 | `/search`、`/whisper`、我的 | 搜索主导的整行，保持；最多给消息键单独 `GlassIconButton` |
| 动态（modern，非 rightDrawer） | `pages/dynamics/view.dart:65-92`、`244-250` | 玻璃标签栏，右上动作被置空 | 无 | 发布在 dock / rail | 不改造；发布入口不属于顶栏 |
| 动态（modern，rightDrawer） | `pages/dynamics/view.dart:238-249` | 玻璃标签栏 + `EndDrawerButton` | 打开 UP 面板抽屉 | drawer | 保留；`EndDrawerButton` 是系统控件，不套玻璃 |
| 动态（legacy） | `pages/dynamics/view.dart:37-60`、`202-241` | 34×34 填充圆 `IconButton` + `LiquidPress` | 发布动态 44-58 | `CreateDynPanel` 底部面板 | 单动作；可换 `GlassIconButton(selected: true)`，或保留 |
| 视频页收起顶栏 | `pages/video/view.dart:652-767` | 透明 `Stack`：左裸图标、中播放、右更多 | 返回 699-711；主页 712-725；播放 665-675/729；未播放 `_moreBtn` 733；播放后设置 734-762 | 返回、关闭全部、播放、菜单/设置面板 | 未播放走 `_moreBtn` 菜单；播放后 `LiquidPress` + `Builder`，设置面板已用 `pendingMorph`；左侧保持裸图标 |
| 视频页封面 overlay | `pages/video/view.dart:1137-1207` | 裸白图标 + 黑色阴影 | 返回 1148-1167；主页 1168-1188；更多 1190-1198 | 返回、关闭全部、菜单 | 视频画面，保持；不要玻璃 |
| 视频播放器 `PlayerBar` | `pages/video/widgets/header_control.dart:1884-2228` | `PlayerBar` 的 left/right/title，裸白图标 | 返回 1893-1909；主页 1914-1927；时间/置顶 1934-1960；音频 1963-1977；投屏 1978-1991；片段 1993-2027；弹幕 2037-2104；画中画 2105-2128；赞/币/藏 2131-2204；更多 2206-2226 | toggle / 面板 / 菜单 | 8+ 个控件，**不要** `GlassActionBar`；仅保留 ⋯ 的 `LiquidPress`，设置面板用 `pendingMorph` |
| 历史记录 | `pages/history/view.dart:159-205` | `AppBar.actions` | 搜索 162-166；⋯ 167-202（暂停/清空/删除已看） | `/historySearch`、菜单 + 确认框 | `GlassActionBar(search + GlassPopupAnchor)` |
| 收藏详情 | `pages/fav_detail/view.dart:132-174`、`177-327` | `SliverAppBar.medium.actions`，5 个裸图标 | 搜索 179-195；分享 196-208；页码顺序 209-225；排序 226-245；⋯ 246-324 | `/favSearch`、分享、toggle、排序、菜单/`RepostPanel` | 5 个动作在 360dp 会挤；先做 `GlassActionBar`，同时准备把页码/排序收进 ⋯ 的方案 |
| 关注 | `pages/follow/view.dart:92-149` | `AppBar.actions`，4 个裸图标 | 新建分组 102-109；分组排序 110-119；搜索 120-129；⋯ 130-145 | 对话框、`FollowTagSortPage`、`/followSearch`、`/blackListPage` | `GlassActionBar` + `GlassPopupAnchor` |
| 会员 / UP 空间 | `pages/member/view.dart:107-135`、`358-594` | `DynamicSliverAppBar.medium.actions`，3 个动作 | 预约 359-360 / 196-206；搜索 361-367；⋯ 368-592 | 预约列表 sheet、`/memberSearch`、大量菜单项 | `GlassActionBar`；预约按钮带数量，需留宽 |
| 专栏 | `pages/article/view.dart:279-362` | `AppBar.actions`，2 个裸图标 | 浏览器打开 289-293；⋯ 294-359 | in-app webview、分享/复制/分享至消息 | `GlassActionBar` + `GlassPopupAnchor` |
| 直播（房间顶栏） | `pages/live_room/view.dart:584-735` | 视频上的透明 `AppBar.actions`，1 个 ⋯ | ⋯ 658-732 | 复制/分享/浏览器/分享至消息 | `GlassPopupAnchor`，锚点保持裸白 `IconButton`；不要玻璃币 |
| 直播（播放器 header） | `pages/live_room/widgets/header_control.dart:115-296` | 透明 `Row`，`ComBtn` 白图标 | 返回 120；置顶 138；弹幕 156；音频 185；后台 206；定时 227；⋯ 244 | toggle / 菜单 | 视频画面，保持；不套玻璃 |
| 直播（列表筛选行） | `pages/live/view.dart:93-207` | 页面内 `Row`，3 个 26dp 圆钮 | 封面/首帧 169-181；游戏赛事 183-197；全部标签 199-206 | toggle、webview、`LiveAreaPage` | 可选 `GlassActionBar`（小尺寸），需与筛选标签同高 |
| 话题 | `pages/dynamics_topic/view.dart:173-349` | 头图上的 `DynamicSliverAppBar.medium.actions` | 分享 317-323；⋯ 324-347 | 分享文本、收藏、举报 webview | `GlassActionBar` + `GlassPopupAnchor`；先确认头图对比度 |
| 私信 | `pages/whisper/view.dart:33-96` | `AppBar.actions`，动态数量 | 新增粉丝 36-46；outsideItem 47-66；⋯ 70-93 | webview / 服务端动作 / 菜单 | `GlassActionBar`，但必须把 outsideItem 拆成独立 action，不能整段 `Row` 包一次 |
| 私信二级 | `pages/whisper_secondary/view.dart:43-73` | `AppBar.actions`，1 个 ⋯ | ⋯ 49-72 | 菜单 | `GlassPopupAnchor` + `GlassIconButton` |
| 稍后再看 | `pages/later/view.dart:157-311` | `MultiSelectAppBarWidget` + `AppBar.actions`，图标和文字混合 | 搜索 198-214；排序 215-263；清空 264-306 | `/laterSearch`、菜单 | 不是统一图标行；只把搜索换 `GlassIconButton`，排序/清空保留文字胶囊 |
| 音频 | `pages/audio/view.dart:100-149` | `AppBar.actions`，4 个裸图标 | 片段 103-113；排序 114-129；定时 130-140；更多 141-146 | 详情 sheet、排序、定时对话框、播放列表 sheet | `GlassActionBar`；4 个动作在窄屏需实测 |
| 搜索 | `pages/search/view.dart:105-149` | `AppBar.actions`，2-3 个裸图标 + `TextField` | UID 113-123；清空 124-128；搜索 129-133 | `/member`、clear、submit | 只做右侧 2-3 键 `GlassActionBar`，但 `TextField` 宽度需评审 |
| 下载（列表） | `pages/download/download/view.dart:140-170` | `MultiSelectAppBarWidget` + `AppBar.actions`，2 个裸图标 | 搜索 147-155；多选 156-166 | `DownloadSearchPage`、toggle | `GlassActionBar`；多选态继续用 `RevampMultiSelectBar` |
| 下载（番剧页） | `pages/download/page/view.dart:151-172` | 同上，1 个裸图标 | 多选 158-168 | toggle | `GlassIconButton` |
| 下载（详情） | `pages/download/detail/view.dart:109-130` | 同上，1 个裸图标 | 多选 116-126 | toggle | `GlassIconButton` |
| 下载（正在缓存） | `pages/download/downloading/view.dart:45-65` | 同上，1 个裸图标 | 多选 51-61 | toggle | `GlassIconButton` |

## 2. 其余 AppBar 动作行

这些页面的动作行同样存在，但优先级低，或不属于“右上角图标组”：

| 页面 | 文件:行 | 当前按钮 | 建议 |
|---|---|---|---|
| 收藏 | `pages/fav/view.dart:56-129` | 新建 61-78；排序 83-97；搜索 102-124 | `GlassActionBar`（3 个，均为 `Obx` 条件） |
| 我的评论 | `pages/my_reply/view.dart:58-93` | 导出 81-85；导入 86-90；debug 61-80 | `GlassActionBar`；debug 键不迁移 |
| 直播分区 | `pages/live_area_detail/view.dart:48-57` | 搜索 51-54 | `GlassIconButton` |
| 通讯录 | `pages/contact/view.dart:44-65` | 搜索 47-62 | `GlassIconButton` |
| @我的 | `pages/msg_feed_top/at_me/view.dart:37-54` | 设置 40-51 | `GlassIconButton` |
| 收到的赞 | `pages/msg_feed_top/like_me/view.dart:39-56` | 设置 42-53 | `GlassIconButton` |
| 回复我的 | `pages/msg_feed_top/reply_me/view.dart:37-54` | 设置 40-51 | `GlassIconButton` |
| 评论详情 | `pages/video/reply_reply/view.dart:79-104` | 前往 83-89 | `GlassIconButton` |
| 设置搜索 | `pages/settings_search/view.dart:66-93` | 清空 68-78 | `GlassIconButton`，或保持 TextField suffix |
| 投屏 | `pages/dlna/view.dart:75-85` | 刷新 78-82 | `GlassIconButton` |
| 直播搜索 | `pages/live_search/view.dart:26-47` | 搜索 28-32 | 搜索框内单键，保持或 `GlassIconButton` |
| 用户搜索 | `pages/member_search/view.dart:26-57` | 搜索 28-32 | 同上 |
| 收藏排序 | `pages/fav_sort/view.dart:51-79` | 完成 54-76 | 文字主操作，不要玻璃 |
| 收藏夹排序 | `pages/fav_folder_sort/view.dart:32-54` | 完成 35-51 | 同上 |
| 关注分组排序 | `pages/follow_tag_sort/view.dart:41-69` | 完成 45-65 | 同上 |
| 会员充电榜 | `pages/member_upower_rank/view.dart:91-107` | 充电 94-104 | 文字主操作，不要玻璃 |
| WebView | `pages/webview/view.dart:95-121`、`400` | ⋯ 菜单 97-119；Linux 分支 124-160 | `GlassPopupAnchor`，但 `onSelected` 要改成逐项 `onTap`，Linux 分支保持 |
| 搜索子页（共享） | `pages/common/search/common_search_page.dart:57-89` | 搜索 60-64 + `extraActions` 65 + 输入框内清空 78-85 | 共享组件；改一处影响 download/history/fav/follow/later 五个搜索页 |
| 动态详情 | `pages/dynamics_detail/view.dart:263-289` | 仅横屏比例控件 286-288 | 不是动作行，跳过 |
| 音乐 | `pages/music/view.dart:75-112` | 仅横屏比例控件 106-111 | 不是动作行，跳过 |
| 系统通知 | `pages/msg_feed_top/sys_msg/view.dart:39-48` | 无 actions | 跳过 |
| 发布动态 | `pages/dynamics_create/view.dart:322-375` | 右侧 `FilledButton.tonal` 发布 356-372 | 主操作，不是图标行，不迁移 |
| 转发动态 | `pages/dynamics_repost/view.dart:266-334` | 右侧 `TextButton` 发布 275-286 / 328-334 | 同上 |

## 3. 逐页备注

### 3.1 我的（`pages/mine`，`MinePage`；主 Tab，无独立路由）

- modern：`PlayerBar` (`view.dart:167`) 右侧 `_headerGroup` (`revamp_view.dart:10-18`)。按钮顺序由状态决定：`hasHome == false` 时才有搜索和消息；`GStorage.reply != null` 时才有评论记录；主题/无痕/切号始终有；modern 不显示设置。
- legacy：`_headerGroup` 直接返回 `Row`，没有胶囊。不要无条件套 `GlassActionBar`，否则关闭新版后也会出现玻璃块。
- `msgBadge` 是共享的 `IconButton`，`view.dart:190` 只是把它套进 `LiquidPress`；不要为了 `GlassIconButton` 改 `msgBadge` 的内部尺寸。
- 迁移时删掉 `press()` (`view.dart:165-166`)，否则 `GlassActionBar` 内外各一层 `LiquidPress`，按压会放大两次。

### 3.2 首页（`pages/home/view.dart`，`HomePage`；主 Tab，无独立路由）

- dock 模式 (`_glassTabBar` 172-231)：左侧头像、右侧消息铃各自一个 `GlassCapsule` + `LiquidPress`。它们已经是“单动作玻璃块”，不需要 `GlassActionBar`。
- legacy (`customAppBar` 283-332)：搜索框占 `Expanded`，右侧消息和头像只有 34-38dp。整行是搜索主导，套胶囊会把搜索框挤窄，也会改变首页的识别度。建议只给消息键加 `LiquidPress`/`GlassIconButton`，不要整行胶囊。
- `msgBadge` (`459-491`) 同时被 `main/view.dart:196`、`main/view.dart:556` 使用；改它的 `padding`、`iconSize` 会影响首页、我的、侧栏三处。

### 3.3 动态（`pages/dynamics`，`DynamicsPage`；主 Tab，无独立路由）

- 发布按钮 `_createDynamicBtn` (`37-60`)：34×34、`secondaryContainer` 填充圆、`LiquidPress(maxGrowth: 9)`；打开 `CreateDynPanel.onCreateDyn` 底部面板。
- legacy 时放在 AppBar actions（`210/222/233/236`）或 leading（`240`）；modern 时被 `actions = SizedBox.shrink()` 隐藏（`244-250`），发布入口移到 dock/rail。
- modern 的 `rightDrawer` 分支仍保留 `EndDrawerButton`（`241`），用于打开 UP 面板抽屉；这不是可替换的图标按钮。
- 若要把 legacy 的圆钮换 `GlassIconButton`：用 `selected: true` 得到 `secondaryContainer` 底，尺寸 36/40，和原来的 34 接近；但这是可选的视觉决策。

### 3.4 视频页（`pages/video`，`VideoDetailPageV`；`/videoV`）

- 收起顶栏 `_buildOverlayToolBar` (`view.dart:652-767`)：左侧返回/主页是裸图标，中间“立即/继续播放”，右侧“更多”。右侧在未播放时走 `_moreBtn`（`1213-1275`，`GlassPopupAnchor` + `GlassIconButton`），播放后走 `LiquidPress` + `Builder`（`737-760`）打开设置面板。
- `_moreBtn` 已经是“三点菜单 + 玻璃币”的标准写法：`GlassPopupAnchor` 1214，菜单项 1216-1250，`shadows != null` 时用 `LiquidPress` 1254，否则 `GlassIconButton` 1268。其他页面的 ⋯ 可以照抄。
- 设置面板 `HeaderControlState.showSettingSheet` (`header_control.dart:377-383`) 已经从按钮 `RenderBox` 取 rect 写入 `PublishRoute.pendingMorph`，再由 `PageUtils.showVideoBottomSheet` (`page_utils.dart:483-502`) 用 `GrowFromRect` 长出来。不要重复实现。
- `PlayerBar` (`header_control.dart:1889`) 的右侧是播放器控件，不是页面动作区：8+ 个白色图标，且 `PlayerBar` 在总宽超出时会整体 `scale`（`player_bar.dart:128-137`）。加 `GlassActionBar` 会进一步挤宽并触发缩放，禁止。
- 封面 overlay (`view.dart:1137-1207`) 的白色图标带黑色 `shadows`，属于 G3 播放器控件；保持裸图标。

### 3.5 历史记录（`pages/history/view.dart`，`HistoryPage`；`/history`）

- `_buildAppBar` 159-205：搜索 + ⋯。⋯ 里是“暂停/恢复观看记录”“清空观看记录”“删除已看记录”；清空会再弹确认框。
- 外层是 `MultiSelectAppBarWidget`（97-101）：多选时整个 AppBar 被 `RevampMultiSelectBar` 替换，所以玻璃动作行只需处理普通态。
- 暂停状态还会在 AppBar 下加一条 `_buildPauseTip`（236-291），注意胶囊和提示条的垂直间距。
- 迁移：`GlassActionBar(actions: [IconButton(search), GlassPopupAnchor(targetBuilder: (open) => IconButton(more_vert, onPressed: open))])`。`PopupMenuItem` 已经在用 `onTap`，不用改。

### 3.6 收藏详情（`pages/fav_detail/view.dart`，`FavDetailPage`；`/favDetail`）

- `SliverAppBar.medium` 133，`actions` 172。
- `_actions` 177-327：搜索 179、分享 196、页码顺序 209、排序 226、⋯ 246。分享只在公开收藏夹出现；⋯ 里的项随 `isOwner`/`favState` 变化。
- 5 个动作 + 返回 + 两行标题，360dp 下容易挤。推荐先做 `GlassActionBar`，但必须同时决定：页码顺序和排序是否合并进 ⋯（这会改变交互，属于设计决策）。如果不动交互，只做玻璃胶囊，需在 320/360dp 和大字体下验证不溢出。
- `_selectActions` 329-370 是多选态文字按钮，保持 `RevampMultiSelectBar` 的逻辑，不要玻璃化。

### 3.7 关注（`pages/follow/view.dart`，`FollowPage`；`/follow`）

- `_buildAppBar` 92-149，`actions` 100：新建分组 102、分组排序 110、搜索 120、⋯ 130。
- `isOwner == false` 时 `actions` 为 `null`，只显示别人的关注列表；迁移时保持这个条件。
- `⋯` 只有“黑名单管理”一项；用 `GlassPopupAnchor` 后菜单会从按钮长出来。
- 页面右下是 `RevampFab.extended` 排序切换（72-87），和顶栏动作无关。

### 3.8 会员 / UP 空间（`pages/member/view.dart`，`MemberPage`；`/member`）

- 仓库里没有独立的大会员中心页；“会员”相关入口在 UP 空间 ⋯ 菜单的“大会员经验” (`view.dart:479-489`)，以及 `member_upower_rank` 的“充电”文字按钮 (`member_upower_rank/view.dart:94-104`)。
- UP 空间 `DynamicSliverAppBar.medium` 107，`actions: _actions(theme)` 108；无头图时回退到 `SliverAppBar` 133-135。
- `_actions` 358-594：预约（仅 `reserves` 非空）196-206/359-360、搜索 361-367、⋯ 368-592。预约按钮是 `ReserveButton`，带数量角标，放进胶囊前要确认角标不被裁切。
- 这是 `DynamicSliverAppBar.medium`，展开/收起时 actions 一直在；`GlassActionBar` 的 `refraction` 建议 `false`，避免滚动时背景采样错位。

### 3.9 专栏（`pages/article/view.dart`，`ArticlePage`；`/articlePage`）

- `_buildAppBar` 279-362，`actions` 286：浏览器打开 289、⋯ 294。
- ⋯ 里的分享/复制/分享至消息都只作用于当前文章；`PopupMenuItem` 已用 `onTap`，可原样搬进 `GlassPopupAnchor`。
- 标题是 `Obx` 渐显 (`280-285`)，胶囊不会影响标题逻辑。

### 3.10 直播（`pages/live_room`，`LiveRoomPage`；`/liveRoom`）

- 房间顶栏 `_buildAppBar` 584-735：透明 AppBar，右侧只有一个 ⋯ (658-732)。它在视频画面上，锚点必须是白色裸图标；`GlassIconButton` 的浅色底和 rim 会在视频上显形。菜单本身可以用 `GlassPopupAnchor` 换成玻璃面板。
- 全屏播放器 header `live_room/widgets/header_control.dart:115-296`：返回、置顶、发弹幕、音频、后台、定时、⋯，全是 `ComBtn` 白图标；这是 G3 控件，保持。
- 直播列表 `live/view.dart:93-207` 的筛选行右侧有 3 个 26dp 圆钮（封面/首帧、游戏赛事、全部标签），是页面内动作行，不是 AppBar。若要统一，可做小号 `GlassActionBar`，但会和左侧横滑标签抢宽度，建议先保持。

### 3.11 话题（`pages/dynamics_topic/view.dart`，`DynTopicPage`；`/dynTopic`）

- `_buildAppBar` 173-356，`DynamicSliverAppBar.medium` 180，`actions` 316：分享 317、⋯ 324（收藏/举报）。
- 顶栏下面是话题头图 (`184-199`)，标题/返回是白色；玻璃胶囊的浅色底可能降低对比度。迁移前先确认真实头图上的可读性，必要时只把菜单换成 `GlassPopupAnchor`，锚点保持白色裸图标。

### 3.12 私信（`pages/whisper`，`WhisperPage`；`/whisper`）

- `AppBar` 33，`actions` 35：新增粉丝 36、`outsideItem` 动态按钮组 47-66、⋯ 70。
- `outsideItem` 是服务端下发的列表，可能 0-3 个；当前整段 `Row` 在一个 `Obx` 里。迁移到 `GlassActionBar` 时必须把每个 item 拆成独立 action（每个 action 单独 `LiquidPress`），不能把整个 `Row` 当一个 action。
- `threeDotItems` 也是服务端下发；`PopupMenuItem` 已用 `onTap`，可直接换 `GlassPopupAnchor`。
- 动作数量随登录态/服务端变化，窄屏要准备“收进 ⋯”的兜底。

### 3.13 稍后再看（`pages/later/view.dart`，`LaterPage`；`/later`）

- `_buildAppbar` 157-311：`MultiSelectAppBarWidget` 162，多选时“复制/移动”文字按钮 165-194；普通态 AppBar 197，搜索 198、排序 215、清空 264。
- 排序和清空是文字 + `unfoldMoreHorizontal` 的下拉，不是图标；套进 `GlassActionBar` 会变成一排文字胶囊，和我的页的图标块不一致。建议只把搜索换成 `GlassIconButton`，文字菜单保留。
- 多选态已经由 `RevampMultiSelectBar` 承载，不要重复加玻璃。

### 3.14 音频（`pages/audio/view.dart`，`AudioPage`；`/audio`）

- `AppBar` 101，`actions` 102：片段信息 103（仅 UGC + SponsorBlock + 有片段）、排序 114、定时关闭 130、更多 141。
- “更多”打开播放列表底部 sheet (`_showMore` 204)；排序是 `PopupMenuButton<ListOrder>`，使用 `onSelected`，换成 `GlassPopupAnchor` 时要改成逐项 `onTap`。
- 4 个动作在 360dp 下接近上限；迁移后要在 320dp / 大字体下确认不溢出。若溢出，把“片段信息”留作条件图标，其余收进 ⋯。

### 3.15 搜索（`pages/search/view.dart`，`SearchPage`；`/search`）

- `_buildAppBar` 105-149，`actions` 112：UID 搜索 113（条件）、清空 124、搜索 129。
- 标题是 `TextField` 136-148；右侧胶囊会占宽，窄屏下输入框可能过窄。建议只把“清空/搜索”做成 2 键胶囊，UID 留在胶囊外，或全部保留现状。
- dock 模式 (`search/revamp_view.dart:16-94`) 是底部输入栏，不是顶栏；其中的 UID/清空在输入框内 (160-181)，不要套 `GlassActionBar`。
- `CommonSearchPage` (`common/search/common_search_page.dart:57-89`) 被 download/history/fav/follow/later 五个搜索页共用；改它的搜索键会一次性影响五页，需单独评审。

### 3.16 下载（`pages/download`；`/download`，子页走 `Get.to`）

- 列表 `download/download/view.dart:140-170`：搜索 147、多选 156；2 个动作，适合 `GlassActionBar`。
- 番剧页 `download/page/view.dart:151-172`：只有多选 158；单个 → `GlassIconButton`。
- 详情 `download/detail/view.dart:109-130`：只有多选 116；单个。
- 正在缓存 `download/downloading/view.dart:45-65`：只有多选 51；单个。
- 四页都包在 `MultiSelectAppBarWidget` 里；多选态会换成 `RevampMultiSelectBar`（`common/widgets/appbar/revamp_multi_select_bar.dart:36` 已经是玻璃胶囊），不要在多选态再套 `GlassActionBar`。
- `updateBtn()` 只在多选态的 actions 里出现，不是普通顶栏动作，保持文字按钮。

## 4. 迁移顺序（低风险 → 高风险）

1. **我的 modern 顶栏**：`_headerGroup` 改为 `GlassActionBar(refraction: false)`，删除 `press()`。这是参考实现本身，改完可直接对照截图；无交互变化。
2. **单图标页面**：下载 3 页、直播分区、通讯录、@我的/收到的赞/回复我的、评论详情、设置搜索、投屏。逐个把裸 `IconButton` 换成 `GlassIconButton`，不涉及菜单。
3. **2-3 个图标的 AppBar**：专栏、历史记录、收藏、我的评论、会员/UP 空间、关注、下载列表。统一用 `GlassActionBar`，三点菜单换 `GlassPopupAnchor`；每页只改 actions 列表。
4. **4 个以上 / 需要收起的页面**：音频、收藏详情、搜索。先做玻璃胶囊，再在 320/360dp 和大字体下决定是否把低频动作收进 ⋯；这一步需要设计确认。
5. **动态动作**：私信、私信二级。先把 `Obx` 里的 `Row` 拆成独立 action，再接 `GlassActionBar`；服务端下发数量变化要有兜底。
6. **文字/混合动作行**：稍后再看。只做搜索键，排序/清空保留文字菜单；不要强行统一。
7. **播放器页面**：视频收起顶栏、视频 `HeaderControl`、直播房间/直播列表。最后做，且只做“菜单玻璃化/按压”，不做玻璃币；需要真机看视频画面上的对比度和性能。
8. **面板 morph**：音频“更多”、收藏详情“分享至动态”、视频设置面板。只有把 `showModalBottomSheet` 改成 `PageUtils.showVideoBottomSheet` / `PublishRoute` 时才加 `pendingMorph`；否则不要为了动效改路由。

## 5. 约束与坑

### 5.1 窄屏溢出

- `GlassActionBar` 是 `Row(mainAxisSize: min)`，本身不滚动；AppBar 的 actions 也不会滚动。360dp 下返回键 + 标题 + 5 个 40dp 按钮就会接近上限，320dp 或大字体必溢出。
- `PlayerBar` 在总宽超出时会把 right 整体 `scale`（`player_bar.dart:128-137`），文字会糊、点击区会缩小；不要把 `GlassActionBar` 塞进已经很宽的 `PlayerBar.right`。
- 超过 3 个动作的页面，优先考虑“保留 2-3 个高频 + 其余进 ⋯”，而不是硬塞。

### 5.2 `PlayerBar` 的 transform

- 我的页和视频 `HeaderControl` 都用 `PlayerBar`。它的 `right` 只按内容宽度布局；超出时统一缩放，没有省略号。
- `LiquidPress` 只改绘制、不改布局和命中测试；在 `PlayerBar` 里是安全的，但父级缩放会同时缩放按压的视觉和命中区。
- `GlassActionBar` 放在 `PlayerBar.right` 时保持 `mainAxisSize: min`（组件已如此），不要再包 `Expanded`。

### 5.3 `Obx` / 状态

- `GlassActionBar.actions` 里可以放 `Obx`，但 **一个 `Obx` 只能对应一个 action**。如果 `Obx` 返回 `Row` 里 3 个按钮，`GlassActionBar` 只会给整行包一层 `LiquidPress`，按压时三个按钮一起放大。
- 我的页 `msgBadge`、无痕、主题都是 `Obx`；迁移时保留它们各自的 `Obx`，不要合并。
- 私信/会员的 actions 数量是状态驱动；如果整个 `GlassActionBar` 放在一个 `Obx` 里，动作行会随状态重建，玻璃胶囊也会重建，注意不要在里面再放 `GlobalKey` 锚点。

### 5.4 共享组件

- `msgBadge` (`pages/home/view.dart:459-491`) 被首页 (`221`/`289`)、我的 (`190`)、侧栏 (`main/view.dart:196`/`556`) 使用；它返回的是带 `Badge` 的 `IconButton`，不要在外层再套一个 `IconButton`。
- `CommonSearchPage` (`pages/common/search/common_search_page.dart:57-89`) 被 download/history/fav/follow/later 五个搜索页继承；改它的 actions 等于改五个页面。
- `RevampMultiSelectBar` (`common/widgets/appbar/revamp_multi_select_bar.dart:36`) 已经是 `GlassCapsule` + 文字按钮；历史/收藏/稍后再看/下载以及各搜索子页的多选态都走它，不要重复玻璃化。
- `VideoPopupMenu` (`common/widgets/video_popup_menu.dart:47`) 和 `_moreBtn` (`pages/video/view.dart:1214`) 是 `GlassPopupAnchor` 的现成范例；新页面优先照抄这两个，而不是自己写 `showMenu`。

### 5.5 `GlassPopupAnchor` 的菜单语义

- 它用 `showGeneralDialog` 把 `PopupMenuEntry` 放进普通 `Column`，不是 `PopupMenuRoute`；**`PopupMenuButton.onSelected` 不会触发**。每个 `PopupMenuItem` 必须自己写 `onTap`。
- `PopupMenuItem` 点击后仍会 `Navigator.pop` 关闭对话框；如果 `onTap` 里又写 `Get.back()`，可能多关一层。迁移时删掉多余的 `Get.back()`。
- `initialValue` 不会画出勾选态；排序/页码菜单如果原来靠 `initialValue` 显示当前项，需要在 `child` 里自己加 `Icon(Icons.done)` 或保留 `PopupMenuButton`。
- `GlassPopupAnchor` 的菜单最大高度按屏幕算，内部可滚动；会员页那种长菜单可以直接用。

### 5.6 `PublishRoute.pendingMorph` / `GrowFromRect`

- `pendingMorph` 在 `PublishRoute` 构造函数里取一次就清空 (`publish_route.dart:25-34`)，所以必须在 push 之前设置；push 没发生时要清掉（参考 `comment_sheet.dart:1101-1106`）。
- 只有 `PublishRoute`（包括 `PageUtils.showVideoBottomSheet`）会消费它；普通 `showModalBottomSheet` 不认。
- `GrowFromRect.anchor`：右上角 ⋯ 用 `Alignment.topRight`（默认），底部栏用 `Alignment.bottomRight`；`GrowFromBottom` 用于从底部输入栏长出的回复面板。
- 视频设置面板已经完整实现：`header_control.dart:377-383` 写 rect，`page_utils.dart:498-502` 包 `GrowFromRect`。其他页面要复用这个链路，不要复制坐标计算。

### 5.7 视觉/性能细节

- `GlassActionBar.refraction` 默认 `true`，我的页当前是 `false`；在实色 AppBar 上建议 `false`，只有内容会从下面滚过时才 `true`。
- `GlassIconButton.liquid` 默认 `false`；列表行/AppBar 保持 `false`。每个 `liquid: true` 都是一次 backdrop filter，别给一排按钮逐个开。
- `GlassIconButton` 当前 `tooltip` 参数没有真正进入 widget 树（`glass_icon_button.dart:92-94` 把 `button` 重新赋值，但最终返回的是 `coin`）；需要悬浮提示时，在外部再包一层 `Tooltip`，不要只依赖这个参数。
- `GlassIconButton` 默认 `size: 36`、`tapSize: 40`，比 AppBar 默认 48dp 的 `IconButton` 小；如果顶栏高度/对齐敏感，传 `tapSize: 48`。
- 视频/直播画面上的白色控件不要用 `GlassIconButton`；如果非要用，必须显式传 `color: Colors.white`，但玻璃底和 rim 仍然不适用于 G3 控件。
- `GlassActionBar` 未按 `Revamp.enabled` 或 `UiGlass.clear` 分支；在旧版页面上会直接出现玻璃胶囊。迁移时用页面已有的 `Revamp.enabled` / `_modern` 条件包住，避免旧界面被强行改样。

## 6. 可机械迁移 vs 需要人工/设计评审

### 6.1 可由子代理机械完成（不改交互、不做设计决策）

- **我的 modern 顶栏**：`GlassActionBar(refraction: false)` 替换 `GlassCapsule` + `press()`；保留所有 `IconButton`、`Obx`、`msgBadge`。
- **专栏**：2 个动作，浏览器 + ⋯；`onTap` 已是现成写法。
- **历史记录**：搜索 + ⋯；普通态替换，多选态不动。
- **关注**：4 个动作；条件 `isOwner` 保留。
- **收藏**：3 个 `Obx` 条件动作；逐个保留 `Obx`。
- **我的评论**：导入/导出 2 个动作；debug 键不动。
- **会员 / UP 空间**：预约/搜索/⋯ 3 个动作；保留 `ReserveButton` 和长菜单。
- **下载列表**：搜索/多选 2 个动作；多选态交给 `RevampMultiSelectBar`。
- **单图标页**：下载番剧/详情/正在缓存、直播分区、通讯录、@我的、收到的赞、回复我的、评论详情、设置搜索、投屏、私信二级；换 `GlassIconButton` 或 `GlassPopupAnchor` 即可。
- **共享搜索页的搜索键**：`CommonSearchPage` 的单个搜索图标换 `GlassIconButton`；但这是一次改五页，需作为一个独立提交验证。

### 6.2 需要人工/设计评审

- **收藏详情**：5 个动作是否收进 ⋯、页码/排序是否合并，属于交互决策；还要验证 `SliverAppBar.medium` 展开/收起时的玻璃位置。
- **音频**：4 个动作 + 条件片段按钮，窄屏是否溢出、是否把片段信息收进 ⋯。
- **搜索**：`TextField` 和右侧胶囊的宽度分配；是否只做 2 键。
- **私信**：`outsideItem` / `threeDotItems` 服务端驱动，动作数量不固定；需要兜底和拆 `Obx`。
- **稍后再看**：排序/清空是文字下拉，是否保持文字胶囊、还是改成图标，属于设计选择。
- **首页**：搜索主导的 legacy 顶栏是否要玻璃化；dock 模式已经是对的，不要为了统一而改。
- **话题**：头图上的玻璃对比度；可能需要只换菜单、不换锚点。
- **视频 / 直播**：播放器画面上的 G3 控件；只做菜单玻璃化和按压，不做玻璃币，需真机看对比度/性能。
- **动态 legacy**：34dp 填充圆是否换成 36dp `GlassIconButton`，是视觉决策。
- **`CommonSearchPage` 整行**：如果要把搜索键 + `extraActions` 做成胶囊，会影响五个搜索页，属于跨页设计。
