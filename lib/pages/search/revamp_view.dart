part of 'view.dart';

/// The search page opened from the liquid glass dock. Kept apart from
/// view.dart so that file stays close to upstream.
extension _SearchRevamp on _SearchPageState {
  /// Search opened from the liquid glass dock: the field sits at the bottom,
  /// right where the dock grew it, and the sections float up above it.
  bool get _dockSearch =>
      Get.isRegistered<MainController>() &&
      Get.find<MainController>().dockSearch;

  static const _dockHeight = 64.0;
  static const _dockEdge = 16.0;
  static const _dockGap = 10.0;

  Widget _buildDockLayout({Widget? trending, Widget? rcmd}) {
    final colorScheme = theme.colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    // above the keyboard when it is up, otherwise where the dock was
    final dockBottom =
        (viewInsets.bottom > 0 ? viewInsets.bottom : padding.bottom) + 8;

    Widget section(Widget sliver) => SliverPadding(
      padding: const .fromLTRB(12, 0, 12, 12),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: const .all(.circular(24)),
        ),
        sliver: sliver,
      ),
    );

    final content = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: .fromLTRB(24, padding.top + 16, 24, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              '搜索',
              style: theme.textTheme.headlineMedium!.copyWith(
                fontWeight: .w900,
              ),
            ),
          ),
        ),
        if (_searchController.searchSuggestion) section(_buildSearchSuggest()),
        if (trending != null) section(trending),
        section(_buildHistory),
        if (rcmd != null) section(rcmd),
        SliverPadding(
          padding: .only(bottom: dockBottom + _dockHeight + 16),
        ),
      ],
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // the sections rise into place as the page fades in
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Transform.translate(
                offset: Offset(0, (1 - t) * 48),
                child: child,
              ),
              child: Padding(
                padding: .only(left: padding.left, right: padding.right),
                child: content,
              ),
            ),
          ),
          Positioned(
            left: padding.left + _dockEdge,
            right: padding.right + _dockEdge,
            bottom: dockBottom,
            height: _dockHeight,
            child: Row(
              spacing: _dockGap,
              children: [
                _glassCapsule(
                  width: _dockHeight,
                  onTap: Get.back,
                  semanticLabel: '返回',
                  child: Icon(
                    Icons.close_rounded,
                    size: 26,
                    color: colorScheme.onSurface,
                  ),
                ),
                Expanded(child: _glassCapsule(child: _dockField())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCapsule({
    required Widget child,
    double? width,
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    const radius = Radius.circular(_dockHeight / 2);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == .dark;
    Widget result = CustomPaint(
      painter: GlassShadowPainter(
        radius: radius,
        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
      ),
      foregroundPainter: GlassRimPainter(
        radius: radius,
        opacity: 0.75,
        isDark: isDark,
      ),
      child: LiquidGlass(
        blurSigma: 3,
        refractionHeight: 20,
        refractionAmount: 20,
        saturation: 1.5,
        color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
        child: Center(child: child),
      ),
    );
    if (onTap != null) {
      result = Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: GestureDetector(onTap: onTap, child: result),
      );
    }
    return width == null ? result : SizedBox(width: width, child: result);
  }

  Widget _dockField() {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const .only(left: (_dockHeight - 24) / 2, right: 6),
      child: Row(
        spacing: 10,
        children: [
          Icon(Icons.search, size: 24, color: colorScheme.onSurface),
          Expanded(
            child: TextField(
              autofocus: true,
              focusNode: _searchController.searchFocusNode,
              controller: _searchController.controller,
              textInputAction: TextInputAction.search,
              onChanged: _searchController.onChange,
              onSubmitted: (_) => _searchController.submit(),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: _searchController.hintText ?? '搜索视频、番剧、UP 主',
                border: InputBorder.none,
              ),
            ),
          ),
          Obx(
            () => _searchController.showUidBtn.value
                ? IconButton(
                    tooltip: 'UID搜索用户',
                    icon: const Icon(Icons.person_outline, size: 22),
                    onPressed: () => Get.toNamed(
                      '/member?mid=${_searchController.controller.text}',
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          ListenableBuilder(
            listenable: _searchController.controller,
            builder: (context, _) => _searchController.controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '清空',
                    icon: const Icon(Icons.cancel_rounded, size: 22),
                    color: colorScheme.outline,
                    onPressed: _searchController.onClear,
                  ),
          ),
        ],
      ),
    );
  }
}
