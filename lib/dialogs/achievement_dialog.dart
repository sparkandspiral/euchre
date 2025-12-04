import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:solitaire/model/achievement.dart';
import 'package:solitaire/model/card_back.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/services/achievement_service.dart';
import 'package:solitaire/widgets/themed_sheet.dart';

class AchievementDialog {
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Consumer(
            builder: (context, ref, child) {
              final saveState =
                  ref.watch(saveStateNotifierProvider).valueOrNull;
              if (saveState == null) {
                return SizedBox.shrink();
              }

              final navigator = Navigator.of(sheetContext);
              final unlocked = saveState.achievements.length;
              final total = Achievement.values.length;

              return ThemedSheet(
                title: 'Achievements',
                subtitle: '$unlocked / $total unlocked',
                scrollController: scrollController,
                child: Column(
                  children: [
                    ...Achievement.values.map(
                      (achievement) => HookBuilder(
                        builder: (context) {
                          final tapsState = useState(0);
                          final isUnlocked =
                              saveState.achievements.contains(achievement);
                          final (int?, int?) progress = (
                            achievement.getCurrentProgress(saveState: saveState),
                            achievement.getProgressMax(),
                          );
                          int? currentProgress;
                          int? maxProgress;
                          double? completion;

                          if (progress case (final current?, final max?)) {
                            currentProgress = current;
                            maxProgress = max;
                            if (max != 0) {
                              completion = current / max;
                            }
                          }

                          return GestureDetector(
                            onTap: () {
                              tapsState.value += 1;
                              if (tapsState.value == 10 && isUnlocked) {
                                ref
                                    .read(achievementServiceProvider)
                                    .deleteAchievement(achievement);
                              }
                            },
                            child: Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: sheetTileColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isUnlocked
                                      ? Colors.greenAccent.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox.square(
                                      dimension: 56,
                                      child: isUnlocked
                                          ? CardBack.values
                                              .firstWhere((back) =>
                                                  back.achievementLock ==
                                                  achievement)
                                              .build()
                                          : LayoutBuilder(
                                              builder: (context, constraints) {
                                                return Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    ColoredBox(
                                                      color: Colors.white24,
                                                      child: Icon(
                                                        Icons.question_mark,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (completion != null)
                                                      Positioned.fill(
                                                        right: constraints
                                                                .maxWidth *
                                                            (1 - completion),
                                                        child: ColoredBox(
                                                          color: Colors.black
                                                              .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                achievement.name,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              isUnlocked
                                                  ? Icons.check_circle
                                                  : Icons.lock_open,
                                              color: isUnlocked
                                                  ? Colors.greenAccent
                                                  : Colors.white38,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          achievement.description,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (!isUnlocked &&
                                            completion != null &&
                                            currentProgress != null &&
                                            maxProgress != null) ...[
                                          SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: completion.clamp(0, 1),
                                              minHeight: 6,
                                              backgroundColor:
                                                  Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.orangeAccent,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Progress: $currentProgress / $maxProgress',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
      },
    );
  }
}
