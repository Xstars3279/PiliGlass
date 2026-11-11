import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licenses of the code copied into this repository (see NOTICE), shown
/// on the license page (关于 › 开源许可) next to those of the packages, which
/// Flutter collects by itself.
abstract final class AppLicenses {
  /// The texts are read only when the license page asks for them.
  static void register() => LicenseRegistry.addLicense(_collect);

  /// the names shown on the license page, and the asset with the text
  static const _entries = <(List<String>, String)>[
    (['PiliGlass'], 'NOTICE'),
    (['PiliGlass', 'SukiSU-Ultra'], 'LICENSE'),
    (
      ['AndroidLiquidGlass', 'miuix', 'Android Open Source Project'],
      'LICENSES/Apache-2.0.txt',
    ),
    (['Anime4K'], 'assets/shaders/LICENSE'),
    (['dio_cookie_manager'], 'lib/utils/accounts/account_manager/LICENSE'),
  ];

  static Stream<LicenseEntry> _collect() async* {
    for (final (packages, asset) in _entries) {
      yield LicenseEntryWithLineBreaks(
        packages,
        await rootBundle.loadString(asset),
      );
    }
  }
}
