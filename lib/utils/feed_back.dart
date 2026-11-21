import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/services.dart' show HapticFeedback;

bool enableFeedback = Pref.feedBackEnable;
void feedBack() {
  if (enableFeedback) {
    HapticFeedback.lightImpact();
  }
}

/// The tick of moving from one choice to the next, e.g. under a finger that
/// is sliding through a menu. Follows 设置 › 震动反馈.
void feedBackSelection() {
  if (enableFeedback) {
    HapticFeedback.selectionClick();
  }
}
