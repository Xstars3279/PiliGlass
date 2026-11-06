import 'package:PiliPlus/common/glass_features.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// 设置 › PiliGlass 特性: what PiliGlass adds to PiliPlus, each with its
/// own switch, in groups. See [GlassFeatures].
const List<(String, List<SettingsModel>)> glassSettingGroups = [
  (
    '界面',
    [
      SwitchModel(
        title: '液态玻璃底栏与新界面',
        subtitle: '悬浮的玻璃底栏、搜索按钮，以及重新设计的各个页面；关闭后回到原版样式',
        leading: Icon(Icons.water_drop_outlined),
        setKey: SettingBoxKey.liquidGlassNavBar,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '平板/横屏玻璃侧栏',
        subtitle: '宽屏时导航移到左侧的玻璃竖胶囊，按住显示文字',
        leading: Icon(Icons.view_sidebar_outlined),
        setKey: GlassFeatures.railKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '评论玻璃面板',
        subtitle: '竖屏视频页的评论改为可拖拽的玻璃面板；关闭则为原版的评论标签页',
        leading: Icon(Icons.comment_outlined),
        setKey: GlassFeatures.commentSheetKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '全屏底部弹幕栏',
        subtitle: '全屏时在底部发弹幕、开关弹幕、调弹幕设置；关闭则放回顶栏',
        leading: Icon(Icons.subtitles_outlined),
        setKey: GlassFeatures.danmakuBarKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '封面取色氛围背景',
        subtitle: '视频页顶部染上封面的颜色',
        leading: Icon(Icons.gradient_outlined),
        setKey: GlassFeatures.ambientKey,
        defaultVal: true,
        needReboot: true,
      ),
    ],
  ),
  (
    '玻璃效果',
    [
      SwitchModel(
        title: '液态玻璃折射',
        subtitle: '玻璃边缘折射背后的内容；关闭后只保留模糊，更省电',
        leading: Icon(Icons.lens_blur_outlined),
        setKey: GlassFeatures.refractionKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '玻璃菜单与弹窗',
        subtitle: '弹出菜单、底部弹窗、对话框为半透明磨砂玻璃',
        leading: Icon(Icons.layers_outlined),
        setKey: GlassFeatures.glassSurfacesKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '玻璃提示框',
        subtitle: '点赞成功等提示为弹出的玻璃胶囊',
        leading: Icon(Icons.chat_bubble_outline),
        setKey: GlassFeatures.toastKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '玻璃下拉刷新球',
        leading: Icon(Icons.refresh_outlined),
        setKey: GlassFeatures.refreshBallKey,
        defaultVal: true,
        needReboot: true,
      ),
    ],
  ),
  (
    '动效',
    [
      SwitchModel(
        title: '流畅页面转场',
        subtitle: '视差推入，在页面任意位置右滑返回；开启时「外观设置」里的过渡动画不生效',
        leading: Icon(Icons.swipe_right_outlined),
        setKey: SettingBoxKey.modernPageTransition,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '卡片弹簧升起',
        subtitle: '列表加载、刷新时卡片依次弹起',
        leading: Icon(Icons.view_agenda_outlined),
        setKey: GlassFeatures.riseInKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '按压回弹',
        subtitle: '按下卡片时轻微缩小再弹回；关闭后点击视频立即打开',
        leading: Icon(Icons.touch_app_outlined),
        setKey: GlassFeatures.pressKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '封面飞入播放器',
        subtitle: '打开视频时封面从卡片飞到播放器位置',
        leading: Icon(Icons.flight_takeoff_outlined),
        setKey: GlassFeatures.coverHeroKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '弹窗弹簧',
        subtitle: '底部弹窗带回弹地弹起',
        leading: Icon(Icons.vertical_align_top_outlined),
        setKey: GlassFeatures.sheetSpringKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '图片放大弹簧',
        subtitle: '点开、关闭图片时带回弹',
        leading: Icon(Icons.zoom_out_map_outlined),
        setKey: GlassFeatures.imageSpringKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '三连弹跳',
        subtitle: '点赞、投币、收藏时图标弹跳并迸出粒子',
        leading: Icon(Icons.thumb_up_outlined),
        setKey: GlassFeatures.actionPopKey,
        defaultVal: true,
        needReboot: true,
      ),
      SwitchModel(
        title: '果冻开关',
        subtitle: '设置里的开关按住拉长、撞边压扁',
        leading: Icon(MdiIcons.toggleSwitchOutline),
        setKey: GlassFeatures.jellySwitchKey,
        defaultVal: true,
        needReboot: true,
      ),
    ],
  ),
  (
    '更新',
    [
      SwitchModel(
        title: '更新下载使用安全 DNS',
        subtitle: '通过 DoH 解析 GitHub 地址，绕开 DNS 污染；连不上时自动改用系统 DNS',
        leading: Icon(Icons.dns_outlined),
        setKey: GlassFeatures.updateDohKey,
        defaultVal: true,
      ),
    ],
  ),
];

/// all of them in one list, for the settings search
final List<SettingsModel> glassSettings = [
  for (final (_, models) in glassSettingGroups) ...models,
];
