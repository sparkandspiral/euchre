import 'dart:async';
import 'dart:math';

import 'package:adaptive_action_sheet/adaptive_action_sheet.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:solitaire/context/card_game_context.dart';
import 'package:solitaire/home_page.dart';
import 'package:solitaire/model/card_back.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/hint.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/services/achievement_service.dart';
import 'package:solitaire/services/audio_service.dart';
import 'package:solitaire/services/rewarded_ad_service.dart';
import 'package:solitaire/utils/build_context_extensions.dart';
import 'package:solitaire/utils/constraints_extensions.dart';
import 'package:solitaire/utils/duration_extensions.dart';
import 'package:utils/utils.dart';

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

  final FutureOr Function()? onVictory;
  final bool isVictory;

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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardGameContext = context.watch<CardGameContext?>();
    final isPreview = cardGameContext?.isPreview ?? false;

    final isHintProcessing = useState(false);
    final startTimeState = useState(DateTime.now());
    final currentTimeState = useState(DateTime.now());

    final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
    final difficultyGameState = saveState?.gameStates[game]?.states[difficulty];

    useEffect(() {
      if (isVictory) {
        final duration =
            currentTimeState.value.difference(startTimeState.value);
        () async {
          ref.read(audioServiceProvider).playWin();
          await onVictory?.call();
          await ref.read(saveStateNotifierProvider.notifier).saveGameCompleted(
              game: game, difficulty: difficulty, duration: duration);
          ref.read(achievementServiceProvider).checkGameCompletionAchievements(
              game: game, difficulty: difficulty, duration: duration);
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

          try {
            await ref.read(rewardedAdServiceProvider).showRewardedAd(context);
            await ref
                .read(saveStateNotifierProvider.notifier)
                .addHints(hintRewardAmount);
            messenger?.showSnackBar(
              SnackBar(
                content: Text('You earned $hintRewardAmount additional hints.'),
              ),
            );
          } catch (error) {
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
          messenger?.showSnackBar(
            const SnackBar(content: Text('No hints available.')),
          );
          return;
        }

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

      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Hints: $hintCount',
            style: const TextStyle(fontSize: 16),
          ),
          Tooltip(
            message: tooltipText,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.5),
              ),
              onPressed: disableButton ? null : handleHintPressed,
              child: Icon(
                Icons.tips_and_updates,
                color: hintCount > 0 ? Colors.white : Colors.yellow[200],
              ),
            ),
          ),
        ],
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
                                      child: MenuAnchor(
                                        builder: (context, controller, child) {
                                          return ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.5),
                                            ),
                                            onPressed: () => controller.open(),
                                            child: Icon(Icons.menu),
                                          );
                                        },
                                        menuChildren: [
                                          MenuItemButton(
                                            leadingIcon:
                                                Icon(Icons.star_border),
                                            onPressed: startNewGame,
                                            child: Text('New Game'),
                                          ),
                                          MenuItemButton(
                                            leadingIcon:
                                                Icon(Icons.restart_alt),
                                            onPressed: restartGame,
                                            child: Text('Restart Game'),
                                          ),
                                          MenuItemButton(
                                            leadingIcon:
                                                Icon(Icons.question_mark),
                                            onPressed: onTutorial,
                                            child: Text('Tutorial'),
                                          ),
                                          MenuItemButton(
                                            leadingIcon: Icon(Icons.close),
                                            onPressed: closeGame,
                                            child: Text('Close'),
                                          ),
                                        ],
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
                                        onPressed: () async {
                                          await showAdaptiveActionSheet(
                                            context: context,
                                            actions: [
                                              BottomSheetAction(
                                                title: Text('New Game'),
                                                leading:
                                                    Icon(Icons.star_border),
                                                onPressed: (context) {
                                                  startNewGame();
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              BottomSheetAction(
                                                title: Text('Restart Game'),
                                                leading:
                                                    Icon(Icons.restart_alt),
                                                onPressed: (_) {
                                                  restartGame();
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              BottomSheetAction(
                                                title: Text('Tutorial'),
                                                leading:
                                                    Icon(Icons.question_mark),
                                                onPressed: (_) {
                                                  onTutorial();
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              BottomSheetAction(
                                                title: Text('Close'),
                                                leading: Icon(Icons.close),
                                                onPressed: (_) {
                                                  Navigator.of(context).pop();
                                                  closeGame();
                                                },
                                              ),
                                            ],
                                          );
                                        },
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
