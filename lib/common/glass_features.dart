import 'package:PiliPlus/utils/storage.dart';

/// PiliGlass's own features, each with its switch in 设置 › PiliGlass 特性
/// (see glass_settings.dart). All default on.
///
/// Read once: the switches take effect after a restart, so a widget that
/// was built with an effect is never rebuilt without it halfway through.
/// Kept apart from upstream's SettingBoxKey and Pref.
abstract final class GlassFeatures {
  // the keys in the settings box
  static const String railKey = 'glassRail',
      commentSheetKey = 'glassCommentSheet',
      danmakuBarKey = 'glassDanmakuBar',
      ambientKey = 'glassAmbient',
      refractionKey = 'glassRefraction',
      glassSurfacesKey = 'glassSurfaces',
      toastKey = 'glassToast',
      refreshBallKey = 'glassRefreshBall',
      jellySwitchKey = 'glassJellySwitch',
      riseInKey = 'glassRiseIn',
      pressKey = 'glassPress',
      sheetSpringKey = 'glassSheetSpring',
      imageSpringKey = 'glassImageSpring',
      coverHeroKey = 'glassCoverHero',
      actionPopKey = 'glassActionPop',
      updateDohKey = 'glassUpdateDoh',
      railWidthKey = 'glassRailWidth';

  static bool _get(String key) =>
      GStorage.setting.get(key, defaultValue: true) as bool;

  /// the dock as a rail of glass on a wide screen
  static final bool rail = _get(railKey);

  /// the comments as a sheet of glass over the video page, not a tab
  static final bool commentSheet = _get(commentSheetKey);

  /// sending and showing danmaku from the bottom of the full screen video
  static final bool danmakuBar = _get(danmakuBarKey);

  /// the video page tinted with the cover's color
  static final bool ambient = _get(ambientKey);

  /// the glass bending what is behind it; blur only where it is off
  static final bool refraction = _get(refractionKey);

  /// menus, sheets and dialogs of frosted glass
  static final bool glassSurfaces = _get(glassSurfacesKey);

  /// toasts on a capsule of glass
  static final bool toast = _get(toastKey);

  /// the pull to refresh spinner in a ball of glass
  static final bool refreshBall = _get(refreshBallKey);

  /// the settings' switches that stretch and squash
  static final bool jellySwitch = _get(jellySwitchKey);

  /// cards rising in on a spring as their list loads
  static final bool riseIn = _get(riseInKey);

  /// cards dipping when pressed
  static final bool press = _get(pressKey);

  /// sheets coming up on a spring
  static final bool sheetSpring = _get(sheetSpringKey);

  /// a picture opening and closing on a spring
  static final bool imageSpring = _get(imageSpringKey);

  /// a video's cover flying into the player
  static final bool coverHero = _get(coverHeroKey);

  /// 点赞, 投币 and 收藏 popping with a burst when tapped
  static final bool actionPop = _get(actionPopKey);

  /// the update's download resolving GitHub over DNS over HTTPS, around
  /// poisoned answers; read when an update is downloaded
  static bool get updateDoh => _get(updateDohKey);

  /// The window width from which the side bar shows instead of the bottom
  /// one, in dp; 0 for the default, the side bar on a window lying on its
  /// side. See MainController.bottomNavFor.
  static final double railWidth =
      (GStorage.setting.get(railWidthKey, defaultValue: 0) as num).toDouble();
}
