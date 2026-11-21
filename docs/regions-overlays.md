# 浮层动效迁移审计（Overlays / Sheets / Dialogs）

审计范围：`lib/` 下由控件打开的底部弹窗、面板、对话框、菜单与 Overlay。只读审计，未改动 `lib/`。

目标：

- (a) **drag-follow deformation**：按住/拖动时面板跟手形变，松手回弹（`LiquidPress`）。
- (b) **growth out of its opening control**：面板从触发它的按钮/横条位置长出（`GrowFromRect` / `GrowFromBottom`）。

---

## 0. 先看结论

已经完成、可直接当模板的：

1. **视频 ⋯ 更多设置**：`header_control.dart` 用 `Builder` 取按钮 rect，`PublishRoute.pendingMorph` → `PageUtils.showVideoBottomSheet` → `GrowFromRect`。
2. **评论输入条 → 回复面板**：`comment_sheet.dart` 取输入条 rect，`ReplyPage` 用 `GrowFromBottom`。
3. **GlassPopupAnchor 菜单**、**播放器 PlayerMenuButton**：已有“从按钮长出 + 按压缩放”，但用的是各自的 `showGeneralDialog` / `OverlayEntry`。
4. **图片查看器**：Hero + fade，本身已有空间关系，不建议再套 `GrowFromRect`。

最值得继续做的：

1. 评论列表中“回复”按钮打开回复面板（目前只有输入条路径有 morph）。
2. 发弹幕面板从底部弹幕输入条长出。
3. 视频画质/音质/解码/字幕等二级选择面板从设置行长出。
4. 动态发布全高 sheet、动态卡片“更多”sheet。
5. 音频“更多”/播放设置。
6. 收藏面板、转发/分享面板。

---

## 1. 现有机制

### `GrowFromBottom`

`lib/common/widgets/grow_from.dart:9`

- `from` 是屏幕坐标里的横条 rect。
- 面板底部先从 `from.bottom` 附近开始，高度从 `from.height` 长到自身高度，带一点 overshoot；关闭时快速缩回。
- 适合：**面板就压在一条底部横条上**，例如评论输入条上的回复面板、底部弹幕输入条上的发弹幕面板。
- 需要 `route.animation`；所以只能用于路由页面，或能拿到 `AnimationController` 的自绘 sheet。

### `GrowFromRect`

`lib/common/widgets/grow_from.dart:150`

- `from` 是触发控件的屏幕 rect。
- 面板先以 `from` 为起点做一份“小副本”，一边移动一边放大到自己的位置；关闭时缩回按钮。
- `anchor` 表示小副本贴住 `from` 的哪个角，默认 `Alignment.topRight`：
  - 顶栏右侧 ⋯ → `topRight`
  - 底部右侧按钮/FAB → `bottomRight`
  - 左上返回/菜单 → `topLeft`
  - 左下按钮 → `bottomLeft`
- 当前实现只区分四个角（`_anchor.x > 0` / `_anchor.y > 0`），**没有真正的水平居中 anchor**；居中 FAB 用 `bottomRight` 会略偏右，必要时再扩展。
- 面板尺寸和 opener 差距很大时最有效；小面板从旁边按钮长出反而不明显。

### `PublishRoute.pendingMorph`

`lib/pages/common/publish/publish_route.dart:25`

- 静态一次性交接：`PublishRoute` 构造函数里 `_takePendingMorph()` 读取并清空（`publish_route.dart:28-34`）。
- 设置后必须**立刻** push 一个 `PublishRoute`；中间插入 `showDialog` / `showModalBottomSheet` 会把 rect 留给下一个无关路由。
- `PageUtils.showVideoBottomSheet`（`lib/utils/page_utils.dart:473`）自己读取并消费它（`page_utils.dart:483`），有 morph 时包 `GrowFromRect`，无 morph 时走 350ms slide。
- 其它 `showModalBottomSheet` / `showDialog` **不会**消费 `pendingMorph`，需要新 helper 或手动读取并清空。

### `LiquidPress`

`lib/common/widgets/liquid_glass/liquid_press.dart:17`

- 按压放大，拖动时按 rubber-band 跟手拉伸，松手回弹簧。
- 只影响绘制，不影响布局/命中测试；菜单定位不会因为形变而错位。
- `pullPastEdges: true`：手指从面板外开始拖，也能把面板拉过去；适合菜单、popover。
- `panelOf`：当 wrapper 比可见面板大（例如全屏 Overlay 里只有一小块菜单）时，用它返回面板真实 rect。
- 已受 `GlassFeatures.press` 和系统“减少动画”控制，默认安全。

### 取 opener rect 的三种写法

**A. `Builder`（最轻，推荐给新代码）**

```dart
Builder(
  builder: (buttonContext) => IconButton(
    onPressed: () {
      final box = buttonContext.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        PublishRoute.pendingMorph =
            box.localToGlobal(Offset.zero) & box.size;
      }
      openPanel();
    },
    icon: ...,
  ),
)
```

现有例子：`header_control.dart:2211-2215`、`view.dart:739-752`。

**B. `GlobalKey`（控件在深层、拿不到 Builder 时）**

```dart
final key = GlobalKey();
...
IconButton(key: key, onPressed: () {
  final box = key.currentContext!.findRenderObject() as RenderBox;
  PublishRoute.pendingMorph = box.localToGlobal(Offset.zero) & box.size;
  ...
})
```

`GlassPopupAnchor` 就是这么做的：`glass_menu.dart:45-56`，并且用 `Overlay` 的 `RenderBox` 作为 `ancestor`，保证 rect 是 overlay 坐标。

**C. 控件自身就是 BuildContext（StatelessWidget 的 context）**

评论输入条直接 `context.findRenderObject()`：`comment_sheet.dart:1099-1103`。适合整块横条/整行可点的控件。

注意：面板关闭动画期间控件可能已 unmount，rect 必须**在打开前**取好；不要在 push 之后再取。

### 形变（drag-follow）怎么选

| 面板类型 | 建议 |
|---|---|
| 菜单、popover、小 action sheet、动态“更多” | `LiquidPress(pullPastEdges: true)`；手指从面板外开始拖也能拉过去 |
| 小底部 sheet（音频更多/播放设置、追番等） | `LiquidPress()`，`maxGrowth: 8`，默认 `pullPastEdges: false` |
| 大底部 sheet / 70% sheet（视频设置、收藏、画质） | 可包 `LiquidPress(maxGrowth: 6)`，但只在面板空白/非滑杆区域；滑杆多时建议不包 |
| 全高 sheet、评论 sheet、可拖拽列表 | **不包整块**；用 sheet 自身 drag。要形变只包顶部把手（`GrowFromBottom` 的输入条也属于这一类） |
| 键盘面板（回复、发弹幕、转发、分享） | **不包整块**；只给输入条/按钮加 `LiquidPress`，否则键盘顶起时整块拉伸很怪 |
| 对话框、系统选择器、图片查看器 | 不包 |

包法：`GrowFromRect(child: LiquidPress(child: panel))`（成长在外、形变在内），避免两个 transform 的锚点互相干扰。

---

## 2. 总表

> 动效缩写：`slide` = 位移；`spring` = `PiliSheetMotion` 弹簧（`revamp_theme.dart:18-25`，默认 520ms）；`fade+scale` = Material Dialog 默认；`PR` = `PublishRoute`。  
> 推荐里的 `GrowFromRect` 都默认“从按钮 rect 长出”，anchor 按控件位置选。

### 2.1 视频播放页

| 面板 | 打开者 file:line | 形态 | 当前动效 | 建议 |
|---|---|---|---|---|
| 视频 ⋯ 更多设置 | `pages/video/widgets/header_control.dart:2215`；竖屏悬浮层 `pages/video/view.dart:752`；入口 `showSettingSheet` `header_control.dart:377` | 竖屏 70% 底部 sheet / 横屏右侧全高 side panel | `GrowFromRect` 460ms（已迁移） | **保留**，作为模板。确认 `from` 用按钮 rect，不要用页面 context |
| 选择画质 | 行 `header_control.dart:770`；方法 `1058`；打开 `1069` | 同 70%/side panel | `PR` slide 350ms | `GrowFromRect`，anchor `bottomRight`；在 `Get.back()` 前用 row `Builder` 设 `pendingMorph`。嵌套“关闭旧 sheet 再开新 sheet”需实机确认节奏 |
| 选择音质 | 行 `header_control.dart:784`；方法 `1160`；打开 `1163` | 同上 | slide 350ms | 同上 |
| 解码格式 | 行 `header_control.dart:797`；方法 `1239`；打开 `1252` | 同上 | slide 350ms | 同上 |
| 字幕设置 | 行 `header_control.dart:847`；方法 `1444`；打开 `1445`（全屏底部多 70 padding） | 同上 | slide 350ms | `GrowFromRect` 或先保留；字号滑杆多，形变不要太强 |
| 弹幕设置 | 行 `header_control.dart:838`；播放器按钮 `2097`；实现 `header_mixin.dart:54,68` | 同上 | slide 350ms | 行入口：`GrowFromRect`；播放器按钮入口：按钮包 `LiquidPress` 并取 rect |
| 弹幕列表 | 行 `header_control.dart:829`；方法 `1672`；打开 `1675` | 同上，较高 | slide 350ms | 可 `GrowFromRect`，或保留 slide（列表内容多，成长收益一般） |
| 评论回复面板（输入条） | 输入条 `pages/video/widgets/comment_sheet.dart:1097-1106`；路由 `pages/common/reply_controller.dart:277`；`GrowFromBottom` `pages/video/reply_new/revamp_view.dart:20-28` | 键盘上方玻璃胶囊 | `GrowFromBottom`（已迁移） | **保留**；关闭时 `pendingMorph` 的 microtask 清理要保留 |
| 评论回复面板（评论项） | 评论项“回复”按钮 `pages/video/reply/widgets/reply_item_grpc.dart:545-549`；楼中楼 `pages/video/reply_reply/view.dart:347`；路由 `reply_controller.dart:277` / `reply_reply/controller.dart:163` | 同上 | `PR` slide 500ms | **高价值**：在回复按钮外包 `Builder`，设 `pendingMorph`；`ReplyPage` 已自动 `GrowFromBottom` |
| 评论 sheet | 打开 `comment_sheet.dart:89`；卡片 `1227` | 整页可拖拽，两档：视频下沿 / 全屏 | 自绘 `SpringFollower`（`comment_sheet.dart:116-120`），rise `622-627`；无路由 | **保留**。要做“从预览卡片长出”需改 `_shown` 起始值/自绘动画，属 one-off，不建议批量套 `GrowFromRect` |
| 发送弹幕面板 | 路由 `pages/video/controller.dart:618-650`；入口 `pages/video/revamp_view.dart:61`、`pages/video/view.dart:1488` | 键盘上方玻璃胶囊 | `PR` slide 500ms | **高价值**：入口取 rect → `pendingMorph`；`SendDanmakuPanel` 的 `Revamp` build 包 `GrowFromBottom` |
| 评论“更多”sheet | 主评论 `reply_item_grpc.dart:111`；楼中楼 `632`；长按 `161` / `652` | 内容高度底部 sheet | spring 520ms | `GrowFromRect` 从被长按行（anchor 视位置）；`LiquidPress(pullPastEdges: true)` |
| 播放页内容 sheet 组：选集/简介/AI/看点/笔记/成员/弹幕池 | `pages/video/view.dart:1987,1998,2068,2155,2173`；`pages/video/controller.dart:1005,1353`；`MiniScaffold.showBottomSheet` `common/widgets/scaffold/mini_scaffold.dart:137` | 全屏时 PR 路由 sheet；普通时 MiniScaffold 页内 sheet | 全屏 slide 350ms；页内高度因子/透明度动画 | 给 `MiniScaffold.showBottomSheet` 加可选 `Rect? morphFrom`，内部用 controller 驱动 `GrowFromBottom`/`GrowFromRect`；**一个 helper 覆盖整组** |
| 下载面板 | 入口 `header_control.dart:2310`（列表行入口 `549`）；打开 `pages/video/controller.dart:1464` | 可拖拽 0.7/1.0 | spring 520ms | `GrowFromRect` 从“缓存”按钮，anchor `bottomRight`；`LiquidPress` 可选 |
| 视频分享 dialog | UGC `pages/video/introduction/ugc/controller.dart:287,295`；PGC `pgc/controller.dart:139,142`；入口 `ugc/view.dart:568` / `pgc/view.dart:543` | `SimpleDialog` | fade+scale ~150ms | 可保留；若要成长，用 `showGrowingDialog` 从分享按钮 rect |
| 视频“更多”glass menu | `pages/video/view.dart:1214` | 锚定 popup menu | spring 360ms + scale 0.78→1 | **已完成**，作为菜单模板 |
| 播放器倍速/设置 menu | `plugin/pl_player/view/view.dart:789,855`；实现 `common/widgets/player_menu.dart:64-137` | OverlayEntry 锚定面板 | 420ms spring + scale 0.72→1 | **已完成**；`LiquidPress` 已包按钮与面板 |
| 视频/弹幕举报 dialog | `header_control.dart:264,299`；评论 `reply_item_grpc.dart:1216` | `AlertDialog` | fade+scale | 保留；低收益 |

### 2.2 动态

| 面板 | 打开者 file:line | 形态 | 当前动效 | 建议 |
|---|---|---|---|---|
| 动态发布 `CreateDynPanel` | `pages/dynamics_create/view.dart:66,76`；入口 `pages/dynamics/view.dart:52`、`pages/main/view.dart:187,246`、`pages/dynamics_detail/view.dart:233` | 全高可拖拽 sheet（`initialChildSize: 1`） | spring 520ms | **高价值**：`GrowFromRect` 从发布 FAB，anchor `bottomRight`；不要直接包 `showModalBottomSheet`（会和 sheet 自身 slide 打架），用新的 growing-sheet route helper |
| 动态卡片“更多” | 按钮 `pages/dynamics/widgets/author_panel.dart:158-163`；打开 `274`；fallback `dynamic_panel.dart:230` | 内容高度底部 sheet，maxWidth 640 | spring 520ms | **高价值**：按钮当前用页面 context，需 `Builder`/`GlobalKey`；`GrowFromRect` anchor `topRight`；`LiquidPress(pullPastEdges: true)` |
| 动态转发 `RepostPanel` | 卡片 `pages/dynamics/widgets/action_panel.dart:51`；详情 `dynamics_detail/view.dart:566`；实现 `dynamics_repost/view.dart:25` | 带键盘的底部 sheet | spring 520ms | `GrowFromRect` 从“转发”按钮，anchor `bottomRight`；键盘弹出时不要形变 |
| 动态话题 | `pages/dynamics_select_topic/view.dart:30`；入口 `dynamics_create/view.dart:177` | 65%/全高可拖拽 | spring 520ms | `GrowFromRect` 从“选择话题”行；中等价值 |
| 动态 @ | `pages/dynamics_mention/view.dart:40`；入口 `common/publish/common_rich_text_pub_page.dart:481,332` | 65%/全高可拖拽 | spring 520ms | 同上；从 @ 工具栏按钮 |
| 保存动态 `SavePanel` | `pages/save_panel/view.dart:46-62`；入口 `author_panel.dart:324` | 居中分享卡，全屏滚动 | `PR` fade 255ms | 保留；成长从“保存动态”行收益低 |
| 动态举报 dialog | `author_panel.dart:638` | `AlertDialog` | fade+scale | 保留 |

### 2.3 音频

| 面板 | 打开者 file:line | 形态 | 当前动效 | 建议 |
|---|---|---|---|---|
| 音频“更多” | 按钮 `pages/audio/view.dart:142-145`；打开 `584,585` | 内容高度底部 sheet | spring 520ms | **高价值**：`GrowFromRect` 从 AppBar ⋯，anchor `topRight`；`LiquidPress(pullPastEdges: true)` |
| 音频播放设置 | 按钮 `audio/view.dart:864-871`；打开 `452,453` | 小底部 sheet（倍速/模式） | spring 520ms | `GrowFromRect` 从播放模式按钮，anchor `bottomRight`；`LiquidPress` |
| 音频播放列表 | 按钮 `audio/view.dart:895-901`；打开 `198,204` | 高底部 sheet，底部留 100 | spring 520ms | `GrowFromRect` 从列表按钮，anchor `bottomRight`；或保留 |
| 音频分享 dialog | `audio/controller.dart:598,602`；转发 `648`；分享至消息 `673` | `SimpleDialog` | fade+scale | 保留；转发行可 `GrowFromRect` |
| 收藏面板 `FavPanel` | 打开 `utils/page_utils.dart:160,164`；入口 `header_control.dart:2195,2294`、`introduction/ugc/view.dart:536`、`pgc/view.dart:518`、`audio/view.dart:704` | 可拖拽 0.7（横屏 1.0） | spring 520ms | **中高价值**：`GrowFromRect` 从星标按钮，anchor `bottomRight`；需要 `Builder`/`GlobalKey` 取 ActionItem 外层 rect |
| 追番状态 dialog | `common/widgets/dialog/dialog.dart:57,63`；入口 `video/introduction/pgc/view.dart:271` | `SimpleDialog` | fade+scale | 可 `GrowFromRect` 从“已追番”按钮，anchor `bottomRight`；或保留 |
| 分享至消息 `SharePanel` | `utils/page_utils.dart:68,101`；调用方如 `ugc/controller.dart:387`、`audio/controller.dart:673`、`author_panel.dart:367` | 带键盘的底部 sheet | spring 520ms | 入口是 dialog 行，不是主控件；建议保留或用 `LiquidPress`，不必强行成长 |
| 图片保存 dialog | `common/widgets/image/image_save.dart:30,38` | 居中卡片路由 | `PR` fade 200ms | 保留 |

### 2.4 历史 / 稍后再看

| 面板 | 打开者 file:line | 形态 | 当前动效 | 建议 |
|---|---|---|---|---|
| 历史 AppBar 菜单 | `pages/history/view.dart:167` | 标准 `PopupMenuButton` | showMenu fade/scale | 保留；要做玻璃菜单可换 `GlassPopupAnchor`，一刀切收益低 |
| 稍后再看 AppBar 菜单 | `pages/later/view.dart:219`（排序）、`264`（清空） | 标准 popup menu | showMenu fade/scale | 同上 |
| 历史条目菜单 | `pages/history/widgets/item.dart:105` | 标准 popup menu | showMenu fade/scale | 同上 |
| 删除/清空确认 | `history/base_controller.dart:19,55`；`later/controller.dart:54` | `AlertDialog` | fade+scale | 保留 |

### 2.5 图片、设置、其他

| 面板 | 打开者 file:line | 形态 | 当前动效 | 建议 |
|---|---|---|---|---|
| 图片查看器 | `utils/page_utils.dart:48`；路由 `common/widgets/image_viewer/hero_dialog_route.dart:10,38` | 全屏 Hero viewer | Hero + fade 460ms | **保留**，已有空间关系 |
| 横屏图片 sheet | `common/widgets/image_grid/image_grid_view.dart:105` | `MiniScaffold` 页内 sheet | 高度/透明度 | 保留；若统一，可复用 `MiniScaffold` 的 morph helper |
| 设置选择 dialog | `pages/setting/widgets/select_dialog.dart:16`；行 `normal_item.dart:46-50`；示例 `video_settings.dart:254` 等 | `AlertDialog` | fade+scale | 保留；若要统一，做 `showGrowingDialog`，在 `NormalItem` 统一设 rect。**不要只改几个调用点，否则 `pendingMorph` 会泄漏** |
| 设置多选/排序 dialog | `multi_select_dialog.dart:4`、`ordered_multi_select_dialog.dart:6` | `AlertDialog` | fade+scale | 保留或走同一 `showGrowingDialog` |
| 设置编辑 dialog | `pages/setting/models/model.dart:228`；`video_settings.dart:211,321` | `AlertDialog` + 输入框 | fade+scale | 保留（键盘 dialog 不适合形变） |
| 设置 `PopupListTile` | `pages/setting/widgets/popup_item.dart:67` | 行内 `showMenu` | fade/scale | 保留；或换 `GlassPopupAnchor`（需处理整行点击定位） |
| 搜索筛选 sheet | `search_panel/video/controller.dart:89`、`user/controller.dart:27`、`article/controller.dart:47` | 内容高度底部 sheet | spring 520ms | 低优先；`GrowFromRect` 从筛选按钮 |
| 直播 rank/码率 sheet | `live_room/view.dart:550,566`；`live_room/widgets/header_control.dart:251,303` | 70%/全高底部 sheet | spring 520ms | 低优先；`GrowFromRect` 从按钮，anchor `topRight` |
| 列表标签/预约 sheet | `live_area_detail/view.dart:122,191`；`member/view.dart:199,209` | 内容高度底部 sheet | spring 520ms | 低优先；可保留 |
| 播放速度页 添加/行菜单 | `pages/setting/pages/play_speed_set.dart:62`（dialog）、`118`（sheet） | 小 dialog / 小 sheet | fade+scale / spring | 保留 |
| 登录、系统选择器、原生分享 | 多处 | 系统组件 | 系统动画 | **不动** |

---

## 3. 迁移顺序

1. **视频 ⋯ 更多设置（已做，先验收）**  
   确认 `header_control.dart:381` 的 rect 是按钮而非页面；横屏 side panel 与竖屏 70% sheet 都正常。把它作为 `pendingMorph + GrowFromRect` 的参照实现。

2. **回复面板补齐所有入口（P0）**  
   输入条已好；给评论项/楼中楼的“回复”按钮包 `Builder`，设 `PublishRoute.pendingMorph`，复用 `ReplyPage` 已有的 `GrowFromBottom`。这是收益最大、改动最小的一步。

3. **发弹幕面板（P0）**  
   在 `revamp_view.dart:61`、`view.dart:1488` 等入口取输入条 rect；`SendDanmakuPanel` 的 `Revamp` 分支包 `GrowFromBottom`。注意它和回复面板一样会被键盘顶起。

4. **视频二级选择面板（P1）**  
   画质/音质/解码/字幕。先做“画质”一个验证“从关闭中的 sheet 行长大”的观感，再复制到其余三个。

5. **动态发布 + 动态卡片更多（P1）**  
   这两个需要先有 growing-sheet helper；做完后是动态页最显眼的两处。

6. **音频更多/播放设置（P1）**  
   AppBar ⋯ 与播放模式按钮，改动局部、风险低。

7. **收藏 / 转发 / 分享（P2）**  
   收藏面板从星标长出；转发面板从“转发”按钮长出。分享至消息入口在 dialog 里，暂缓。

8. **设置 dialog（P2，可选）**  
   统一做 `showGrowingDialog` 后再批量接；否则保持现状。举报、确认、追番等小 dialog 可以永久保留。

9. **评论 sheet、图片查看器（P3）**  
   已有自绘 spring / Hero，不建议批量改。评论 sheet 若要做“从预览卡片长出”，单独设计。

---

## 4. 复用 helper 还是 one-off

### 建议做成复用 helper

**H1. `showGrowingSheet` / `PublishSheetRoute`**

替代需要成长的 `showModalBottomSheet`。参数建议：

```dart
Future<T?> showGrowingSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Rect? from,                 // 或读 PublishRoute.pendingMorph
  Alignment anchor = Alignment.bottomRight,
  double? heightFactor,       // null = 内容高度
  double maxWidth = 640,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool enableDrag = true,
  Duration duration = const Duration(milliseconds: 460),
})
```

内部用 `PublishRoute` + `GrowFromRect`（或 `GrowFromBottom`）实现；不要再套 `showModalBottomSheet`，否则 sheet 自身的 slide 会和成长叠加。

适用：动态发布、动态更多、音频更多/播放设置/播放列表、转发、收藏、搜索筛选。

**H2. `showGrowingDialog`**

读取并清空 `PublishRoute.pendingMorph`，用 `showGeneralDialog` + `GrowFromRect` 包 page；适合设置选择、追番、举报、分享 dialog。

**H3. `morphRectOf(BuildContext)` / `setMorphFrom(BuildContext)`**

统一：

```dart
Rect? rectOf(BuildContext context, {RenderObject? ancestor}) { ... }
void setMorphFrom(BuildContext context, {RenderObject? ancestor}) { ... }
```

避免每个调用点重复 `findRenderObject`/`localToGlobal`，并统一处理 overlay 坐标。

**H4. `MiniScaffold.showBottomSheet(..., Rect? morphFrom)`**

`lib/common/widgets/scaffold/mini_scaffold.dart:137` 已有 `AnimationController`，加一个可选 rect，内部包 `GrowFromBottom`/`GrowFromRect` 即可覆盖播放页的选集/简介/AI/看点/笔记/成员/弹幕池，以及横屏图片 sheet。这是“一个改动覆盖一组”的地方。

**H5. `GrowingDialogRoute`（可选）**

如果不想动 `showDialog` 的调用点，可以只在 `NormalItem`、`PopupListTile`、`ActionItem` 等统一入口用 H3 设 rect，再让 H2 消费。注意必须同时清空，避免 rect 泄漏到后续路由。

### 适合 one-off

- **评论 sheet**：页内自绘 Stack + `SpringFollower`，不是路由；成长要从 `_shown` 起始值做，不能直接套 `GrowFromRect`。
- **视频二级选择面板**：入口在“正在关闭的 sheet 的行”里，时序特殊；先做一个验证再复制。
- **播放器菜单 / GlassPopupAnchor**：已有自己的 overlay/general dialog 动效，保持现状。
- **历史/稍后再看 AppBar popup**：标准 `PopupMenuButton`，换 `GlassPopupAnchor` 要重排 item 和定位，单独处理。
- **图片查看器**：Hero 已足够，不需要成长。
- **设置编辑 dialog / 登录 / 系统选择器**：键盘或系统组件，形变收益低甚至有害。

### 需要特别注意

- `PublishRoute.pendingMorph` 是全局静态；`showModalBottomSheet`/`showDialog` 不会消费它。任何新 helper 必须 `take + clear`。
- 全高 sheet（动态发布、评论 sheet）不要套大 `maxGrowth` 的 `LiquidPress`；拉伸极限是短边的 7/32，全屏面板会明显变形。建议 `maxGrowth: 6~8`，或只给顶部把手/输入条加。
- 菜单/小面板适合 `LiquidPress(pullPastEdges: true)`；底部 sheet 用默认 `false`，从按下点开始拉更自然。
- `GrowFromRect` 的 `from` 必须是全局坐标；如果控件在缩放/变换容器里，用 `localToGlobal(..., ancestor: overlayBox)`。
- 面板关闭动画期间不要重新取 rect；先取好再 push。

---

## 5. 可机械迁移的面板（review 后可直接派给 subagent）

满足以下条件：入口明确、面板是独立路由或可包一层、无需改数据逻辑。

- [ ] **视频画质** `header_control.dart:770/1069` — 行 `Builder` 设 `pendingMorph`，`showVideoBottomSheet` 已有 `GrowFromRect`。
- [ ] **视频音质** `header_control.dart:784/1163` — 同上。
- [ ] **视频解码格式** `header_control.dart:797/1252` — 同上。
- [ ] **视频字幕设置** `header_control.dart:847/1445` — 同上（可先保留 slide）。
- [ ] **评论项回复面板** `reply_item_grpc.dart:545-549` / `reply_reply/view.dart:347` — 设 `pendingMorph`，`ReplyPage` 已消费。
- [ ] **发弹幕面板** `revamp_view.dart:61` / `view.dart:1488` — 设 rect，`SendDanmakuPanel` 包 `GrowFromBottom`。
- [ ] **动态卡片更多** `author_panel.dart:163/274` — 按钮改 `Builder`/`GlobalKey`，`GrowFromRect` + `LiquidPress(pullPastEdges: true)`。
- [ ] **音频更多** `audio/view.dart:144/585` — `GrowFromRect` + `LiquidPress(pullPastEdges: true)`。
- [ ] **音频播放设置** `audio/view.dart:866/453` — `GrowFromRect` + `LiquidPress`。
- [ ] **收藏面板** `page_utils.dart:160` + 星标入口 — 需要给 `ActionItem` 外层加 `Builder`/key，再设 rect。
- [ ] **追番状态 dialog** `dialog.dart:57` + `pgc/view.dart:271` — 可换成 `showGrowingDialog`。

暂不派：

- 动态发布、动态更多、音频播放列表、转发/分享，等 H1 `showGrowingSheet` 落地后再批量做。
- 评论 sheet、图片查看器、历史/稍后再看 popup、设置 dialog 组，先保持现状或单独设计。
