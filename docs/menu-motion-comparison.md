# 菜单动画对比：FlClash 代理页 ⋯ vs PiliGlass 玻璃菜单

> 对象：FlClash 代理页右上角 ⋯（应用栏 overflow），以及 PiliGlass 的 `GlassPopupAnchor` / `GlassIconButton`。
> 代码位置：
> - FlClash：`D:\dev\_downloads\FlClash\lib\ui\scaffold\scaffold_actions.dart:116` → `prism_ui/lib/popup.dart`
> - PiliGlass：`lib/common/widgets/liquid_glass/glass_menu.dart`

## 结论

FlClash 的菜单位置在按钮**上方并盖住按钮**，打开时先画一个约 `0.41 × 按钮短边` 的圆形“platter”，再把它拉成卡片；内容被裁进 platter 并随其缩放，出现时才逐渐清晰。按钮本身被快照、隐藏，关闭时整块玻璃连同快照一起缩回按钮。

我们的菜单在按钮**下方 6px**，打开时把一张**已经完成的卡片**整体缩放到 0.24，再配合透明度；玻璃、文字、阴影都跟着缩小。所以看起来是“缩小的卡片淡入”，不是“从按钮里长出来”。

## 关键差异

| 项目 | FlClash | PiliGlass 现在 | 观感 |
|---|---|---|---|
| 触发 | 手指**按下**就打开，同一根手指继续滑进菜单 | `onTap`（抬起）才打开 | 按钮先回弹，菜单再出现，没有交接 |
| 位置 | 菜单顶边在按钮上方 8px，**盖住按钮** | 按钮下方 6px | 没有重叠，无法“融合” |
| 初始形状 | platter：约 0.41×按钮短边的圆，半径=高度/2 | 完整卡片整体缩放到 0.24 | 一开始就是一张迷你菜单 |
| 内容 | 裁进 platter，按 platter 比例缩放，出现时才去模糊 | 整个子树一起缩放 | 文字从第一帧就清晰可见 |
| 圆角 | 24 起，先呈胶囊，再用 324/.75 弹簧“变方” | 固定 16，跟着缩放 | 没有“胶囊→卡片”的形变 |
| 玻璃 | 每帧按 platter 重画，rim/阴影强度随进度上升 | 一次画好，整体缩放 | 折射带、模糊、rim 都被缩小 |
| 按钮 | 截图、隐藏，快照画进 droplet | 不截图、不隐藏 | 菜单旁边还留着原按钮 |
| 按压带入 | `_CarriedPress` 把按下坐标转发进菜单，可一路滑到选项 | 无 | 必须点两下 |
| 关闭 | 整块玻璃+快照缩回按钮，动作等 `completed` 后才执行 | 反向缩放到 0.24、30% 透明度后被移除 | 像“消失”，不是“吸回去” |
| 弹簧 | 打开 400/.754，450ms；圆角 324/.75，延迟 70ms；回缩 500ms | 单一 460ms bouncy，正反向同速 | 更像弹跳，不像液体 |

## 建议的修改顺序

1. **P1：菜单位置改到按钮上方/盖住按钮。** 最小改动，先让“从按钮里出来”成立。
2. **P2：把 `Transform.scale` 换成 platter 绘制。** 在 render object 里按 `_openingOf` 的几何画：起始圆 → 卡片矩形，裁切内容、内容模糊、圆角随进度；不要再用整体 Opacity/scale。
3. **P3：按下即打开，并把按压带进菜单。** 抄 `_PopupPressRecognizer` + `_CarriedPress`；列表行不再用 Material `InkWell`，改成跟手高亮/释放选中。
4. **P4：按钮快照 + 隐藏 + 关闭回缩。** `RepaintBoundary.toImageSync`，打开时画进 droplet，关闭时缩回并恢复按钮；选项动作延迟到路由完成。
5. **P5：圆角弹簧和玻璃样式渐变**（324/.75、延迟 70ms；rim/阴影随进度）。
6. **P6：按压下的命中测试**（`paintBoundsOf`），以及子菜单的 400ms 悬停展开。

P1+P2+P3 三项就能解释绝大部分“渐显 vs 液态气泡”的差异；P4 决定关闭是否像“吸回去”。
