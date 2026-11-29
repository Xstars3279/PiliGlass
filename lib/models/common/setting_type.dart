import 'package:PiliPlus/pages/setting/models/glass_settings.dart';
import 'package:PiliPlus/pages/setting/models/download_settings.dart';
import 'package:PiliPlus/pages/setting/models/dm_settings.dart';
import 'package:PiliPlus/pages/setting/models/dyn_settings.dart';
import 'package:PiliPlus/pages/setting/models/extra_settings.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart';
import 'package:PiliPlus/pages/setting/models/privacy_settings.dart';
import 'package:PiliPlus/pages/setting/models/recommend_settings.dart';
import 'package:PiliPlus/pages/setting/models/reply_settings.dart';
import 'package:PiliPlus/pages/setting/models/style_settings.dart';
import 'package:PiliPlus/pages/setting/models/video_settings.dart';

enum SettingType {
  privacySetting('隐私设置'),
  recommendSetting('推荐流设置'),
  videoSetting('音视频设置'),
  playSetting('播放器设置'),
  dmSetting('弹幕设置'),
  downloadSetting('下载设置'),
  replySetting('评论设置'),
  dynSetting('动态设置'),
  styleSetting('外观设置'),
  extraSetting('其它设置'),
  glassSetting('PiliGlass 特性'),
  webdavSetting('WebDAV 设置'),
  about('关于'),
  ;

  final String title;
  const SettingType(this.title);

  List<SettingsModel> get settings => switch (this) {
    .privacySetting => privacySettings,
    .recommendSetting => recommendSettings,
    .videoSetting => videoSettings,
    .playSetting => playSettings,
    .dmSetting => dmSettings,
    .downloadSetting => downloadSettings,
    .dynSetting => dynSettings,
    .replySetting => replySettings,
    .styleSetting => styleSettings,
    .extraSetting => extraSettings,
    .glassSetting => glassSettings,
    .webdavSetting || .about => throw UnimplementedError(),
  };

  List<(String, List<SettingsModel>)> get settingGroups => switch (this) {
    .glassSetting => glassSettingGroups,
    .recommendSetting => _groupByTitle(recommendSettings, const [
      ('推荐来源与刷新', {'首页推荐来源', '保留首页推荐刷新', '显示上次看到位置提示'}),
      (
        '内容过滤',
        {
          '点赞率',
          '标题关键词过滤',
          '分区关键词过滤',
          '视频时长',
          '播放量',
          '已关注UP豁免推荐过滤',
          '过滤器也应用于详情页相关视频',
        },
      ),
    ]),
    .downloadSetting => _groupByTitle(downloadSettings, const [
      ('默认配置', {'设置默认下载路径', '设置默认下载画质', '设置默认下载音质'}),
      ('管理与说明', {'我的下载', 'MP4 合并兼容说明'}),
    ]),
    .videoSetting => _groupByTitle(videoSettings, const [
      (
        '画质与音质',
        {
          '免登录1080P',
          '默认画质',
          '蜂窝网络画质',
          '默认音质',
          '蜂窝网络音质',
          '直播默认画质',
          '蜂窝网络直播默认画质',
        },
      ),
      ('解码与输出', {'开启硬解', '首选解码格式', '蜂窝网络首选解码格式', '硬解模式', '音频输出设备'}),
      ('网络与 CDN', {'B站定向流量支持', 'CDN 设置', '直播 CDN 设置', 'CDN 测速', '音频不跟随 CDN 设置'}),
      ('缓冲与同步', {'缓冲大小', '缓冲时长', '直播缓冲大小', '直播缓冲时长', '自动同步', '视频同步'}),
    ]),
    .playSetting => _groupByTitle(playSettings, const [
      (
        '播放控制',
        {
          '倍速设置',
          '播放顺序',
          '自动播放',
          '提前初始化播放器',
          '自动启用字幕',
          '音量均衡',
          '超分辨率',
          '播放器音量',
          '最高音量',
          '播放器设置仅对当前生效',
        },
      ),
      (
        '手势与交互',
        {
          '双击快退/快进',
          '双击快进/快退时长',
          '左右侧滑动调节亮度/音量',
          '滚轮调节音量',
          '调节系统亮度',
          '中间滑动进入/退出全屏',
          '滑动快进/快退使用相对时长',
          '滑动快进/快退时长',
          '启用双指缩小视频',
          '启用拖拽字幕调整底部边距',
          '全屏手势反向',
          '倾斜角度阈值',
          '启用键盘控制',
        },
      ),
      (
        '全屏与界面',
        {
          '竖屏扩大展示',
          '自动全屏',
          '自动退出全屏',
          '默认全屏方向',
          '全屏显示锁定按钮',
          '全屏显示截图按钮',
          '全屏显示电池电量',
          '全屏展示点赞/投币/收藏等操作按钮',
          '延长播放控件显示时间',
          '底部进度条展示',
          '滑动跳转预览视频缩略图',
          '显示高能进度条',
        },
      ),
      (
        '详情页与合集',
        {
          '视频页显示相关视频',
          '默认展开视频简介',
          '横屏自动展开视频简介',
          '横屏分P/合集列表显示在Tab栏',
          '横屏播放页在侧栏打开UP主页',
          '横屏在侧栏打开图片预览',
          '显示视频警告/争议信息',
          '显示视频分段信息',
          '显示继续播放分P提示',
          '分P/合集：倒序播放从首集开始播放',
          '观看人数',
        },
      ),
      ('后台与画中画', {'后台播放', '后台画中画', '画中画不加载弹幕', '后台音频服务', '最小化时暂停/还原时播放'}),
      ('直播', {'自动佩戴直播间粉丝牌', 'SuperChat (醒目留言) 显示类型', '全屏 SuperChat 设置'}),
    ]),
    .styleSetting => _groupByTitle(styleSettings, const [
      ('主题与色彩', {'主题模式', '纯黑主题', '应用主题', '深色下图片颜色叠加', '视频播放页使用深色主题'}),
      (
        '导航与布局',
        {
          '横屏适配',
          '改用侧边栏',
          '隐藏侧边栏文字',
          '优化平板导航栏',
          'MD3样式底栏',
          '悬浮底栏',
          '顶/底栏收起类型',
          '首页顶栏收起',
          '首页底栏收起',
          '默认启动页',
          '首页标签页',
          'Navbar编辑',
          '我的页卡片',
          '返回时直接退出',
        },
      ),
      (
        '页面与列表',
        {
          '列表宽度（dp）限制',
          '用户页默认展示TAB',
          '显示UP主页小店TAB',
          '动态页启用瀑布流',
          '动态页UP主显示位置',
          '动态页显示所有已关注UP主',
          '动态页展开正在直播UP列表',
          '播放页移除安全边距',
        },
      ),
      (
        '字体、图片与动效',
        {
          'App字体设置',
          '界面缩放',
          '页面过渡动画',
          '首页切换页面动画',
          '滑动动画弹簧参数',
          '图片质量',
          '查看大图质量',
          '气泡提示不透明度',
          '屏幕帧率',
        },
      ),
      ('角标与装饰', {'动态未读标记', '消息未读标记', '消息未读类型', '显示粉丝勋章', '展示头像/评论/动态装饰', '点击表情显示 Tooltip'}),
    ]),
    .extraSetting => _groupByTitle(extraSettings, const [
      ('存储与缓存', {'退出时最小化', '缓存路径', '允许三方APP访问私有存储', '最大缓存大小', '静默下载图片'}),
      ('播放与番剧增强', {'空降助手', '番剧片头/片尾跳过类型', '启用AI总结'}),
      ('搜索与发现', {'搜索建议', '记录搜索历史', '大家都在搜', '搜索发现', '搜索默认词', '显示热门推荐', '展示追番时间表'}),
      (
        '交互与功能',
        {
          '快速收藏',
          '预览 Live Photo',
          '侧滑关闭二级页面',
          '长按/右键显示图片菜单',
          '震动反馈',
          '横向滑动阈值',
          '刷新指示器高度',
          '消息页禁用"收到的赞"功能',
          '使用外部浏览器打开链接',
        },
      ),
      ('网络与更新', {'启用HTTP/2', '连接重试次数', '连接重试间隔', '设置代理', '禁用 SSL 证书验证', '检查更新'}),
    ]),
    _ => [(title, settings)],
  };

  static List<(String, List<SettingsModel>)> _groupByTitle(
    List<SettingsModel> all,
    List<(String, Set<String>)> spec,
  ) {
    final buckets = [for (final (name, _) in spec) (name, <SettingsModel>[])];
    final fallback = <SettingsModel>[];
    for (final item in all) {
      final t = item.title;
      var placed = false;
      for (var i = 0; i < spec.length; i++) {
        if (spec[i].$2.contains(t)) {
          buckets[i].$2.add(item);
          placed = true;
          break;
        }
      }
      if (!placed) {
        fallback.add(item);
      }
    }
    return [
      for (final b in buckets)
        if (b.$2.isNotEmpty) b,
      if (fallback.isNotEmpty) ('其他', fallback),
    ];
  }
}
