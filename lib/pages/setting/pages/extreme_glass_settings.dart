import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class ExtremeGlassPage extends StatefulWidget {
  const ExtremeGlassPage({super.key});

  @override
  State<ExtremeGlassPage> createState() => _ExtremeGlassPageState();
}

class _ExtremeGlassPageState extends State<ExtremeGlassPage> {
  static const _shellPresets = [
    (label: '默认', blur: 3.0, alpha: 0.30),
    (label: '清透', blur: 1.5, alpha: 0.15),
    (label: '晶体', blur: 0.5, alpha: 0.05),
    (label: '全透明', blur: 0.0, alpha: 0.0),
  ];

  static const _refractionPresets = [
    (label: '关闭', scale: 0.0),
    (label: '微弱', scale: 0.5),
    (label: '默认', scale: 1.0),
    (label: '强烈', scale: 1.5),
  ];

  Future<void> _apply(Future<void> Function() fn) async {
    await fn();
    if (mounted) {
      setState(() {});
    }
    Get.forceAppUpdate();
  }

  Future<void> _editNumber({
    required String title,
    required double current,
    required double min,
    required double max,
    required int decimals,
    String suffix = '',
    required Future<void> Function(double value) onSave,
  }) async {
    final controller = TextEditingController(
      text: current.toStringAsFixed(decimals),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(
            decimal: decimals > 0,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(decimals > 0 ? r'[0-9.]' : r'[0-9]'),
            ),
          ],
          decoration: InputDecoration(
            suffixText: suffix.isEmpty ? null : suffix,
            helperText:
                '范围 ${min.toStringAsFixed(decimals)} ~ ${max.toStringAsFixed(decimals)}$suffix',
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null) return;
              Navigator.of(context).pop(parsed.clamp(min, max).toDouble());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await _apply(() => onSave(result));
    }
  }

  Widget _presetRow<T>({
    required List<T> items,
    required String Function(T) label,
    required bool Function(T) isSelected,
    required Future<void> Function(T) onTap,
  }) {
    final colorScheme = ColorScheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final selected = isSelected(item);
          return Material(
            color: selected
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              onTap: () => _apply(() => onTap(item)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Text(
                  label(item),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sliderTile({
    required String title,
    String? subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required int inputDecimals,
    String inputSuffix = '',
    double inputScale = 1.0,
    required Future<void> Function(double) onChanged,
  }) {
    final colorScheme = ColorScheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: UiType.body),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: UiType.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  onTap: () => _editNumber(
                    title: title,
                    current: value * inputScale,
                    min: min * inputScale,
                    max: max * inputScale,
                    decimals: inputDecimals,
                    suffix: inputSuffix,
                    onSave: (v) => onChanged(v / inputScale),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Text(
                          displayValue,
                          style: UiType.caption.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => _apply(() => onChanged(v)),
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: UiType.body),
      subtitle: Text(
        subtitle,
        style: UiType.caption.copyWith(
          color: ColorScheme.of(context).onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: (v) => _apply(() => onChanged(v)),
    );
  }

  Widget _group(String label, List<Widget> children) {
    if (!Revamp.enabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          ...children,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RevampGroupLabel(label),
        RevampGroup(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: revampDivided(children)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final notRunningExtreme = UiGlass.level != UiGlassLevel.extreme;

    final groups = [
      if (notRunningExtreme)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Material(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                spacing: 10,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  Expanded(
                    child: Text(
                      '当前生效的透明效果为「${UiGlass.level.label}」，请确保「透明效果」已设为「极致」并重启应用后生效。',
                      style: UiType.caption.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      _group('壳体透明与模糊（底栏 / 顶栏 / 搜索框 / 悬浮按钮）', [
        _presetRow(
          items: _shellPresets,
          label: (p) => '${p.label} (${p.blur} · ${(p.alpha * 100).round()}%)',
          isSelected: (p) =>
              (UiGlass.extremeShellBlur - p.blur).abs() < 0.05 &&
              (UiGlass.extremeShellAlpha - p.alpha).abs() < 0.015,
          onTap: (p) async {
            await UiGlass.setExtremeShellBlur(p.blur);
            await UiGlass.setExtremeShellAlpha(p.alpha);
          },
        ),
        _sliderTile(
          title: '壳体模糊强度',
          subtitle: '0 为完全无模糊纯透，3.0 为原版极致轻模糊',
          value: UiGlass.extremeShellBlur,
          min: 0.0,
          max: 6.0,
          divisions: 60,
          displayValue: UiGlass.extremeShellBlur.toStringAsFixed(1),
          inputDecimals: 1,
          onChanged: UiGlass.setExtremeShellBlur,
        ),
        _sliderTile(
          title: '壳体遮罩不透明度',
          subtitle: '0% 为纯透明玻璃，30% 为原版极致白雾底色',
          value: UiGlass.extremeShellAlpha,
          min: 0.0,
          max: 0.60,
          divisions: 60,
          displayValue: '${(UiGlass.extremeShellAlpha * 100).round()}%',
          inputDecimals: 0,
          inputSuffix: '%',
          inputScale: 100.0,
          onChanged: UiGlass.setExtremeShellAlpha,
        ),
        _switchTile(
          title: '顶栏圆按钮跟随壳体透明',
          subtitle: '开启后顶部返回、消息等圆形玻璃按钮同步采用上方壳体参数（关闭时维持 66% 面板浓度）',
          value: UiGlass.extremeRoundBtnFollowsShell,
          onChanged: UiGlass.setExtremeRoundBtnFollowsShell,
        ),
      ]),
      _group('液态玻璃折射范围与强度', [
        _presetRow(
          items: _refractionPresets,
          label: (p) => '${p.label} ${p.scale.toStringAsFixed(1)}x',
          isSelected: (p) =>
              (UiGlass.extremeRefractionScale - p.scale).abs() < 0.05,
          onTap: (p) => UiGlass.setExtremeRefractionScale(p.scale),
        ),
        _sliderTile(
          title: '折射范围 / 弯曲倍率',
          subtitle:
              '等比缩放边缘折射宽度（uRefractionHeight）与边缘拉伸强度（uRefractionAmount）',
          value: UiGlass.extremeRefractionScale,
          min: 0.0,
          max: 2.0,
          divisions: 40,
          displayValue: '${UiGlass.extremeRefractionScale.toStringAsFixed(2)}x',
          inputDecimals: 2,
          inputSuffix: 'x',
          onChanged: UiGlass.setExtremeRefractionScale,
        ),
      ]),
      _group('弹出菜单（... 菜单）', [
        _switchTile(
          title: '菜单高透（跟随壳体透明与模糊）',
          subtitle: '开启后弹出菜单同步使用上方壳体透明度与模糊度；关闭则维持 54% 雾面与 16 模糊以保证文字清晰',
          value: UiGlass.extremeMenuClear,
          onChanged: UiGlass.setExtremeMenuClear,
        ),
        _switchTile(
          title: '菜单边缘折射',
          subtitle: '开启或关闭弹出菜单边缘的液态玻璃弯曲效果',
          value: UiGlass.extremeMenuRefraction,
          onChanged: UiGlass.setExtremeMenuRefraction,
        ),
      ]),
      _group('上拉面板（评论区 / 收藏 / 发布动态 / 播放底页）', [
        _switchTile(
          title: '上拉面板高透（跟随壳体透明与模糊）',
          subtitle: '开启后评论区与各类底部上拉面板统一采用上方壳体透明度与模糊度；关闭则维持 66% 磨砂与 16 模糊',
          value: UiGlass.extremeSheetClear,
          onChanged: UiGlass.setExtremeSheetClear,
        ),
        _switchTile(
          title: '小型浮卡边缘折射',
          subtitle: '控制 GlassBox 小浮卡的边缘折射；评论区等大面积上拉面板为保障流畅度仅使用单次静态模糊截图',
          value: UiGlass.extremeSheetRefraction,
          onChanged: UiGlass.setExtremeSheetRefraction,
        ),
      ]),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, padding.bottom + 40),
        child: Center(
          child: FilledButton.tonalIcon(
            onPressed: () => _apply(UiGlass.resetExtremeDefaults),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('恢复「极致」默认参数'),
          ),
        ),
      ),
    ];

    if (!Revamp.enabled) {
      return SimpleScaffold(
        appBar: AppBar(title: const Text('极致液态玻璃微调')),
        body: ListView(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          children: groups,
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const RevampLargeAppBar(title: '极致液态玻璃微调', implyLeading: true),
          SliverPadding(
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            sliver: SliverList.list(children: groups),
          ),
        ],
      ),
    );
  }
}
