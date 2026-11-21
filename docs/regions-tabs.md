# 顶部标签与筛选条清单（regions-tabs）

> 只读审计，未改 `lib/`。行号取自当前工作区（含未提交改动），以 `file:line` 为准。
> 目标：把散落的 `TabBar`、筛选条、分段控件统一成「玻璃胶囊 + 会跟手移动的药丸」，并支持手指在标签上横向拖动切换。

## 结论先行

- **作为顶部标签条，真正用了玻璃胶囊的只有三处**：首页 `CenteredGlassTabs`、动态 `CenteredGlassTabs`、UP 空间 `GlassTabBar`。前两者已经有 `LiquidPress`，`GlassTabBar` 没有。
- **其余 30 多处都是 Material `TabBar`（含 `DynTabBar` 这类子类）**。`Revamp.enabled` 时由全局 `RevampTheme` 的 `PillTabIndicator` 统一成药丸（`lib/common/revamp_theme.dart:55`、`:173`），但**没有胶囊、没有 `LiquidPress`、标签不能拖动**；`Revamp.enabled` 关闭时多数退回默认下划线。
- **`pages/fav_detail` 没有顶部标签**。用户说的「视频/追番/追剧/专栏/笔记/话题/课堂」在 `pages/fav/view.dart`；`fav_detail` 是某个收藏夹的详情，只有 `SliverAppBar.medium` 和网格。
- **`subscription`（我的订阅）、`setting`、`audio`、`download`、`article`（专栏/文章）没有顶部标签**，不要为了统一而硬加。
- `lib/` 中没有命中 `CupertinoSlidingSegmentedControl`、`FilterChip`、`ChoiceChip`、`SegmentedButton`。筛选主要用 `SearchText` 和 `ToggleButtons`。
- 页面级标签全部由 **`TabController`** 驱动，没有 `PageController` 驱动的页签；`PageController` 只出现在 `member` 的资料卡头部、`main` 的底栏和直播间的页面切换。
- 迁移不需要重写页面：先把 `CenteredGlassTabs` 里的「测量 + 药丸 + 标签 + 滚动」抽成 `GlassTabStrip`，给 `CenteredGlassTabs` / `GlassTabBar` 做薄包装，再逐页替换 `TabBar`。

## 判定口径

| 类型 | 定义 | 本轮处理 |
|---|---|---|
| 页面级顶部标签 | 一个 `TabController` 对应一组页面，通常在 `AppBar` 下、`body` 顶部或浮动 `PreferredSize` 里 | 换玻璃胶囊，加拖动 |
| 页面内次级标签 | 在外层页签内部，再分一层页面；如收藏的追番/笔记、UP 投稿 | 用无胶囊的 `GlassTabStrip`，避免「胶囊套胶囊」 |
| 筛选条 | 不切页面，只改排序/分区/标签并重新请求 | 保留现有 `SearchText` / `ToggleButtons`，最多加 `LiquidPress` |
| 面板内标签 | 底部面板、播放器面板、直播间面板 | 不迁，保持 Material，避免玻璃叠玻璃 |

路由索引（只列命名路由；直播分区/详情、PGC 索引等是 `Get.to` 直接 push）：首页/动态在 `/` 的 `MainApp` tab，另有 `/home`、`/dynamics`；`/member`、`/history`、`/fav`、`/favDetail`、`/later`、`/search`、`/searchResult`、`/dynTopic`、`/follow`、`/upowerRank`、`/bubble`、`/danmakuBlock`、`/liveDmBlockPage`、`/subscription`、`/setting`、`/audio`、`/download`、`/articlePage`。

## 表 1：页面级顶部标签

| 页面 | file:line | 位置 | 控件 | 标签 / 数量 | 滚动 / 铺满 | 控制器 | 当前外观 | 建议 |
|---|---|---|---|---|---|---|---|---|
| 首页 | `lib/pages/home/view.dart:193`；回退 `:62` | 浮动 AppBar / 顶部 Column | `CenteredGlassTabs`；回退 `TabBar` | `HomeTabType`：直播/推荐/热门/分区/番剧/影视；用户可排序，1–6 个 | 自适应；放不下滚动；回退 `isScrollable` + `center` | `HomeController.tabController`（`home/controller.dart:80`） | 玻璃胶囊 + 药丸，药丸跟页面滑动；有 `LiquidPress`；回退是普通 `TabBar` | 保留胶囊，把拖动能力放进共享条；不要再复制一套 |
| 动态 | `lib/pages/dynamics/view.dart:76`；回退 `:269` | AppBar bottom（浮动 PreferredSize） | `CenteredGlassTabs`；回退 `TabBar` | 全部/投稿/番剧/专栏/UP，5 个 | 自适应；回退 `isScrollable` + `start` | `DynamicsController.tabController`（`dynamics/controller.dart:51`） | 与首页同款玻璃胶囊 + 药丸；有 `LiquidPress` | 同首页；回退分支可保留到 `Revamp` 全量切换后再删 |
| UP 空间 / 会员 | `lib/pages/member/view.dart:156`；回退 `:170` | body 顶部（嵌套滚动头下） | `GlassTabBar`；回退 `TabBar` | 服务端 `tab2`：主页/动态/投稿/收藏/追番/课堂/小店；默认 4 个，1–8 个 | 胶囊内 `TabBar` 可滚、左对齐；回退铺满 | `MemberController.tabController`（`member/controller.dart:152`、`:180`） | 玻璃胶囊 + 内嵌 `TabBar` 药丸；**没有** `LiquidPress`；`refraction:false` | 用 `GlassTabStrip(capsule:true, centered:false)` 替换 `GlassTabBar`，加拖动；保留 `onTapTab` 回顶 |
| 历史记录 | `lib/pages/history/view.dart:113` | body 顶部（AppBar 下） | `TabBar` | 全部 + 服务端 `tabs`；常见 视频/直播/专栏，3–4 个 | 铺满（未开 `isScrollable`） | `HistoryController.tabController`（`history/controller.dart:75`，数据到达后创建） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 直接换 `CenteredGlassTabs` / `GlassTabStrip`；注意控制器可能为 null |
| 我的收藏 | `lib/pages/fav/view.dart:133` | body 顶部（AppBar 下） | `TabBar` | 视频/追番/追剧/专栏/笔记/话题/课堂，7 个 | 滚动、左对齐 | `FavPage` 本地 `TabController`（`fav/view.dart:37`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 换 `GlassTabStrip`；7 个标签建议 `centered:false` 或自动居中 |
| 稍后再看 | `lib/pages/later/view.dart:117` | body 顶部（ViewSafeArea 内） | `TabBar` | 全部/未看完，2 个；标签带 `(数量)` | 铺满 | `LaterPage` 本地 `TabController`（`later/view.dart:49`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 最稳的机械迁移样板；注意 `(数量)` 会变宽，需重新测量 |
| 搜索结果 | `lib/pages/search_result/view.dart:107` | body 顶部（AppBar 下） | `TabBar` | 综合/番剧/影视/直播间/用户/专栏，6 个；标签带计数 | 滚动、左对齐 | `SearchResultPage` 本地 `TabController`（`search_result/view.dart:40`） | Revamp 下主题药丸；非 Revamp 显式药丸；跟页面滑动 | 换 `GlassTabStrip`；计数用 `Obx` 包住标签，宽度会变 |
| 直播分区 | `lib/pages/live_area/view.dart:86` | body 顶部（AppBar 下） | `TabBar` | 服务端一级分区名，常见 10+ 个 | 滚动、左对齐 | `LiveAreaController.tabController`（`live_area/controller.dart:42`，接口返回后创建） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 换 `GlassTabStrip`；只在一级分区有数据时建条 |
| 直播分区详情 | `lib/pages/live_area_detail/view.dart:83` | body 顶部（AppBar 下 Row） | `TabBar` + 右侧两个 `iconButton` | 服务端二级分区名，常见 5–12 个 | 滚动、左对齐 | `LiveAreaDetailController.tabController`（`live_area_detail/controller.dart:32`，初始定位当前分区） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 把 `TabBar` 换成 `Expanded(child: GlassTabStrip(...))`，右侧按钮不动 |
| 番剧/影视时间表 | `lib/pages/pgc/view.dart:112` | sliver 内（随内容滚动） | `TabBar` | 7 天：`MM-DD 周X`，今天带「今天」 | 滚动、左对齐 | 局部 `DefaultTabController`（`pgc/view.dart:98`） | 显式药丸（非 Revamp 也药丸）；**不跟页面滑动**（`NeverScrollableScrollPhysics`） | **保留**。日期条不是页面导航，拖动会和下方横向剧集列表抢手势；最多加 `LiquidPress` |
| 番剧/影视索引入口 | `lib/pages/pgc/view.dart:273` | 临时页 body 顶部 | `TabBar` | 全部/电影/电视剧/纪录片/综艺，5 个 | 铺满 | 局部 `DefaultTabController`（`pgc/view.dart:266`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 可换 `GlassTabStrip`，但这是临时 push 的索引页，优先级低 |
| 话题页 | `lib/pages/dynamics_topic/view.dart:91` | SliverPinnedHeader（吸顶） | `ToggleButtons` | 服务端 `allSortBy`，常见 默认/最新/最热，2–4 个 | 固定宽度、左对齐 | 无 `TabController`；`DynTopicController.sortBy`（`dynamics_topic/controller.dart:19`） | 选中填充药丸的分段控件；不跟页面滑动；在 `SliverPinnedHeader` 里 | **保留**，或换 `GlassTabStrip(capsule:false, drag:none)`；拖动只改排序会频繁请求，不建议跟手 |
| 关注 | `lib/pages/follow/view.dart:165` | body 顶部（AppBar 下） | `TabBar` | 全部关注 + 服务端分组；标签带 `(数量)`；自定义分组带菜单图标 | 滚动、左对齐 | `FollowController.tabController`（`follow/controller.dart:82`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 可换 `GlassTabStrip`，但必须支持标签 `onLongPress`（编辑/删除分组）和右侧小图标 |
| 会员投稿 | `lib/pages/member_contribute/view.dart:61` | UP 空间 body 内（嵌套） | `TabBar` | 服务端 `contribute.items`（视频/合集/…）+「全部合集/列表」，2–4 个 | 滚动、左对齐 | `MemberContributeCtr.tabController`（`member_contribute/controller.dart:37`） | Revamp 下主题药丸；非 Revamp 显式药丸；**不跟页面滑动**（`NeverScrollableScrollPhysics`） | 用 `GlassTabStrip(capsule:false)` 即可；它已在 UP 空间的大胶囊下面，别套第二层胶囊 |
| 动态详情 | `lib/pages/dynamics_detail/view.dart:294` | body 顶部（详情头下） | `DynTabBar`（`TabBar` 子类） | 转发/评论/赞，3 个；带计数 | 铺满 | `CommonDynPageMultiState.tabController`（`common_dyn_page.dart:93`） | 全宽 `DynTabBar`，修了最后一个 tab 的 indicator 偏移；**不跟页面滑动**（`NeverScrollableScrollPhysics`） | 可换 `GlassTabStrip`，顺带去掉 `DynTabBar` 的 workaround；计数用 `Obx` |
| 番剧点评 | `lib/pages/pgc_review/view.dart:55` | body 顶部（SimpleScaffold） | `TabBar` | 长评/短评，2 个 | 滚动、左对齐 | `PgcReviewPage` 本地 `TabController`（`pgc_review/view.dart:35`） | Revamp 下主题药丸；非 Revamp 显式药丸；跟页面滑动 | 直接换 `CenteredGlassTabs` / `GlassTabStrip` |
| 会员充电榜 | `lib/pages/member_upower_rank/view.dart:120` | body 顶部（AppBar 下） | `TabBar` | 服务端 `levelInfo` 档位名 + `(人数)`，1–N 个 | 滚动、左对齐 | 局部 `DefaultTabController`（`:114`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 可换 `GlassTabStrip`；先把 `DefaultTabController` 改成显式 `TabController` 更好迁移 |
| 小站（bubble） | `lib/pages/bubble/view.dart:153` | body 顶部（AppBar 下） | `TabBar` | 服务端 `categoryList` 小站分类，N 个 | 滚动、左对齐 | `BubbleController.tabController`（`bubble/controller.dart:46`，数据到达后创建） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 可换 `GlassTabStrip`；注意控制器异步创建 |
| 黑名单管理 | `lib/pages/blacklist/view.dart:77` | body 顶部（AppBar 下） | `TabBar` | 本地/在线，2 个 | 铺满 | `BlackListPage` 本地 `TabController`（`blacklist/view.dart:53`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 机械迁移 |
| 通讯录 | `lib/pages/contact/view.dart:68` | body 顶部（AppBar 下） | `TabBar` | 我的关注/我的粉丝，2 个 | 铺满 | `ContactPage` 本地 `TabController`（`contact/view.dart:28`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 机械迁移 |
| 弹幕屏蔽 | `lib/pages/danmaku_block/view.dart:58` | body 顶部（AppBar 下） | `TabBar` | 关键词/正则/用户，3 个；带计数 | 铺满 | `DanmakuBlockController.tabController`（`danmaku_block/controller.dart:25`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 机械迁移；计数会变，`Obx` 包标签 |
| 直播弹幕屏蔽 | `lib/pages/live_dm_block/view.dart:33` | body 顶部（AppBar 下） | `TabBar` | 关键词/用户，2 个 | 铺满 | `LiveDmBlockController.tabController`（`live_dm_block/controller.dart:20`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 机械迁移 |
| 会员搜索 | `lib/pages/member_search/view.dart:68` | body 顶部（AppBar 下） | `TabBar` | 视频/动态，2 个；带计数 | 铺满 | `MemberSearchController.tabController`（`member_search/controller.dart:28`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 机械迁移 |
| 直播搜索 | `lib/pages/live_search/view.dart:65` | body 顶部（AppBar 下） | `TabBar` | 正在直播/主播，2 个；带计数 | 铺满 | `LiveSearchController.tabController`（`live_search/controller.dart:34`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 机械迁移 |
| 评论搜索 | `lib/pages/video/reply_search_item/view.dart:71` | body 顶部（AppBar 下） | `TabBar` | 视频/专栏，2 个 | 铺满 | `ReplySearchItemController.tabController`（`reply_search_item/controller.dart:40`） | Revamp 下主题药丸；否则下划线；跟页面滑动 | 机械迁移，优先级低 |
| 视频详情 | `lib/pages/video/view.dart:1404` | 播放器下方控制条（body 内） | `TabBar`（`buildTabBar`） | 简介/评论/播放列表；评论可能隐藏，1–3 个；评论带计数 | 铺满，`maxWidth: 96 * count` | `VideoDetailController.tabCtr`（`video/controller.dart:400`，长度变化时在 `view.dart:1391` 重建） | 自定义 `TabBar`，播放器下方一行，和「发弹幕」按钮同排；不跟页面滑动 | **保留**。这是播放器控制条的一部分，不要做成胶囊；最多给标签加 `LiquidPress` |

## 表 2：页面内次级标签与筛选条

| 页面 | file:line | 位置 | 控件 | 标签 / 数量 | 滚动 / 铺满 | 控制器 | 当前外观 | 建议 |
|---|---|---|---|---|---|---|---|---|
| 收藏-追番/追剧 | `lib/pages/fav/pgc/view.dart:50` | 收藏页 body 内（嵌套） | `TabBar` | 想看/在看/看过，3 个 | 滚动、左对齐 | `FavPgcPage` 本地 `TabController`（`:24`，`initialIndex:1`） | Revamp 下主题药丸；非 Revamp 显式药丸；**不跟页面滑动** | `GlassTabStrip(capsule:false, drag:scrub)`；它已在「我的收藏」的大页签里，别套胶囊 |
| 收藏-笔记 | `lib/pages/fav/note/view.dart:47` | 收藏页 body 内（嵌套） | `TabBar` | 未发布笔记/公开笔记，2 个 | 滚动、左对齐 | `FavNotePage` 本地 `TabController`（`:22`） | 同上；**不跟页面滑动** | 同上 |
| PGC 索引筛选 | `lib/pages/pgc_index/view.dart:138`、`:178` | sliver 内（条件区顶部） | `SearchText` + `SelfSizedHorizontalList` | 排序 + 多个筛选维度，每个维度 5–10 项 | 每行横向滚动 | `PgcIndexController.indexParams`（无 `TabController`） | 选中淡色胶囊；不跟页面滑动；在 sliver 里 | **保留**。这是筛选，不是页签；最多加 `LiquidPress` |
| 搜索结果-视频排序 | `lib/pages/search_panel/video/view.dart:59`、`:72` | SliverFloatingHeader（吸顶） | `SearchText` + 横向 `SingleChildScrollView` + `Wrap` | `ArchiveFilterType.values`：默认排序/播放多/新发布/弹幕多/收藏多/评论多，6 项 | 横向滚动 | `SearchVideoController.selectedType`（无 `TabController`） | 选中项在 Revamp 下是 `surfaceContainerHighest` 药丸；不跟页面滑动 | **保留**；不要做成页签，排序会重新请求 |
| UP 投稿标签 | `lib/pages/member_video_web/archive/view.dart:55` | SliverPinnedHeader（吸顶） | `SearchText` + `SelfSizedHorizontalList` | 服务端视频标签，N 个 | 横向滚动；`SliverPinnedHeader` | `MemberVideoWebCtr.tid / specialType` | 选中淡色胶囊；不跟页面滑动 | **保留**；如果要做玻璃，只包外层，不要逐标签做胶囊 |
| 直播首页分区入口 | `lib/pages/live/view.dart:114`、`:132` | 信息流 sliver 顶部 | `SearchText` + 横向 `ListView` | 「推荐」+ `areaEntranceV3.list`，常见 8–12 个 | 横向滚动；在信息流顶部 | `LiveController.areaIndex` 和 `onSelectArea` | 选中 `secondaryContainer` 药丸；不跟页面滑动 | **保留**；这是筛选信息流，不是页面页签 |
| 直播分区-常用标签 | `lib/pages/live_area/view.dart:321` | body 顶部（AppBar 下） | `SearchText` 的 `Wrap` | 我的常用标签，N 个 | 自动换行 | `LiveAreaController.favState` | 淡色胶囊；不跟页面滑动 | **保留**，最多加 `LiquidPress` |

## 表 3：明确没有顶部标签的页面

| 页面 | file:line | 实际结构 | 结论 |
|---|---|---|---|
| 收藏夹详情 | `lib/pages/fav_detail/view.dart:102`、`:132` | `CustomScrollView` + `SliverAppBar.medium` + 网格；没有 `TabBar` | **没有标签，不要迁移**。用户记的 7 个标签在 `pages/fav` |
| 我的订阅 | `lib/pages/subscription/view.dart:25`、`:27` | `SimpleScaffold` + 单个 `CustomScrollView` 网格 | **没有标签**；如要分类，先产品定义 |
| 设置 | `lib/pages/setting/view.dart:344`、`:204` | 分组 `CustomScrollView` | **没有标签**；不要加 |
| 音频 | `lib/pages/audio/view.dart:100` | 播放器页面；播放列表在底部面板里用 `ListOrder` 弹窗 | **没有顶部标签** |
| 下载 | `lib/pages/download/download/view.dart:173` | 单个 `CustomScrollView`：正在缓存 / 已缓存视频两段 | **没有标签**；两段是滚动内容，不是页签 |
| 专栏/文章 | `lib/pages/article/view.dart:78` | 单个 `SimpleScaffold` + 长文滚动；`:547` 的 `PageView` 是图片浏览 | **没有标签** |
| 搜索首页 | `lib/pages/search/view.dart:374` | 搜索框 + 历史/热搜，`SearchText` 推荐词 | **没有标签**；结果页才有 |

## 表 4：面板 / 非顶部 TabBar（不迁）

| 位置 | file:line | 内容 | 处理 |
|---|---|---|---|
| 剧集面板 | `lib/pages/episode_panel/view.dart:256` | 季 / 篇章 tabs（`widget.list` 的标题） | 保留 Material；面板里不做玻璃胶囊 |
| 表情面板 | `lib/pages/emote/view.dart:159` | 表情包分类 tabs | 保留 |
| 直播表情面板 | `lib/pages/live_emote/view.dart:136` | 直播表情包分类 | 保留 |
| 直播间贡献榜 | `lib/pages/live_room/contribution_rank/view.dart:58` | 在线榜/日榜/周榜/月榜 | 保留；面板内 |
| 登录 | `lib/pages/login/view.dart:537`、`:579` | 登录方式 tabs | 保留 |
| 排行榜 | `lib/pages/rank/view.dart:52` | `VerticalTabBar` 左侧竖排 | 保留；不是顶部 |
| PGC 简介面板 | `lib/pages/video/introduction/pgc/widgets/intro_detail.dart:60` | 详情/点评 | 保留；播放页内面板 |

## 逐页要点

### 首页与动态：只加拖动，不换皮

两页已经是目标外观：`CenteredGlassTabs` 内部用 `TextPainter` 量宽、`AnimatedBuilder` 监听 `controller.animation`、药丸按小数 index 插值、放不下时 `SingleChildScrollView` 滚动并把选中项居中（`centered_glass_tabs.dart:91-115`、`:261-270`）。它们已经包了 `LiquidPress(maxGrowth: 8, pullPastEdges: true)`（`:285`）。

注意它的入参是 `TabController`，药丸读的是 `controller.animation`，不是 `PageController`；当前页面级页签没有 `PageController` 驱动的情况。以后若出现，给 `GlassTabStrip` 加一个 `positionOf` / `onSelect` 适配层即可，不要把 `PageController` 塞进现有构造函数。

迁移只需要：

1. 把 `_row`、测量、滚动、点击、药丸绘制抽到 `GlassTabStrip`。
2. `CenteredGlassTabs` 变成 `GlassTabStrip(capsule:true, ...)` 的薄包装，公开 API 不变。
3. 在 `GlassTabStrip` 里加水平拖动。首页/动态不需要改 `TabBarView` 或 `HomeController` / `DynamicsController`。

注意首页有两条分支：`dockSearch == true` 用 `CenteredGlassTabs`（`:193`），否则用普通 `TabBar`（`:62`）。不要只改一条；如果短期不想动回退分支，至少保证两边的标签顺序、`onTap` 回顶行为一致。

### UP 空间：`GlassTabBar` 是「胶囊里的 TabBar」，不是共享条

`member/view.dart:156` 只在 `Revamp.enabled` 且 `tab2.length > 1` 时用 `GlassTabBar`，否则用 `TabBar`（`:170`）。`GlassTabBar` 的特点：

- `GlassCapsule` + 内嵌 `TabBar`（`glass_tab_bar.dart:45-85`）；
- `isScrollable: true`、`TabAlignment.start`，左对齐，不居中；
- `PillTabIndicator(insets: EdgeInsets.all(4))`，和首页 `CenteredGlassTabs` 的 8dp 内缩不一致（审计文档第 11 条已提过）；
- 没有 `LiquidPress`，标签不能拖。

建议用 `GlassTabStrip(capsule:true, centered:false, refraction:false, drag:scrub)` 替换。`onTapTab`（`member/controller.dart:287`）负责回顶，保留。`tab2` 可能在刷新后增删（`member/controller.dart:152`、`:180` 会重建 `TabController`），共享条必须在 `didUpdateWidget` 里处理「控制器换了 / 长度变了」。

### 历史：控制器是异步创建的，先判空

`HistoryController.tabController` 在 `customHandleResponse` 里、服务端返回 tab 之后才创建（`history/controller.dart:71-76`），长度是 `tab.length + 1`（「全部」）。`view.dart:104-132` 用 `Obx` 包住，`tabs.isEmpty` 时直接返回单页。

迁移时不要写成 `controller: _historyController.tabController!`；在 `tabs.isEmpty` 分支继续用单页，只有非空才建条。`TabBar` 当前是铺满、不滚动；换成胶囊后如果标签多，`CenteredGlassTabs` 会自动滚动并居中，这是可接受的视觉变化。

### 我的收藏：7 个标签在 `pages/fav`，不在 `fav_detail`

`FavPage` 用本地 `TabController(length: FavTabType.values.length)`（`fav/view.dart:37`），`FavTabType` 定义 7 项（`models/common/fav_type.dart:9-17`）。`TabBar` 是 `isScrollable: true` + `TabAlignment.start`（`:133-139`），`TabBarView` 用 `tabBarView()`（`:162`），所以跟页面滑动。

`fav_detail` 是收藏夹详情页，只有 `SliverAppBar.medium` 和网格，没有标签。不要在那里找 7 个标签。

收藏内部的「追番/追剧」和「笔记」各有一层 `TabBar`（表 2），且都是 `NeverScrollableScrollPhysics`。它们适合无胶囊的 `GlassTabStrip(capsule:false)`：外层已经是大胶囊，内层再套胶囊会显得很重。

### 稍后再看：最适合做第一个机械迁移

`LaterPage` 只有 2 个标签（`LaterViewType`：全部、未看完，`models/common/later_view_type.dart:4-9`），控制器在 `initState` 里同步创建（`later/view.dart:49`），`TabBarView` 用 `tabBarView()`（`:136`）。标签上带 `(数量)`，数量来自 `_baseCtr.counts`，是 `Obx` 可变的。

先拿它验证三件事：标签宽度变化后药丸是否重新测量、切页后药丸是否跟手、`LiquidPress` 是否和多选模式下的 `NeverScrollableScrollPhysics` 共存。通过后，历史/收藏/搜索结果可以照抄。

### 搜索：6 个标签，没有「视频」

`SearchType.actives` 是 综合/番剧/影视/直播间/用户/专栏（`models/common/search/search_type.dart:35-42`），没有 `video`。不要按「综合/视频/用户/…」的旧印象写迁移。

`SearchResultPage` 的 `TabBar` 是 `isScrollable: true`、`TabAlignment.start`，计数格式是 `label + 空格 + count`，超过 99 显示 `99+`（`search_result/view.dart:112-124`）。这些计数在 `Obx` 里，标签列表会重建；`GlassTabStrip` 每次 build 重新量宽即可。

### 直播分区与分区详情：动态数量 + 右侧按钮

`LiveAreaPage` 的一级分区在 `customHandleResponse` 里创建 `TabController(length: response.length)`（`live_area/controller.dart:38-44`），`TabBar` 在 `body` 的 Column 顶部（`live_area/view.dart:86`）。标签数量可能十几，必须滚动。

`LiveAreaDetailPage` 的二级分区在 `getDataList` 里创建，`initialIndex` 定位到当前分区（`live_area_detail/controller.dart:31-36`）。`TabBar` 和两个 `iconButton` 在同一个 `Row` 里（`live_area_detail/view.dart:80-125`）。迁移时只替换 `Expanded` 里的 `TabBar`，右侧按钮和 `Divider` 不动。

### 番剧/影视：时间表不是页签，别拖

`pgc/view.dart:98-202` 是 7 天时间表：`DefaultTabController`、`TabBar` 在 `Row` 里、`TabBarView` 用 `NeverScrollableScrollPhysics`，每个页面里还有横向 `ListView` 的剧集卡片。这里横向手势已经属于剧集列表，标签拖动会抢手势；保留 `TabBar`，最多给标签加按压缩放。

`pgc/view.dart:266-303` 的索引入口是另一个临时页面，5 个标签、铺满，可以换胶囊，但优先级低于主页面。

### 话题页：分段控件，不是页签

`dynamics_topic/view.dart:81-126` 用 `SliverPinnedHeader` + `ToggleButtons`，选中项填充 `secondaryContainer`。它由 `allSortBy` 驱动（`dynamics_topic/controller.dart:54-55`、`:92`），切换会重新请求，不会切页面。

保留现状最稳。如果一定要统一外观，用 `GlassTabStrip(capsule:false, drag:none)` 的「索引模式」，只把 `onSelected` 映射到 `onSort`；不要做跟手拖动，否则会连续触发请求。

### 关注：唯一需要长按菜单的页签

`follow/view.dart:169-199` 的每个标签可能是 `GestureDetector`，长按/右键打开分组编辑菜单；标签还带 `(数量)` 和一个 `Icons.menu` 小图标。这是唯一不能直接换成 `CenteredGlassTabs` 的页面级标签。

共享条需要支持 `GlassTabItem.trailing` 和 `onLongPress` / `onSecondaryTap`，并且测量宽度时把 `trailing` 的固定 18dp 算进去。否则迁移后长按编辑会丢。

### 动态详情：可以顺手删掉 `DynTabBar` 的临时补丁

`dynamics_detail/view.dart:291-341` 用 `DynTabBar`（`common/widgets/flutter/dyn_tab_bar.dart`）解决最后一个 tab 的 indicator 偏移，并固定全宽。`TabBarView` 是 `NeverScrollableScrollPhysics`（`:360-365`），标签本身不跟页面滑。

换成 `GlassTabStrip` 后，药丸位置由共享条自己算，不再需要 `_correctTabIndex` 这类 workaround；计数仍然用 `Obx` 包标签。

### 视频详情：不要胶囊

`video/view.dart:1376-1505` 的 `buildTabBar` 是播放器下方控制条的一部分：`SizedBox(height:45)`、`Row`、`maxWidth: 96 * tabs.length`，右侧还有「发弹幕」和弹幕开关。标签数量会随「简介/评论/播放列表」变化，`TabController` 在长度不一致时重建（`:1389-1398`）。

这里保持 `TabBar`。如果要做按压缩放，优先包整条或只包 `Tab` 的 child，并先验证命中区域；不要加胶囊或整条拖动，否则会和播放器手势、横向简介卡片冲突。

## 共享 `GlassTabStrip` API

### 目标

- 一个组件同时覆盖三种用法：
  1. `TabController` + 页面：首页、动态、历史、收藏、搜索、直播分区……；
  2. 纯索引 + 回调：话题排序、PGC 索引筛选、直播首页分区；
  3. 只读标签 + 自定义布局：会员页、直播分区详情（右侧有按钮）。
- `CenteredGlassTabs` 和 `GlassTabBar` 都退化成薄包装，行为不变。
- 拖动、点击、页面滑动三者最终都落到同一个 index。

### 建议文件

`lib/common/widgets/liquid_glass/glass_tab_strip.dart`

### API 草案

```dart
enum GlassTabDrag {
  /// 不接管横向手势；放不下时由内部滚动视图自己滚。
  none,

  /// 拖动时只移动药丸和高亮，松手才提交 index。
  scrub,

  /// 每跨过一个标签就提交一次，页面会跟着手指切换。
  live,
}

class GlassTabItem {
  const GlassTabItem(
    this.label, {
    this.trailing,
    this.onLongPress,
    this.onSecondaryTap,
    this.enabled = true,
  });

  final String label;

  /// 固定宽度的小图标，例如关注分组的菜单图标；测量时按 18dp 计入。
  final Widget? trailing;

  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool enabled;
}

class GlassTabStrip extends StatefulWidget {
  /// 控制器模式：药丸跟 [controller.animation] 走，页面滑动也会更新。
  const GlassTabStrip({
    super.key,
    required this.items,
    required this.controller,
    this.onTap,
    this.onSelected,
    this.drag = GlassTabDrag.scrub,
    this.centered = true,
    this.labelPadding = 14,
    this.height = 44,
    this.capsule = false,
    this.refraction = false,
    this.padding = EdgeInsets.zero,
    this.onDragStateChanged,
  }) : index = null,
       assert(controller != null);

  /// 索引模式：没有 TabController 的筛选条、分段控件。
  const GlassTabStrip.indexed({
    super.key,
    required this.items,
    required this.index,
    this.onSelected,
    this.drag = GlassTabDrag.none,
    this.centered = false,
    this.labelPadding = 14,
    this.height = 44,
    this.capsule = false,
    this.refraction = false,
    this.padding = EdgeInsets.zero,
    this.onDragStateChanged,
  }) : controller = null,
       onTap = null,
       assert(index != null);

  final List<GlassTabItem> items;
  final TabController? controller;
  final int? index;

  /// 只关心点按；拖动提交不会触发。和 [onSelected] 只传一个。
  final ValueChanged<int>? onTap;

  /// 点按和拖动提交都会触发；页面级迁移通常只传这个。
  final ValueChanged<int>? onSelected;
  final GlassTabDrag drag;
  final bool centered;
  final double labelPadding;
  final double height;

  /// 是否自带 GlassCapsule + LiquidPress；页面级用 true，嵌套/筛选用 false。
  final bool capsule;
  final bool refraction;
  final EdgeInsetsGeometry padding;

  /// 拖动开始/结束，调用方可据此暂停列表滚动或隐藏底栏。
  final ValueChanged<bool>? onDragStateChanged;
}
```

### 内部状态

```dart
class _GlassTabStripState extends State<GlassTabStrip>
    with TickerProviderStateMixin {
  final _scroll = ScrollController();

  /// 每个标签的宽度（label + 左右 padding + trailing）
  List<double> _widths = const [];

  /// 每个标签的中心点，用于把手指 x 映射成小数 index
  List<double> _centers = const [];

  double? _dragPosition;   // 拖动中的小数 index
  double _lastLocalX = 0;
  int? _lastTickIndex;
  Ticker? _edgeTicker;

  bool get _dragging => _dragPosition != null;

  double get _position {
    if (_dragPosition case final p?) return p;
    if (widget.controller case final c?) {
      return c.animation?.value ?? c.index.toDouble();
    }
    return widget.index!.toDouble();
  }
}
```

关键点：

- `TextPainter` 只量 `label`，`trailing != null` 时加 `18 + 4`；`label` 里已经包含 `(数量)` 的页面（稍后再看、关注、搜索、会员搜索、直播搜索、动态详情）直接量整串即可。
- `controller.animation` 用 `AnimatedBuilder` 监听，不要每帧 `setState`。
- `didUpdateWidget` 处理三种变化：`controller` 换了、`items.length` 变了、`items[i].label` 变了。后两种要清空 `_widths` 并在下一帧重新居中。
- `dispose` 里移除 controller listener、停掉 `_edgeTicker`、`_scroll.dispose()`。

### 点击与拖动

```dart
void _select(int i) {
  feedBack();
  // onTap 只关心「点」；onSelected 在点选和拖动提交时都会触发。
  widget.onTap?.call(i);
  widget.onSelected?.call(i);
  if (widget.controller case final c?) {
    if (c.index != i) c.animateTo(i);
  }
}

double _positionAt(double localX) {
  final x = localX + _scroll.offset;
  if (_centers.isEmpty) return 0;
  if (x <= _centers.first) return 0;
  if (x >= _centers.last) return (_centers.length - 1).toDouble();
  for (var i = 0; i < _centers.length - 1; i++) {
    final a = _centers[i];
    final b = _centers[i + 1];
    if (x >= a && x <= b) {
      return i + (x - a) / (b - a);
    }
  }
  return (_centers.length - 1).toDouble();
}

void _onDragStart(DragStartDetails d) {
  _dragPosition = _position;
  _lastLocalX = d.localPosition.dx;
  widget.onDragStateChanged?.call(true);
}

void _onDragUpdate(DragUpdateDetails d) {
  _lastLocalX = d.localPosition.dx;
  setState(() {
    _dragPosition = _positionAt(_lastLocalX);
  });
  final nearest = _dragPosition!.round();
  if (nearest != _lastTickIndex) {
    _lastTickIndex = nearest;
    HapticFeedback.selectionClick();
  }
  _autoScrollIfNeeded();
}

void _onDragEnd(DragEndDetails d) {
  final target = _dragPosition!.round().clamp(0, widget.items.length - 1);
  _dragPosition = null;
  _stopEdgeScroll();
  widget.onDragStateChanged?.call(false);
  widget.onSelected?.call(target);
  if (widget.controller case final c?) {
    c.animateTo(target, duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic);
  }
  setState(() {});
}
```

`GlassTabDrag.live` 时，在 `_onDragUpdate` 里当 `nearest` 变化就调用 `controller.animateTo(nearest, duration: 120ms)`；药丸仍用 `_dragPosition` 画，避免被 `TabController` 的动画拖慢。默认用 `scrub`，松手再提交，页面不会在拖动中疯狂重建。

### 溢出时的边缘自动滚动

`CenteredGlassTabs` 现在用 `SingleChildScrollView`，放不下时用户可以自己横向滚动。加入拖动后，这个滚动视图会和 `HorizontalDragGestureRecognizer` 抢手势。建议：

- `drag != none` 时，内部 `SingleChildScrollView` 固定 `NeverScrollableScrollPhysics`，只由 `_scroll` 程序化控制；
- 手指进入左/右 24dp 边缘时，启动 `Ticker`，每帧 `_scroll.jumpTo(offset ± 6)`，并重新计算 `_dragPosition`；
- 手指离开边缘或拖动结束，停掉 `Ticker`；
- 这样标签条只有一套横向手势，不会和 `TabBarView` / 剧集横向列表打架。

`CenteredGlassTabs` 已有的「选中项居中」逻辑（`_centerChosen`）可以保留，但拖动中不要调用，避免和手指位置抢滚动。

### 胶囊包装

```dart
Widget _panel(Widget child) {
  if (!widget.capsule) return child;
  return LiquidPress(
    enabled: !_dragging,
    maxGrowth: 8,
    pullPastEdges: true,
    child: GlassCapsule(
      refraction: widget.refraction,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.height / 2),
        child: SizedBox(height: widget.height, child: child),
      ),
    ),
  );
}
```

拖动时把 `LiquidPress` 关掉，避免「按压拉长」和「拖动跟手」两个位移叠加；松手后再打开。

### 两个兼容包装

```dart
class CenteredGlassTabs extends StatelessWidget {
  // 保留现有构造参数
  @override
  Widget build(BuildContext context) => GlassTabStrip(
    items: labels.map(GlassTabItem.new).toList(),
    controller: controller,
    capsule: true,
    centered: centered,
    height: height,
    labelPadding: labelPadding,
    refraction: refraction,
    drag: GlassTabDrag.scrub,
    onSelected: onTap,
  );
}

class GlassTabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GlassTabStrip(
    items: labels.map(GlassTabItem.new).toList(),
    controller: controller,
    capsule: true,
    centered: false,       // 保持现在的左对齐
    refraction: refraction,
    drag: GlassTabDrag.scrub,
    onSelected: onTap,
  );
}
```

这样首页、动态、会员三处不需要改调用方；其他页面可以先用 `CenteredGlassTabs`（页面级、2–7 个标签、无长按/图标），复杂布局再用 `GlassTabStrip`。

## 手指拖动的可行性与冲突

| 页面/条 | 需要驱动的状态 | 主要冲突 | 结论 |
|---|---|---|---|
| 首页 / 动态 | `TabController.animateTo`；药丸用本地 `_dragPosition` | 外层 `TabBarView` 横向滑动；信息流纵向滚动 | 可做。拖动条在 `TabBarView` 外，纵向滚动不受影响；横向手势由标签条优先 |
| UP 空间 | `MemberController.tabController` | `ExtendedNestedScrollView` 的纵向滚动；`tab2` 刷新后重建控制器 | 可做。标签条在 nested body 外，纵向不冲突；处理控制器替换 |
| 历史 / 收藏 / 搜索 / 直播分区 | 各自的 `TabController.animateTo` | `TabBarView` 的横向滑动；`isScrollable` 标签条自身的横向滚动 | 可做。把标签条内部滚动改为程序化，拖动独占横向手势 |
| 直播分区详情 | `LiveAreaDetailController.tabController` | 同一 `Row` 里的两个 `iconButton`；`TabBarView` | 可做。`Expanded` 内只包标签条，按钮不参与手势 |
| 关注 | `FollowController.tabController` | 标签长按菜单；分组数量变化 | 可做，但必须保留 `onLongPress`/`onSecondaryTap`；长按优先于拖动 |
| 收藏子页（追番/笔记） | 本地 `TabController`；`NeverScrollableScrollPhysics` | 外层收藏页的 `TabBarView`；内层没有页面滑动 | 可做。拖动是唯一能切页的手势，体验反而更好；用无胶囊条 |
| 会员投稿 | `MemberContributeCtr.tabController`；`NeverScrollableScrollPhysics` | 外层 UP 空间 `TabBarView`；内层内容横向卡片 | 可做，但优先级低；标签条不要做胶囊 |
| 动态详情 | `CommonDynPageMultiState.tabController`；`NeverScrollableScrollPhysics` | 外层动态详情滚动；`DynTabBar` 现有 indicator workaround | 可做；换掉 `DynTabBar` 后 workaround 可删 |
| 番剧时间表 | 局部 `DefaultTabController` | 下方剧集横向 `ListView`；`NeverScrollableScrollPhysics` | **不建议拖动**。日期条是时间选择器，不是页面导航；保留 `TabBar` |
| 话题排序 | `DynTopicController.sortBy` | `SliverPinnedHeader`；每次切换重新请求 | **不建议拖动**。用 `ToggleButtons` 或索引模式，点选即可 |
| 视频详情 | `VideoDetailController.tabCtr` | 播放器手势；简介横向卡片；控制条空间 | **不建议**。保留 `TabBar`，最多 `LiquidPress` |
| 筛选条（PGC 索引、搜索排序、UP 标签、直播首页分区） | 各自的 `index` / `params` | 横向滚动；请求节流 | **不做页签拖动**。保持筛选控件，最多按压缩放 |

### 通用冲突处理

1. **横向 `SingleChildScrollView`**：拖动模式下不要让它参与手势竞技场；用 `NeverScrollableScrollPhysics` + `ScrollController`，由标签条自己滚。
2. **`TabBarView` / `PageView`**：标签条在页面外，页面滑动仍然更新 `controller.animation`；标签拖动时用本地 `_dragPosition` 画药丸，松手再 `animateTo`，避免两个动画互相覆盖。
3. **`NeverScrollableScrollPhysics`**：页面不能滑，但 `controller.animateTo` 仍然能切页；这正是收藏子页、会员投稿、动态详情需要的行为。
4. **`ExtendedNestedScrollView`**：标签条在 body 顶部、不在 sliver 里，纵向手势不会冲突；不要把标签条塞进 `SliverPersistentHeader` 再套横向拖动。
5. **`DefaultTabController`**：`GlassTabStrip` 需要显式 `TabController`；在 `Builder` 里用 `DefaultTabController.of(context)` 取，或把页面改成显式 `TabController`。后者更利于控制器重建。
6. **异步控制器**：历史、直播分区、小站、会员的 `TabController` 都在接口返回后创建；标签条只在非 null 时构建，或在 `Obx` 里判空。
7. **长度变化**：会员刷新、关注增删分组、搜索计数变化都会改变标签数量/宽度；`didUpdateWidget` 必须重新测量并 clamp 当前 index。
8. **长按 / 右键**：关注分组编辑需要 `onLongPress` 和 `onSecondaryTap`；这两个回调放在 `GlassTabItem` 上，不要放在整条上。
9. **鼠标/触控板**：桌面端横向拖动应只对 touch 启用，鼠标拖动会误触；`GestureDetector` 的 `supportedDevices` 或 `dragDevices` 要排除 mouse，除非用户明确要鼠标拖。
10. **无障碍**：每个标签要有 `Semantics(button: true, selected: ...)`；拖动不应成为唯一操作方式，点击必须保留。

## 迁移顺序（先易后难）

### P0：抽组件，不改视觉

1. 新建 `glass_tab_strip.dart`，把 `CenteredGlassTabs` 的测量、布局、药丸、滚动逻辑搬过去。
2. `CenteredGlassTabs` 改为薄包装，并加一个 `drag` 参数（默认 `none`）；首页/动态视觉不变。
3. 只在首页/动态传 `drag: scrub`，验证与 `TabBarView`、信息流纵向滚动、底栏手势的关系。
4. 通过后再改会员：`GlassTabBar` 改为 `GlassTabStrip(capsule:true, centered:false)`，补 `LiquidPress`。

### P1：2–3 个标签，机械替换

这批页面结构最简单，适合当模板：

- 稍后再看（`pages/later/view.dart`）
- 黑名单（`pages/blacklist/view.dart`）
- 通讯录（`pages/contact/view.dart`）
- 弹幕屏蔽（`pages/danmaku_block/view.dart`）
- 直播弹幕屏蔽（`pages/live_dm_block/view.dart`）
- 会员搜索（`pages/member_search/view.dart`）
- 直播搜索（`pages/live_search/view.dart`）
- 番剧点评（`pages/pgc_review/view.dart`）
- 评论搜索（`pages/video/reply_search_item/view.dart`）

验收：点击、页面滑动、标签拖动三种方式得到的 index 一致；计数变化后药丸不偏。

### P2：页面级 5–7 个标签

- 历史记录（`pages/history/view.dart`）
- 我的收藏（`pages/fav/view.dart`）
- 搜索结果（`pages/search_result/view.dart`）
- 直播分区（`pages/live_area/view.dart`）
- 直播分区详情（`pages/live_area_detail/view.dart`）
- 会员充电榜（`pages/member_upower_rank/view.dart`）
- 小站（`pages/bubble/view.dart`）
- 番剧索引入口（`pages/pgc/view.dart:266`）

这批需要处理异步控制器、滚动溢出和计数；但标签本身仍然是纯文本。

### P3：已有玻璃 / 复杂布局

- 会员 / UP 空间（`pages/member/view.dart`，`GlassTabBar` → `GlassTabStrip`）
- 关注（`pages/follow/view.dart`，长按菜单 + 图标）
- 会员投稿（`pages/member_contribute/view.dart`，无胶囊、无页面滑动）
- 动态详情（`pages/dynamics_detail/view.dart`，替换 `DynTabBar`）
- 收藏子页（`pages/fav/pgc/view.dart`、`pages/fav/note/view.dart`，无胶囊）

### P4：保留，不迁

- 番剧/影视时间表（`pages/pgc/view.dart:112`）
- 话题排序（`pages/dynamics_topic/view.dart:91`）
- 视频详情（`pages/video/view.dart:1404`）
- PGC 索引筛选（`pages/pgc_index/view.dart`）
- 搜索视频排序（`pages/search_panel/video/view.dart`）
- UP 投稿标签（`pages/member_video_web/archive/view.dart`）
- 直播首页分区入口（`pages/live/view.dart`）
- 所有面板内 `TabBar`（表 4）

## 可机械迁移的页面清单

> 前提：`GlassTabStrip` 已合入并通过 P0 验收；下列页面不再改布局，只替换标签条。每行都需要保留原有的 `onTap` 回顶逻辑。

| 页面 | 文件 | 迁移方式 | 额外条件 |
|---|---|---|---|
| 稍后再看 | `lib/pages/later/view.dart` | `GlassTabStrip(capsule:true)` | 数量文本会变，重新测量 |
| 历史记录 | `lib/pages/history/view.dart` | `GlassTabStrip(capsule:true)` | `tabController` 可空；`tabs.isEmpty` 不建条 |
| 我的收藏 | `lib/pages/fav/view.dart` | `GlassTabStrip(capsule:true)` | 7 个标签，溢出时自动滚 |
| 搜索结果 | `lib/pages/search_result/view.dart` | `GlassTabStrip(capsule:true)` | 计数用 `Obx`；`SearchType.actives` 6 项 |
| 直播分区 | `lib/pages/live_area/view.dart` | `GlassTabStrip(capsule:true)` | 控制器在接口回调里创建 |
| 直播分区详情 | `lib/pages/live_area_detail/view.dart` | `GlassTabStrip(capsule:true)` | 放在 `Expanded`，右侧按钮不动 |
| 番剧点评 | `lib/pages/pgc_review/view.dart` | `GlassTabStrip(capsule:true)` | 2 个标签 |
| 会员搜索 | `lib/pages/member_search/view.dart` | `GlassTabStrip(capsule:true)` | 计数 `Obx` |
| 直播搜索 | `lib/pages/live_search/view.dart` | `GlassTabStrip(capsule:true)` | 计数 `Obx` |
| 黑名单 | `lib/pages/blacklist/view.dart` | `GlassTabStrip(capsule:true)` | 2 个标签 |
| 通讯录 | `lib/pages/contact/view.dart` | `GlassTabStrip(capsule:true)` | 2 个标签 |
| 弹幕屏蔽 | `lib/pages/danmaku_block/view.dart` | `GlassTabStrip(capsule:true)` | 计数 `Obx` |
| 直播弹幕屏蔽 | `lib/pages/live_dm_block/view.dart` | `GlassTabStrip(capsule:true)` | 2 个标签 |
| 小站 | `lib/pages/bubble/view.dart` | `GlassTabStrip(capsule:true)` | 控制器异步创建 |
| 收藏-追番/追剧 | `lib/pages/fav/pgc/view.dart` | `GlassTabStrip(capsule:false)` | 无页面滑动；内层不要胶囊 |
| 收藏-笔记 | `lib/pages/fav/note/view.dart` | `GlassTabStrip(capsule:false)` | 无页面滑动；内层不要胶囊 |
| 会员充电榜 | `lib/pages/member_upower_rank/view.dart` | `GlassTabStrip(capsule:true)` | 先把 `DefaultTabController` 改成显式 `TabController` |
| 评论搜索 | `lib/pages/video/reply_search_item/view.dart` | `GlassTabStrip(capsule:true)` | 优先级低 |

**不要交给子代理机械改的**：首页、动态、会员、关注、会员投稿、动态详情、番剧时间表、话题排序、视频详情、所有筛选条。它们要么已有玻璃结构，要么有长按/横向列表/请求节流等额外语义。

## 验收清单

- [ ] 点击标签、滑动页面、拖动标签，三种方式最终 index 一致；松手后药丸停在正确标签中心。
- [ ] 页面滑动时药丸连续跟手，不跳帧；标签拖动时药丸跟手指，页面在松手后切换（`scrub`）。
- [ ] 标签溢出时能通过边缘自动滚动到达所有标签；不出现「标签条和页面同时横向滑动」。
- [ ] `LiquidPress` 在拖动时关闭，松手后恢复；按压回弹开关（`GlassFeatures.press`）关闭时不报错。
- [ ] 标签数量/文字变化后，药丸宽度和位置重新计算，不残留旧宽度。
- [ ] `TabController` 为 null、长度变化、页面刷新重建时不抛异常。
- [ ] 关注分组的长按/右键菜单仍可打开；标签上的菜单图标不挤压文字。
- [ ] `Revamp.enabled == false` 时，未迁移页面仍保持原下划线外观；已迁移页面有合理的非玻璃回退（至少不透明药丸）。
- [ ] 桌面端鼠标不会误触发标签拖动；触摸板横向滚动仍可用。
- [ ] 每个标签有 `Semantics` 的 selected/button 信息；点击区域不小于 44dp。
- [ ] 不改变现有 `TabBarView` 的 `tabBarScrollPhysics` / `CustomHorizontalDragGestureRecognizer` 行为。
