import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:solitaire/model/background.dart';
import 'package:solitaire/model/card_back.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/utils/iterable_extensions.dart';
import 'package:solitaire/widgets/themed_sheet.dart';

class CustomizationDialog {
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
          if (saveState == null) {
            return SizedBox.shrink();
          }

          Widget buildSection({
            required String title,
            String? description,
            required Widget child,
          }) {
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sheetTileColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null) ...[
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  SizedBox(height: 12),
                  child,
                ],
              ),
            );
          }

          final navigator = Navigator.of(sheetContext);

          return ThemedSheet(
            title: 'Customization',
            subtitle: 'Personalize your table and deck.',
            child: Column(
              children: [
                buildSection(
                  title: 'Table Background',
                  description: 'Change the vibe of the playing surface.',
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 420),
                    child: Row(
                      spacing: 12,
                      children: Background.values
                          .map(
                            (background) => Expanded(
                              child: _customizationSquare(
                                context,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: background.build(),
                                ),
                                onPressed: () => ref
                                    .read(saveStateNotifierProvider.notifier)
                                    .saveBackground(background: background),
                                selected: background == saveState.background,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                buildSection(
                  title: 'Card Backs',
                  description: 'Unlock alternates by earning achievements.',
                  child: Column(
                    spacing: 12,
                    children: CardBack.values
                        .batch(4)
                        .map(
                          (row) => Row(
                            spacing: 12,
                            children: row.map((cardBack) {
                              final locked = cardBack.achievementLock != null &&
                                  !saveState.achievements
                                      .contains(cardBack.achievementLock!);
                              return Expanded(
                                child: HookBuilder(
                                  builder: (context) {
                                    final tooltipKey = useMemoized(
                                      () => GlobalKey<TooltipState>(),
                                    );
                                    return _customizationSquare(
                                      context,
                                      onPressed: locked
                                          ? () => tooltipKey.currentState
                                              ?.ensureTooltipVisible()
                                          : () => ref
                                              .read(saveStateNotifierProvider
                                                  .notifier)
                                              .saveCardBack(cardBack: cardBack),
                                      selected: cardBack == saveState.cardBack,
                                      child: locked
                                          ? Tooltip(
                                              key: tooltipKey,
                                              message:
                                                  'Unlocked with the "${cardBack.achievementLock!.name}" achievement.',
                                              child: ColoredBox(
                                                color: Colors.white24,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.lock,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: cardBack.build(),
                                            ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => navigator.pop(),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _customizationSquare(
  BuildContext context, {
  required Widget child,
  required Function() onPressed,
  required bool selected,
}) {
  final borderRadius = BorderRadius.circular(16);
  final highlightColor = selected ? Color(0xFFFFD700) : Colors.white24;

  return AnimatedContainer(
    duration: Duration(milliseconds: 180),
    decoration: BoxDecoration(
      borderRadius: borderRadius,
      border: Border.all(
        color: highlightColor,
        width: selected ? 2.4 : 1.2,
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: highlightColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ]
          : [],
    ),
    child: ClipRRect(
      borderRadius: borderRadius.subtract(BorderRadius.circular(2)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: AspectRatio(
            aspectRatio: 1,
            child: child,
          ),
        ),
      ),
    ),
  );
}
