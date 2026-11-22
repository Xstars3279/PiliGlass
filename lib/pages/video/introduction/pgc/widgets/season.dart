import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/utils/scroll_offset_helper.dart';
import 'package:material_ui/material_ui.dart';

class SeasonPanel extends StatelessWidget {
  const SeasonPanel({
    super.key,
    required this.pgcController,
    required this.onSeasonChanged,
  });

  final VoidCallback onSeasonChanged;
  final PgcIntroController pgcController;

  ScrollController get _scrollController {
    if (pgcController.seasonController != null) {
      return pgcController.seasonController!;
    }
    if (pgcController.seasonIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback(_jumpToCurrent);
    }
    return pgcController.seasonController = ScrollController(
      keepScrollOffset: false,
    );
  }

  void _jumpToCurrent([_, bool anim = false]) {
    final position = pgcController.seasonController!.position;
    final scrollOffset = calcPageItemOffset(
      index: pgcController.seasonIndex,
      itemCount: pgcController.pgcItem.seasons!.length,
      // the redesign's chips are as wide as their text: about 96 each, near
      // enough to bring the chosen one into view
      extent: Revamp.enabled ? 96 : kPageItemExtent,
      viewportDimension: position.viewportDimension,
    );
    if (anim) {
      position.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      position.jumpTo(scrollOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seasons = pgcController.pgcItem.seasons!;
    final controller = _scrollController;
    final colorScheme = ColorScheme.of(context);
    if (Revamp.enabled) {
      // a capsule as wide as its title, 36 high, the chosen one tonal (6.7)
      return SizedBox(
        height: 36,
        child: ListView.builder(
          padding: .zero,
          controller: controller,
          itemCount: seasons.length,
          scrollDirection: .horizontal,
          key: const PageStorageKey(SeasonPanel),
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = seasons[index];
            final isCurr = index == pgcController.seasonIndex;
            return Padding(
              padding: const .only(right: UiSpace.s8),
              child: Material(
                color: isCurr
                    ? colorScheme.secondaryContainer
                    : colorScheme.surfaceContainerLow,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    if (isCurr || pgcController.changingSeason) return;
                    pgcController.changeSeason(item.seasonId!, index).then((
                      res,
                    ) {
                      if (context.mounted && res) {
                        onSeasonChanged();
                        _jumpToCurrent(null, true);
                      }
                    });
                  },
                  child: Padding(
                    padding: const .symmetric(horizontal: UiSpace.s16),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        item.seasonTitle!,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: UiType.caption.copyWith(
                          fontWeight: isCurr
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: isCurr
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return SizedBox(
      height: 35,
      child: ListView.builder(
        padding: .zero,
        itemExtent: kPageItemExtent,
        controller: controller,
        itemCount: seasons.length,
        scrollDirection: .horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final item = seasons[index];
          final isCurr = index == pgcController.seasonIndex;
          return Container(
            width: kPageItemExtent,
            margin: index != seasons.length - 1 ? const .only(right: 10) : null,
            child: Material(
              color: Revamp.tile(colorScheme),
              shape: Revamp.tileShape,
              child: InkWell(
                customBorder: Revamp.tileShape,
                onTap: () {
                  if (isCurr || pgcController.changingSeason) return;
                  pgcController.changeSeason(item.seasonId!, index).then((res) {
                    if (context.mounted && res) {
                      onSeasonChanged();
                      _jumpToCurrent(null, true);
                    }
                  });
                },
                child: Padding(
                  padding: const .symmetric(horizontal: 8),
                  child: Align(
                    alignment: .centerLeft,
                    child: Text(
                      item.seasonTitle!,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: TextStyle(
                        height: 1,
                        fontSize: 13,
                        color: isCurr
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      strutStyle: const .new(height: 1, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
