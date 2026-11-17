import 'dart:math';

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/season.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:material_ui/material_ui.dart';

class SeasonPanel extends StatelessWidget {
  const SeasonPanel({
    super.key,
    required this.seasons,
    required this.pgcController,
    required this.onSeasonChanged,
  });

  final List<Season> seasons;
  final PgcIntroController pgcController;
  final VoidCallback onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    final currIndex = max(
      0,
      seasons.indexWhere((e) => e.seasonId == pgcController.seasonId),
    );
    final controller = pgcController.seasonController(currIndex);
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
            final isCurr = index == currIndex;
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
                    pgcController.changeSeason(item.seasonId!).then((res) {
                      if (context.mounted && res) {
                        onSeasonChanged();
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
        itemExtent: 150,
        controller: controller,
        itemCount: seasons.length,
        scrollDirection: .horizontal,
        key: const PageStorageKey(SeasonPanel),
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final item = seasons[index];
          final isCurr = index == currIndex;
          return Container(
            width: 150,
            margin: index != seasons.length - 1 ? const .only(right: 10) : null,
            child: Material(
              color: Revamp.tile(colorScheme),
              shape: Revamp.tileShape,
              child: InkWell(
                customBorder: Revamp.tileShape,
                onTap: () {
                  if (isCurr || pgcController.changingSeason) return;
                  pgcController.changeSeason(item.seasonId!).then((res) {
                    if (context.mounted && res) {
                      onSeasonChanged();
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
