import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:solitaire/dialogs/achievement_dialog.dart';
import 'package:solitaire/dialogs/customization_dialog.dart';
import 'package:solitaire/dialogs/settings_dialog.dart';
import 'package:solitaire/dialogs/stats_dialog.dart';
import 'package:solitaire/game_view.dart';
import 'package:solitaire/games/free_cell.dart';
import 'package:solitaire/games/golf_solitaire.dart';
import 'package:solitaire/games/solitaire.dart';
import 'package:solitaire/games/pyramid_solitaire.dart';
import 'package:solitaire/games/spider_solitaire.dart';
import 'package:solitaire/games/tri_peaks_solitaire.dart';
import 'package:solitaire/model/active_game_snapshot.dart';
import 'package:solitaire/model/daily_challenge.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/services/daily_challenge_service.dart';
import 'package:solitaire/styles/game_visuals.dart';
import 'package:solitaire/utils/build_context_extensions.dart';
import 'package:solitaire/widgets/themed_sheet.dart';

typedef GameWidgetBuilder = Widget Function(
  Difficulty difficulty,
  bool startWithTutorial, {
  DailyChallengeConfig? dailyChallenge,
  ActiveGameSnapshot? snapshot,
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Map<Game, GameWidgetBuilder> get gameBuilders => {
        Game.klondike: (difficulty, startWithTutorial,
                {DailyChallengeConfig? dailyChallenge,
                ActiveGameSnapshot? snapshot}) =>
                Solitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                  dailyChallenge: dailyChallenge,
                  snapshot: snapshot,
                ),
        Game.spider: (difficulty, startWithTutorial,
                {DailyChallengeConfig? dailyChallenge,
                ActiveGameSnapshot? snapshot}) =>
                SpiderSolitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                  dailyChallenge: dailyChallenge,
                  snapshot: snapshot,
                ),
        Game.freeCell: (difficulty, startWithTutorial,
                {DailyChallengeConfig? dailyChallenge,
                ActiveGameSnapshot? snapshot}) =>
                FreeCell(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                  dailyChallenge: dailyChallenge,
                  snapshot: snapshot,
                ),
        Game.pyramid: (difficulty, startWithTutorial,
                {DailyChallengeConfig? dailyChallenge,
                ActiveGameSnapshot? snapshot}) =>
                PyramidSolitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                  dailyChallenge: dailyChallenge,
                  snapshot: snapshot,
                ),
        Game.golf: (difficulty, startWithTutorial,
                {DailyChallengeConfig? dailyChallenge,
                ActiveGameSnapshot? snapshot}) =>
                GolfSolitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                  dailyChallenge: dailyChallenge,
                  snapshot: snapshot,
                ),
        Game.triPeaks: (difficulty, startWithTutorial,
                {DailyChallengeConfig? dailyChallenge,
                ActiveGameSnapshot? snapshot}) =>
                TriPeaksSolitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                  dailyChallenge: dailyChallenge,
                  snapshot: snapshot,
                ),
      };

  void _startGame({
    required BuildContext context,
    required WidgetRef ref,
    required Game game,
    required GameWidgetBuilder builder,
    required Difficulty difficulty,
    DailyChallengeConfig? dailyChallenge,
    ActiveGameSnapshot? snapshot,
  }) {
    context.pushReplacement(
      () => GameView(
        cardGame: builder(
          difficulty,
          false,
          dailyChallenge: dailyChallenge,
          snapshot: snapshot,
        ),
      ),
    );
    ref.read(saveStateNotifierProvider.notifier).saveGameStarted(
          game: game,
          difficulty: difficulty,
        );
  }

  void _startDailyGame({
    required BuildContext context,
    required WidgetRef ref,
    required Game game,
    required GameWidgetBuilder builder,
    required DailyChallengeConfig config,
  }) {
    _startGame(
      context: context,
      ref: ref,
      game: game,
      builder: builder,
      difficulty: config.difficulty,
      dailyChallenge: config,
      snapshot: null,
    );
  }

  void _showDifficultySelector({
    required BuildContext rootContext,
    required WidgetRef ref,
    required Game game,
    required GameWidgetBuilder builder,
    required Difficulty currentDefault,
    required DailyChallengeConfig dailyConfig,
    required bool dailyCompleted,
  }) {
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _DifficultySheet(
          game: game,
          defaultDifficulty: currentDefault,
          dailyConfig: dailyConfig,
          dailyCompleted: dailyCompleted,
          onDailySelected: () {
            Navigator.of(sheetContext).pop();
            _startDailyGame(
              context: rootContext,
              ref: ref,
              game: game,
              builder: builder,
              config: dailyConfig,
            );
          },
          onDifficultyChosen: (difficulty) {
            Navigator.of(sheetContext).pop();
            _startGame(
              context: rootContext,
              ref: ref,
              game: game,
              builder: builder,
              difficulty: difficulty,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
    if (saveState == null) {
      return SizedBox.shrink();
    }
    final dailyService = ref.watch(dailyChallengeServiceProvider);

    return Scaffold(
      backgroundColor: Color(0xFF0D2C54),
      appBar: AppBar(
        backgroundColor: Color(0xFF0A2340),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Solitaire Collection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Achievements',
            child: IconButton(
              icon: Icon(Symbols.military_tech, fill: 1),
              onPressed: () => AchievementDialog.show(context),
            ),
          ),
          Tooltip(
            message: 'Customization',
            child: IconButton(
              icon: Icon(Symbols.palette, fill: 1),
              onPressed: () => CustomizationDialog.show(context),
            ),
          ),
          Tooltip(
            message: 'Stats',
            child: IconButton(
              icon: Icon(Symbols.query_stats, fill: 1),
              onPressed: () => StatsDialog.show(context),
            ),
          ),
          Tooltip(
            message: 'Settings',
            child: IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => SettingsDialog.show(context),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determine number of columns based on width
          int crossAxisCount = 2;
          if (constraints.maxWidth > 900) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 3;
          }

          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: gameBuilders.length,
            itemBuilder: (context, index) {
              final game = gameBuilders.keys.elementAt(index);
              final builder = gameBuilders[game]!;
              final difficulty = saveState.lastPlayedGameDifficulties[game] ??
                  Difficulty.classic;
              final dailyConfig = dailyService.configFor(game);
              final dailyCompleted = dailyService.isCompleted(
                game,
                dailyConfig,
                saveState.dailyChallengeProgress,
              );
              final snapshot = saveState.activeGames[game];

              return _GameCard(
                game: game,
                gradient: game.accentGradient,
                icon: game.icon,
                logoAsset: game.logoAsset,
                dailyConfig: dailyConfig,
                dailyCompleted: dailyCompleted,
                onSelectDifficulty: () =>
                    _handleGameSelection(context, ref, game, builder, difficulty,
                        dailyConfig, dailyCompleted, snapshot),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleGameSelection(
    BuildContext context,
    WidgetRef ref,
    Game game,
    GameWidgetBuilder builder,
    Difficulty defaultDifficulty,
    DailyChallengeConfig dailyConfig,
    bool dailyCompleted,
    ActiveGameSnapshot? snapshot,
  ) async {
    if (snapshot != null && !snapshot.isDaily) {
      final decision = await _showResumeDialog(context, snapshot);
      if (decision == _ResumeChoice.resume) {
        if (!context.mounted) return;
        _startGame(
          context: context,
          ref: ref,
          game: game,
          builder: builder,
          difficulty: snapshot.difficulty,
          snapshot: snapshot,
        );
        return;
      } else if (decision == null) {
        return;
      } else {
        if (!context.mounted) return;
        await ref
            .read(saveStateNotifierProvider.notifier)
            .clearActiveGame(game);
      }
    }

    if (!context.mounted) return;
    _showDifficultySelector(
      rootContext: context,
      ref: ref,
      game: game,
      builder: builder,
      currentDefault: defaultDifficulty,
      dailyConfig: dailyConfig,
      dailyCompleted: dailyCompleted,
    );
  }

  Future<_ResumeChoice?> _showResumeDialog(
      BuildContext context, ActiveGameSnapshot snapshot) {
    return showDialog<_ResumeChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Resume ${snapshot.difficulty.title} game?'),
        content: Text(
            'You have an unfinished game saved. Would you like to continue where you left off or start a new game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ResumeChoice.newGame),
            child: const Text('New Game'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ResumeChoice.resume),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}

enum _ResumeChoice { resume, newGame }

class _GameCard extends StatelessWidget {
  final Game game;
  final List<Color> gradient;
  final IconData icon;
  final String logoAsset;
  final VoidCallback onSelectDifficulty;
  final DailyChallengeConfig dailyConfig;
  final bool dailyCompleted;

  const _GameCard({
    required this.game,
    required this.gradient,
    required this.icon,
    required this.logoAsset,
    required this.onSelectDifficulty,
    required this.dailyConfig,
    required this.dailyCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelectDifficulty,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Positioned(
                //   top: 12,
                //   right: 12,
                //   child: Container(
                //     padding:
                //         const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //     decoration: BoxDecoration(
                //       color: dailyCompleted
                //           ? Colors.greenAccent.withValues(alpha: 0.8)
                //           : Colors.orangeAccent.withValues(alpha: 0.9),
                //       borderRadius: BorderRadius.circular(999),
                //       boxShadow: [
                //         BoxShadow(
                //           color: Colors.black.withValues(alpha: 0.2),
                //           blurRadius: 6,
                //         ),
                //       ],
                //     ),
                //     child: Text(
                //       dailyCompleted ? 'Daily Done' : 'Daily Ready',
                //       style: const TextStyle(
                //         color: Colors.black,
                //         fontWeight: FontWeight.bold,
                //         fontSize: 12,
                //       ),
                //     ),
                //   ),
                // ),
                // Decorative pattern overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: CustomPaint(
                      painter: _PatternPainter(),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Game icon and name
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              game.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      // Game logo
                      Center(
                        child: SizedBox(
                          width: 158,
                          height: 158,
                          child: Image.asset(
                            logoAsset,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultySheet extends StatelessWidget {
  final Game game;
  final Difficulty defaultDifficulty;
  final ValueChanged<Difficulty> onDifficultyChosen;
  final DailyChallengeConfig dailyConfig;
  final bool dailyCompleted;
  final VoidCallback onDailySelected;

  const _DifficultySheet({
    required this.game,
    required this.defaultDifficulty,
    required this.dailyConfig,
    required this.dailyCompleted,
    required this.onDailySelected,
    required this.onDifficultyChosen,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedSheet(
      title: game.title,
      child: Column(
        children: Difficulty.values
            .map(
              (difficulty) => SheetOptionTile(
                icon: difficulty.icon,
                title: difficulty.title,
                description: difficulty.getDescription(game),
                onTap: () => onDifficultyChosen(difficulty),
                highlight: defaultDifficulty == difficulty,
              ),
            )
            .toList()
          ..insert(
            0,
            SheetOptionTile(
              icon: Symbols.calendar_month,
              title: 'Daily Puzzle',
              description: dailyCompleted
                  ? 'You finished today\'s puzzle!'
                  : 'Play today\'s puzzle and compete on the leaderboard.',
              onTap: onDailySelected,
              highlight: !dailyCompleted,
              highlightColor: Colors.lightBlueAccent,
              trailing: dailyCompleted
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.lightGreenAccent,
                    )
                  : const Icon(
                      Icons.leaderboard,
                      color: Colors.white,
                    ),
            ),
          ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw a simple diamond pattern
    for (double i = 0; i < size.width; i += 40) {
      for (double j = 0; j < size.height; j += 40) {
        canvas.drawCircle(Offset(i, j), 15, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
