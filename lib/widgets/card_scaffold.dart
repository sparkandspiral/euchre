import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:solitaire/context/card_game_context.dart';
import 'package:solitaire/home_page.dart';
import 'package:solitaire/model/card_back.dart';
import 'package:solitaire/model/daily_challenge.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/hint.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/services/achievement_service.dart';
import 'package:solitaire/services/audio_service.dart';
import 'package:solitaire/services/daily_challenge_service.dart';
import 'package:solitaire/services/ad_service.dart';
import 'package:solitaire/services/rewarded_ad_service.dart';
import 'package:solitaire/utils/build_context_extensions.dart';
import 'package:solitaire/utils/constraints_extensions.dart';
import 'package:solitaire/utils/duration_extensions.dart';
import 'package:utils/utils.dart';
import 'package:solitaire/widgets/themed_sheet.dart';
import 'package:solitaire/widgets/daily_leaderboard_sheet.dart';

class CardScaffold extends HookConsumerWidget {
  final Game game;
  final Difficulty difficulty;

  final Widget Function(BuildContext, BoxConstraints, CardBack,
      bool autoMoveEnabled, Object gameKey) builder;

  final Function() onNewGame;
  final Function() onRestart;
  final Function() onTutorial;
  final Function()? onUndo;
  final FutureOr<HintSuggestion?> Function()? onHint;

  final FutureOr<void> Function(BuildContext context, Duration duration)?
      onVictory;
  final bool isVictory;
  final DailyChallengeConfig? dailyChallenge;
  final Duration initialElapsed;
  final bool disableAds;

  const CardScaffold({
    super.key,
    required this.game,
    required this.difficulty,
    required this.builder,
    required this.onNewGame,
    required this.onRestart,
    required this.onTutorial,
    required this.onUndo,
    this.onHint,
    this.onVictory,
    this.isVictory = false,
    this.dailyChallenge,
    this.initialElapsed = Duration.zero,
    this.disableAds = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardGameContext = context.watch<CardGameContext?>();
    final isPreview = cardGameContext?.isPreview ?? false;

    final isHintProcessing = useState(false);
    final startTimeState =
        useState(DateTime.now().subtract(initialElapsed));
    final currentTimeState = useState(DateTime.now());

    final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
    final difficultyGameState = saveState?.gameStates[game]?.states[difficulty];

    useEffect(() {
      if (isVictory) {
        final duration =
            currentTimeState.value.difference(startTimeState.value);
        () async {
          ref.read(audioServiceProvider).playWin();
          await onVictory?.call(context, duration);
          if (!context.mounted) return;
          await ref.read(saveStateNotifierProvider.notifier).saveGameCompleted(
                game: game,
                difficulty: difficulty,
                duration: duration,
              );
          if (!context.mounted) return;
          await ref
              .read(achievementServiceProvider)
              .checkGameCompletionAchievements(
                game: game,
                difficulty: difficulty,
                duration: duration,
              );
          if (dailyChallenge != null) {
            if (!context.mounted) return;
            await ref.read(dailyChallengeServiceProvider).handleVictory(
                  context: context,
                  game: game,
                  config: dailyChallenge!,
                  duration: duration,
                );
          }
          if (!disableAds) {
            await ref.read(adServiceProvider).maybeShowAfterGame();
          }
        }();
      }
      return null;
    }, [isVictory]);

    useEffect(() {
      if (!isPreview) ref.read(audioServiceProvider).playRedraw();
      return null;
    }, [startTimeState.value]);

    useListen(useMemoized(
      () => Stream.periodic(
        Duration(milliseconds: 480),
        (_) {
          if (!isVictory && !isPreview) {
            currentTimeState.value = DateTime.now();
          }
        },
      ),
      [isVictory],
    ));

    final confettiController = useMemoized(
        () => ConfettiController(duration: Duration(milliseconds: 50))..play());
    useEffect(() => () => confettiController.dispose(), []);

    if (isVictory) {
      confettiController.play();
    } else {
      confettiController.stop();
    }

    void startNewGame() {
      startTimeState.value = DateTime.now();
      onNewGame();
      ref.read(saveStateNotifierProvider.notifier).saveGameCloseOrRestart();
    }

    void restartGame() {
      startTimeState.value = DateTime.now();
      onRestart();
      ref.read(saveStateNotifierProvider.notifier).saveGameCloseOrRestart();
    }

    void closeGame() {
      ref.read(saveStateNotifierProvider.notifier).saveGameCloseOrRestart();
      context.pushReplacement(() => HomePage());
    }

    Future<void> openMenu() async {
      if (!context.mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _InGameMenuSheet(
          gameTitle: game.title,
          isDailyChallenge: dailyChallenge != null,
          onTutorial: () {
            Navigator.of(sheetContext).pop();
            onTutorial();
          },
          onNewGame: () {
            Navigator.of(sheetContext).pop();
            startNewGame();
          },
          onRestart: () {
            Navigator.of(sheetContext).pop();
            restartGame();
          },
          onClose: () {
            Navigator.of(sheetContext).pop();
            closeGame();
          },
        ),
      );
    }

    Future<bool> promptForHintRefill() async {
      if (!context.mounted) return false;

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Out of hints'),
          content: Text(
            'Watch a rewarded ad to earn $hintRewardAmount more hints?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Watch ad'),
            ),
          ],
        ),
      );

      return result ?? false;
    }

    Future<void> handleHintPressed() async {
      if (onHint == null || isPreview || isVictory || isHintProcessing.value) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      isHintProcessing.value = true;
      try {
        final latestSaveState = ref.read(saveStateNotifierProvider);
        final hintsAvailable = latestSaveState.valueOrNull?.hints ?? 0;

        if (hintsAvailable <= 0) {
          final shouldWatchAd = await promptForHintRefill();
          if (!shouldWatchAd) {
            return;
          }
          if (!context.mounted) return;

          try {
            final rewarded =
                await ref.read(rewardedAdServiceProvider).showRewardedAd(context);
            if (rewarded) {
              await ref
                  .read(saveStateNotifierProvider.notifier)
                  .addHints(hintRewardAmount);
              if (!context.mounted) return;
              messenger?.showSnackBar(
                SnackBar(
                  content: Text('You earned $hintRewardAmount additional hints.'),
                ),
              );
            }
          } catch (error) {
            if (!context.mounted) return;
            messenger?.showSnackBar(
              SnackBar(
                content: Text('Unable to finish the ad: $error'),
              ),
            );
          }
          return;
        }

          final hint = await Future<HintSuggestion?>.sync(onHint!);
        if (hint == null) {
          if (!context.mounted) return;
          messenger?.showSnackBar(
            const SnackBar(
              content:
                  Text('No hint is available right now. Try another move.'),
            ),
          );
          return;
        }

        final didSpendHint =
            await ref.read(saveStateNotifierProvider.notifier).spendHint();
        if (!didSpendHint) {
          if (!context.mounted) return;
          messenger?.showSnackBar(
            const SnackBar(content: Text('No hints available.')),
          );
          return;
        }

        if (!context.mounted) return;
        final detail = hint.detail;
        final text = detail == null ? hint.message : '${hint.message}\n$detail';
        messenger?.showSnackBar(SnackBar(content: Text(text)));
      } finally {
        isHintProcessing.value = false;
      }
    }

    if (saveState == null) {
      return SizedBox.shrink();
    }

    Widget? buildHintControls() {
      if (isPreview || onHint == null) {
        return null;
      }

      final hintCount = saveState.hints;
      final tooltipText = hintCount > 0
          ? 'Use a hint'
          : 'Out of hints — watch an ad to earn $hintRewardAmount more';
      final disableButton =
          isHintProcessing.value || isVictory || onHint == null;
      final hasHints = hintCount > 0;

      return Tooltip(
        message: tooltipText,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.5),
              ),
              onPressed: disableButton ? null : handleHintPressed,
              child: Icon(
                Icons.tips_and_updates,
                color: hasHints ? Colors.white : Colors.yellow[200],
              ),
            ),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: hasHints ? Colors.orange : Colors.grey,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text(
                  '$hintCount',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final axis = constraints.largestAxis;

            return Stack(
              children: [
                Column(
                  children: [
                    if (!isPreview && axis == Axis.horizontal)
                      Container(
                        height: max(MediaQuery.paddingOf(context).top + 32, 48),
                        alignment: Alignment.center,
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Builder(
                              builder: (context) {
                                final hintControlsTop = buildHintControls();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 8,
                                  children: [
                                    Tooltip(
                                      message: 'Menu',
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.5),
                                        ),
                                        onPressed: openMenu,
                                        child: Icon(Icons.menu),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Undo',
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.5)),
                                        onPressed: isVictory || onUndo == null
                                            ? null
                                            : () {
                                                ref
                                                    .read(audioServiceProvider)
                                                    .playUndo();
                                                onUndo?.call();
                                              },
                                        child: Icon(Icons.undo),
                                      ),
                                    ),
                                    Text(
                                      currentTimeState.value
                                          .difference(startTimeState.value)
                                          .format(),
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    if (hintControlsTop != null) ...[
                                      Spacer(),
                                      hintControlsTop,
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: SafeArea(
                        bottom: axis == Axis.vertical,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 1080),
                            child: LayoutBuilder(
                              builder: (context, constraints) => builder(
                                context,
                                constraints,
                                saveState.cardBack,
                                saveState.enableAutoMove,
                                startTimeState.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!isPreview && axis == Axis.vertical)
                      Container(
                        height:
                            max(MediaQuery.paddingOf(context).bottom + 32, 48),
                        color: Colors.white.withValues(alpha: 0.2),
                        alignment: Alignment.center,
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Builder(
                              builder: (context) {
                                final hintControlsBottom = buildHintControls();
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Tooltip(
                                      message: 'Menu',
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.5)),
                                        onPressed: openMenu,
                                        child: Icon(Icons.menu),
                                      ),
                                    ),
                                    Text(
                                      currentTimeState.value
                                          .difference(startTimeState.value)
                                          .format(),
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    if (hintControlsBottom != null)
                                      Flexible(child: hintControlsBottom),
                                    Tooltip(
                                      message: 'Undo',
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.5)),
                                        onPressed: isVictory || onUndo == null
                                            ? null
                                            : () {
                                                ref
                                                    .read(audioServiceProvider)
                                                    .playUndo();
                                                onUndo?.call();
                                              },
                                        child: Icon(Icons.undo),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    emissionFrequency: 0.02,
                    numberOfParticles: 50,
                    maxBlastForce: 100,
                    minBlastForce: 60,
                    gravity: 0.3,
                    shouldLoop: true,
                  ),
                ),
              ],
            );
          },
        ),
        AnimatedOpacity(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          opacity: isVictory && !isPreview ? 1 : 0,
          child: IgnorePointer(
            ignoring: !isVictory || isPreview,
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 512, maxHeight: 512),
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dailyChallenge != null) ...[
                        Text(
                          'Daily Puzzle Complete!',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 4),
                        Text(
                          dailyChallenge!.formattedLabel,
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 12),
                      ],
                      Text(
                        'You Won!',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      SizedBox(height: 16),
                      MarkdownBody(
                          data:
                              '**Time**: ${currentTimeState.value.difference(startTimeState.value).format()}'),
                      MarkdownBody(
                        data:
                            '**Best Time**: ${(difficultyGameState?.fastestGame ?? currentTimeState.value.difference(startTimeState.value)).format()}',
                      ),
                      MarkdownBody(
                          data:
                              '**Games Won**: ${difficultyGameState?.gamesWon ?? 1}'),
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          if (dailyChallenge == null)
                            ElevatedButton.icon(
                              onPressed: () {
                                startTimeState.value = DateTime.now();
                                onNewGame();
                              },
                              label: Text('New Game'),
                              icon: Icon(Icons.star_border),
                            ),
                          ElevatedButton.icon(
                            onPressed: () => restartGame(),
                            label: Text('Restart Game'),
                            icon: Icon(Icons.restart_alt),
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.pushReplacement(() => HomePage()),
                            label: Text('Close'),
                            icon: Icon(Icons.close),
                          ),
                          if (dailyChallenge != null)
                            ElevatedButton.icon(
                              onPressed: () => DailyLeaderboardSheet.show(
                                context,
                                game: game,
                                config: dailyChallenge!,
                              ),
                              label: Text('View Leaderboard'),
                              icon: Icon(Icons.leaderboard),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InGameMenuSheet extends StatelessWidget {
  final String gameTitle;
  final bool isDailyChallenge;
  final VoidCallback onTutorial;
  final VoidCallback onNewGame;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  const _InGameMenuSheet({
    required this.gameTitle,
    required this.isDailyChallenge,
    required this.onTutorial,
    required this.onNewGame,
    required this.onRestart,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedSheet(
      title: '$gameTitle Menu',
      subtitle: 'Choose an action for your current game.',
      child: Column(
        children: [
          SheetOptionTile(
            icon: Icons.school,
            title: 'Tutorial',
            description:
                'Replay the guided walkthrough to refresh the core mechanics.',
            onTap: onTutorial,
          ),
          if (!isDailyChallenge)
            SheetOptionTile(
              icon: Icons.star_border,
              title: 'New Game',
              description: 'Deal a fresh layout with newly shuffled cards.',
              onTap: onNewGame,
            ),
          SheetOptionTile(
            icon: Icons.restart_alt,
            title: 'Restart Game',
            description: 'Reset this deal back to the starting position.',
            onTap: onRestart,
          ),
          SheetOptionTile(
            icon: Icons.close,
            title: 'Close Game',
            description: 'Leave the table and return to the home screen.',
            onTap: onClose,
            trailing: Icon(
              Icons.home_outlined,
              color: Colors.white54,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
