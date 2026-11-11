# 开源协议核查

核查日期：2026-11-10。依据：`pubspec.lock`、仓库内各文件的版权头、各上游仓库的 LICENSE 文件。

本文是对照协议文本做的整理，不是法律意见。

## 结论

- PiliGlass 以 GPL-3.0（或更新版本）发布，与上游 PiliPlus 一致。
- 仓库里拷贝或移植的第三方代码共 5 处，协议都与 GPL-3.0 兼容，来源和协议记在 [NOTICE](../NOTICE)，协议原文在 [LICENSES](../LICENSES)。
- `pubspec.lock` 中的 250 个依赖全部是宽松协议（BSD、MIT、Apache-2.0）或 MPL-2.0，都与 GPL-3.0 兼容，没有发现 GPL 不兼容或缺少协议的依赖。
- 应用内「关于 › 开源许可」列出本应用的声明、仓库内第三方代码的协议，以及 Flutter 自动收集的所有依赖协议。

## 仓库内的第三方代码

| 代码 | 位置 | 来源 | 协议 |
|---|---|---|---|
| 液态玻璃底栏、折射着色器 | `lib/common/widgets/liquid_glass/liquid_glass_navigation_bar.dart`、`shaders/liquid_glass_lens.frag` | SukiSU-Ultra，其中又改编自 Kyant0/AndroidLiquidGlass 和 compose-miuix-ui/miuix | GPL-3.0；Apache-2.0 |
| Flutter 组件的修改版 | `lib/common/widgets/flutter/` 等 24 个文件 | Flutter | BSD-3-Clause |
| 媒体通知辅助类 | `android/.../MediaHelper.java` | Android Open Source Project | Apache-2.0 |
| 超分辨率着色器 | `assets/shaders/Anime4K_*.glsl` | Anime4K | MIT；Unlicense |
| Cookie 管理 | `lib/utils/accounts/account_manager/` | dio_cookie_manager | MIT |

三个 Apache-2.0 来源（AndroidLiquidGlass、miuix、AOSP）都没有 NOTICE 文件，所以只需保留版权和协议声明，附上协议原文。

## 依赖协议统计

| 协议 | 数量 |
|---|---|
| BSD-3-Clause | 143 |
| MIT | 78 |
| Apache-2.0 | 21 |
| Apache-2.0 + BSD-3-Clause | 4 |
| MPL-2.0 | 3 |
| BSD-2-Clause | 1 |

- **MPL-2.0** 的 3 个（`dbus`、`nm`、`upower`）是 Linux 桌面版用到的间接依赖（读取电量、网络状态）。MPL-2.0 与 GPL-3.0 兼容。
- **Apache-2.0 + BSD-3-Clause** 的 4 个（`hive_ce`、`image_picker` 系列）是包内不同部分用不同协议，都兼容。
- 28 个 GitHub 依赖已由 `pubspec.lock` 锁定到具体 commit，协议按该 commit 的 LICENSE 文件核对。

## 尚未处理

- **预编译的原生库**：`media_kit` 在 Android 上附带预编译的 libmpv 和 FFmpeg，它们通常是 LGPL 或 GPL。分发这类二进制时，协议要求能提供对应的源码。上游 PiliPlus 也是同样的做法，目前依靠 media-kit 项目公开的构建仓库；如果要做得更稳妥，可以在 Release 说明里写明这些库的源码地址。
- **发布与源码的对应**：每个 Release 都应关联一个 tag，并且 tag 指向的 commit 就是打包所用的源码。

## 全部依赖

<details>
<summary>展开 250 个依赖</summary>

| 依赖 | 类型 | 来源 | 协议 |
|---|---|---|---|
| _fe_analyzer_shared | 间接 | pub.dev | BSD-3-Clause |
| analyzer | 间接 | pub.dev | BSD-3-Clause |
| android_file_picker | 间接 | pub.dev | MIT |
| ansicolor | 间接 | pub.dev | Apache-2.0 |
| app_links | 直接 | pub.dev | Apache-2.0 |
| app_links_linux | 间接 | pub.dev | Apache-2.0 |
| app_links_platform_interface | 间接 | pub.dev | Apache-2.0 |
| app_links_web | 间接 | pub.dev | Apache-2.0 |
| archive | 直接 | pub.dev | MIT |
| args | 间接 | pub.dev | BSD-3-Clause |
| asn1lib | 间接 | pub.dev | BSD-2-Clause |
| async | 间接 | pub.dev | BSD-3-Clause |
| audio_service | 直接 | GitHub | MIT |
| audio_service_mpris | 直接 | pub.dev | MIT |
| audio_service_platform_interface | 间接 | pub.dev | MIT |
| audio_service_web | 间接 | pub.dev | MIT |
| audio_session | 直接 | GitHub | MIT |
| battery_plus | 直接 | pub.dev | BSD-3-Clause |
| battery_plus_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| boolean_selector | 间接 | pub.dev | BSD-3-Clause |
| brotli | 直接 | pub.dev | MIT |
| build | 间接 | pub.dev | BSD-3-Clause |
| build_config | 间接 | pub.dev | BSD-3-Clause |
| build_daemon | 间接 | pub.dev | BSD-3-Clause |
| build_runner | 开发 | pub.dev | BSD-3-Clause |
| built_collection | 间接 | pub.dev | BSD-3-Clause |
| built_value | 间接 | pub.dev | BSD-3-Clause |
| cached_network_image_ce | 直接 | GitHub | MIT |
| cached_network_image_platform_interface_ce | 间接 | GitHub | MIT |
| canvas_danmaku | 直接 | GitHub | MIT |
| catcher_2 | 直接 | GitHub | Apache-2.0 |
| characters | 直接 | pub.dev | BSD-3-Clause |
| chat_bottom_container | 直接 | GitHub | Apache-2.0 |
| checked_yaml | 间接 | pub.dev | BSD-3-Clause |
| cli_config | 间接 | pub.dev | BSD-3-Clause |
| cli_util | 间接 | pub.dev | BSD-3-Clause |
| clock | 间接 | pub.dev | Apache-2.0 |
| cnativeapi | 间接 | pub.dev | MIT |
| code_assets | 间接 | pub.dev | BSD-3-Clause |
| collection | 直接 | pub.dev | BSD-3-Clause |
| connectivity_plus | 直接 | pub.dev | BSD-3-Clause |
| connectivity_plus_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| convert | 间接 | pub.dev | BSD-3-Clause |
| cookie_jar | 直接 | pub.dev | MIT |
| cross_file | 间接 | pub.dev | BSD-3-Clause |
| crypto | 直接 | pub.dev | BSD-3-Clause |
| csslib | 间接 | pub.dev | BSD-3-Clause |
| cupertino_ui | 直接 | pub.dev | BSD-3-Clause |
| dart_style | 间接 | pub.dev | BSD-3-Clause |
| dbus | 间接 | pub.dev | MPL-2.0 |
| device_info_plus | 直接 | pub.dev | BSD-3-Clause |
| device_info_plus_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| dio | 直接 | pub.dev | MIT |
| dio_http2_adapter | 直接 | pub.dev | MIT |
| dio_web_adapter | 间接 | pub.dev | MIT |
| dlna_dart | 直接 | pub.dev | BSD-3-Clause |
| dynamic_color | 直接 | pub.dev | Apache-2.0 |
| easy_debounce | 直接 | pub.dev | MIT |
| encrypt | 直接 | pub.dev | BSD-3-Clause |
| equatable | 间接 | pub.dev | MIT |
| extended_nested_scroll_view | 直接 | GitHub | MIT |
| fake_async | 间接 | pub.dev | Apache-2.0 |
| ffi | 直接 | pub.dev | BSD-3-Clause |
| ffi_leak_tracker | 间接 | pub.dev | BSD-3-Clause |
| file | 间接 | pub.dev | BSD-3-Clause |
| file_picker | 直接 | pub.dev | MIT |
| file_picker_darwin | 间接 | pub.dev | MIT |
| file_picker_linux | 间接 | pub.dev | MIT |
| file_picker_platform_interface | 间接 | pub.dev | MIT |
| file_picker_web | 间接 | pub.dev | MIT |
| file_selector_linux | 间接 | pub.dev | BSD-3-Clause |
| file_selector_macos | 间接 | pub.dev | BSD-3-Clause |
| file_selector_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| file_selector_windows | 间接 | pub.dev | BSD-3-Clause |
| fixnum | 直接 | pub.dev | BSD-3-Clause |
| fl_chart | 直接 | pub.dev | MIT |
| flex_seed_scheme | 直接 | pub.dev | BSD-3-Clause |
| flutter | 直接 | Flutter SDK | BSD-3-Clause |
| flutter_displaymode | 直接 | pub.dev | MIT |
| flutter_html | 直接 | GitHub | MIT |
| flutter_inappwebview | 直接 | pub.dev | Apache-2.0 |
| flutter_inappwebview_android | 覆盖 | GitHub | Apache-2.0 |
| flutter_inappwebview_internal_annotations | 间接 | pub.dev | Apache-2.0 |
| flutter_inappwebview_ios | 间接 | pub.dev | Apache-2.0 |
| flutter_inappwebview_macos | 间接 | pub.dev | Apache-2.0 |
| flutter_inappwebview_platform_interface | 间接 | pub.dev | Apache-2.0 |
| flutter_inappwebview_web | 间接 | pub.dev | Apache-2.0 |
| flutter_inappwebview_windows | 覆盖 | GitHub | Apache-2.0 |
| flutter_launcher_icons | 开发 | pub.dev | MIT |
| flutter_lints | 开发 | pub.dev | BSD-3-Clause |
| flutter_localizations | 直接 | Flutter SDK | BSD-3-Clause |
| flutter_native_splash | 开发 | pub.dev | MIT |
| flutter_plugin_android_lifecycle | 间接 | pub.dev | BSD-3-Clause |
| flutter_smart_dialog | 直接 | GitHub | MIT |
| flutter_sortable_wrap | 直接 | GitHub | MIT |
| flutter_staggered_grid_view | 直接 | pub.dev | MIT |
| flutter_svg | 直接 | pub.dev | MIT |
| flutter_test | 开发 | Flutter SDK | BSD-3-Clause |
| flutter_volume_controller | 直接 | pub.dev | MIT |
| flutter_web_plugins | 间接 | Flutter SDK | BSD-3-Clause |
| font_awesome_flutter | 直接 | GitHub | MIT |
| get | 直接 | GitHub | MIT |
| glob | 间接 | pub.dev | BSD-3-Clause |
| graphs | 间接 | pub.dev | BSD-3-Clause |
| hive_ce | 直接 | pub.dev | Apache-2.0 + BSD-3-Clause |
| hooks | 间接 | pub.dev | BSD-3-Clause |
| html | 直接 | pub.dev | MIT |
| http | 间接 | pub.dev | BSD-3-Clause |
| http2 | 直接 | pub.dev | BSD-3-Clause |
| http_multi_server | 间接 | pub.dev | BSD-3-Clause |
| http_parser | 间接 | pub.dev | BSD-3-Clause |
| image | 间接 | pub.dev | MIT |
| image_cropper | 直接 | pub.dev | BSD-3-Clause |
| image_cropper_for_web | 间接 | pub.dev | BSD-3-Clause |
| image_cropper_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| image_picker | 直接 | pub.dev | Apache-2.0 + BSD-3-Clause |
| image_picker_android | 间接 | pub.dev | Apache-2.0 + BSD-3-Clause |
| image_picker_for_web | 间接 | pub.dev | BSD-3-Clause |
| image_picker_ios | 间接 | pub.dev | Apache-2.0 + BSD-3-Clause |
| image_picker_linux | 间接 | pub.dev | BSD-3-Clause |
| image_picker_macos | 间接 | pub.dev | BSD-3-Clause |
| image_picker_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| image_picker_windows | 间接 | pub.dev | BSD-3-Clause |
| intl | 直接 | pub.dev | BSD-3-Clause |
| io | 间接 | pub.dev | BSD-3-Clause |
| isolate_channel | 间接 | pub.dev | BSD-3-Clause |
| jni | 直接 | pub.dev | BSD-3-Clause |
| jni_flutter | 间接 | pub.dev | BSD-3-Clause |
| jni_util | 间接 | pub.dev | BSD-3-Clause |
| jnigen | 开发 | pub.dev | BSD-3-Clause |
| js | 间接 | pub.dev | BSD-3-Clause |
| json_annotation | 直接 | pub.dev | BSD-3-Clause |
| leak_tracker | 间接 | pub.dev | BSD-3-Clause |
| leak_tracker_flutter_testing | 间接 | pub.dev | BSD-3-Clause |
| leak_tracker_testing | 间接 | pub.dev | BSD-3-Clause |
| lints | 间接 | pub.dev | BSD-3-Clause |
| list_counter | 间接 | pub.dev | MIT |
| live_photo_maker | 直接 | pub.dev | MIT |
| logger | 直接 | pub.dev | MIT |
| logging | 间接 | pub.dev | BSD-3-Clause |
| matcher | 间接 | pub.dev | BSD-3-Clause |
| material_color_utilities | 直接 | pub.dev | Apache-2.0 |
| material_design_icons_flutter | 直接 | GitHub | MIT |
| material_new_shapes | 直接 | pub.dev | MIT |
| material_ui | 直接 | pub.dev | BSD-3-Clause |
| media_kit | 直接 | GitHub | MIT |
| media_kit_libs_android_video | 覆盖 | GitHub | MIT |
| media_kit_libs_ios_video | 覆盖 | GitHub | MIT |
| media_kit_libs_linux | 间接 | pub.dev | MIT |
| media_kit_libs_macos_video | 间接 | pub.dev | MIT |
| media_kit_libs_video | 直接 | GitHub | MIT |
| media_kit_libs_windows_video | 覆盖 | GitHub | MIT |
| media_kit_native_event_loop | 覆盖 | GitHub | MIT |
| media_kit_video | 直接 | GitHub | MIT |
| meta | 间接 | pub.dev | BSD-3-Clause |
| mime | 直接 | pub.dev | BSD-3-Clause |
| native_device_orientation | 直接 | GitHub | MIT |
| native_toolchain_c | 间接 | pub.dev | BSD-3-Clause |
| nativeapi | 直接 | pub.dev | MIT |
| nativeapi_flutter | 间接 | pub.dev | MIT |
| nm | 间接 | pub.dev | MPL-2.0 |
| objective_c | 间接 | pub.dev | BSD-3-Clause |
| octo_image | 间接 | GitHub | MIT |
| package_config | 间接 | pub.dev | BSD-3-Clause |
| package_info_plus | 直接 | pub.dev | BSD-3-Clause |
| package_info_plus_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| path | 直接 | pub.dev | BSD-3-Clause |
| path_parsing | 间接 | pub.dev | MIT |
| path_provider | 直接 | pub.dev | BSD-3-Clause |
| path_provider_android | 间接 | pub.dev | BSD-3-Clause |
| path_provider_foundation | 间接 | pub.dev | BSD-3-Clause |
| path_provider_linux | 间接 | pub.dev | BSD-3-Clause |
| path_provider_platform_interface | 直接 | pub.dev | BSD-3-Clause |
| path_provider_windows | 间接 | pub.dev | BSD-3-Clause |
| permission_handler_android | 直接 | pub.dev | MIT |
| permission_handler_apple | 直接 | pub.dev | MIT |
| permission_handler_platform_interface | 直接 | pub.dev | MIT |
| petitparser | 间接 | pub.dev | MIT |
| platform | 间接 | pub.dev | BSD-3-Clause |
| plugin_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| pointycastle | 间接 | pub.dev | MIT |
| pool | 间接 | pub.dev | BSD-3-Clause |
| posix | 间接 | pub.dev | MIT |
| pretty_qr_code | 直接 | pub.dev | MIT |
| process | 间接 | pub.dev | BSD-3-Clause |
| protobuf | 直接 | pub.dev | BSD-3-Clause |
| pub_semver | 间接 | pub.dev | BSD-3-Clause |
| pubspec_parse | 间接 | pub.dev | BSD-3-Clause |
| qr | 间接 | pub.dev | BSD-3-Clause |
| re_highlight | 直接 | pub.dev | MIT |
| record_use | 间接 | pub.dev | BSD-3-Clause |
| rxdart | 间接 | pub.dev | Apache-2.0 |
| saver_gallery | 直接 | pub.dev | MIT |
| screen_brightness_android | 间接 | pub.dev | MIT |
| screen_brightness_ios | 间接 | pub.dev | MIT |
| screen_brightness_platform_interface | 直接 | pub.dev | MIT |
| screen_retriever | 直接 | pub.dev | MIT |
| share_plus | 直接 | pub.dev | BSD-3-Clause |
| share_plus_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| shared_preferences | 间接 | pub.dev | BSD-3-Clause |
| shared_preferences_android | 间接 | pub.dev | BSD-3-Clause |
| shared_preferences_foundation | 间接 | pub.dev | BSD-3-Clause |
| shared_preferences_linux | 间接 | pub.dev | BSD-3-Clause |
| shared_preferences_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| shared_preferences_web | 间接 | pub.dev | BSD-3-Clause |
| shared_preferences_windows | 间接 | pub.dev | BSD-3-Clause |
| shelf | 间接 | pub.dev | BSD-3-Clause |
| shelf_web_socket | 间接 | pub.dev | BSD-3-Clause |
| sky_engine | 间接 | Flutter SDK | BSD-3-Clause |
| source_span | 间接 | pub.dev | BSD-3-Clause |
| stack_trace | 间接 | pub.dev | BSD-3-Clause |
| stream_channel | 间接 | pub.dev | BSD-3-Clause |
| stream_transform | 直接 | pub.dev | BSD-3-Clause |
| string_scanner | 间接 | pub.dev | BSD-3-Clause |
| super_sliver_list | 直接 | GitHub | MIT |
| synchronized | 直接 | pub.dev | MIT |
| term_glyph | 间接 | pub.dev | BSD-3-Clause |
| test_api | 间接 | pub.dev | BSD-3-Clause |
| tray_manager | 直接 | pub.dev | MIT |
| typed_data | 间接 | pub.dev | BSD-3-Clause |
| universal_io | 间接 | pub.dev | Apache-2.0 |
| upower | 间接 | pub.dev | MPL-2.0 |
| url_launcher | 直接 | pub.dev | BSD-3-Clause |
| url_launcher_android | 间接 | pub.dev | BSD-3-Clause |
| url_launcher_ios | 间接 | pub.dev | BSD-3-Clause |
| url_launcher_linux | 间接 | pub.dev | BSD-3-Clause |
| url_launcher_macos | 间接 | pub.dev | BSD-3-Clause |
| url_launcher_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| url_launcher_web | 间接 | pub.dev | BSD-3-Clause |
| url_launcher_windows | 间接 | pub.dev | BSD-3-Clause |
| uuid | 直接 | pub.dev | MIT |
| vector_graphics | 间接 | pub.dev | BSD-3-Clause |
| vector_graphics_codec | 间接 | pub.dev | BSD-3-Clause |
| vector_graphics_compiler | 间接 | pub.dev | BSD-3-Clause |
| vector_math | 直接 | pub.dev | BSD-3-Clause |
| vm_service | 间接 | pub.dev | BSD-3-Clause |
| wakelock_plus | 直接 | pub.dev | BSD-3-Clause |
| wakelock_plus_platform_interface | 间接 | pub.dev | BSD-3-Clause |
| watcher | 间接 | pub.dev | BSD-3-Clause |
| web | 间接 | pub.dev | BSD-3-Clause |
| web_socket | 间接 | pub.dev | BSD-3-Clause |
| web_socket_channel | 直接 | pub.dev | BSD-3-Clause |
| webdav_client | 直接 | GitHub | BSD-3-Clause |
| win32 | 直接 | pub.dev | BSD-3-Clause |
| win32_registry | 间接 | pub.dev | BSD-3-Clause |
| window_manager | 直接 | GitHub | MIT |
| windows_file_picker | 间接 | pub.dev | MIT |
| xdg_directories | 间接 | pub.dev | BSD-3-Clause |
| xml | 间接 | pub.dev | MIT |
| yaml | 间接 | pub.dev | MIT |

</details>
