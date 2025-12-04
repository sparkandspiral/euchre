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
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/styles/game_visuals.dart';
import 'package:solitaire/utils/build_context_extensions.dart';
import 'package:solitaire/widgets/themed_sheet.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Map<Game, Widget Function(Difficulty, bool startWithTutorial)>
      get gameBuilders => {
            Game.klondike: (Difficulty difficulty, bool startWithTutorial) =>
                Solitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                ),
            Game.spider: (Difficulty difficulty, bool startWithTutorial) =>
                SpiderSolitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                ),
            Game.freeCell: (Difficulty difficulty, bool startWithTutorial) =>
                FreeCell(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                ),
            Game.pyramid: (Difficulty difficulty, bool startWithTutorial) =>
                PyramidSolitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                ),
            Game.golf: (Difficulty difficulty, bool startWithTutorial) =>
                GolfSolitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                ),
            Game.triPeaks: (Difficulty difficulty, bool startWithTutorial) =>
                TriPeaksSolitaire(
                  difficulty: difficulty,
                  startWithTutorial: startWithTutorial,
                ),
          };

  void _startGame({
    required BuildContext context,
    required WidgetRef ref,
    required Game game,
    required Widget Function(Difficulty, bool) builder,
    required Difficulty difficulty,
  }) {
    context
        .pushReplacement(() => GameView(cardGame: builder(difficulty, false)));
    ref.read(saveStateNotifierProvider.notifier).saveGameStarted(
          game: game,
          difficulty: difficulty,
        );
  }

  void _showDifficultySelector({
    required BuildContext rootContext,
    required WidgetRef ref,
    required Game game,
    required Widget Function(Difficulty, bool) builder,
    required Difficulty currentDefault,
  }) {
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _DifficultySheet(
          game: game,
          defaultDifficulty: currentDefault,
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

              return _GameCard(
                game: game,
                gradient: game.accentGradient,
                icon: game.icon,
                logoAsset: game.logoAsset,
                onSelectDifficulty: () => _showDifficultySelector(
                  rootContext: context,
                  ref: ref,
                  game: game,
                  builder: builder,
                  currentDefault: difficulty,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final Game game;
  final List<Color> gradient;
  final IconData icon;
  final String logoAsset;
  final VoidCallback onSelectDifficulty;

  const _GameCard({
    required this.game,
    required this.gradient,
    required this.icon,
    required this.logoAsset,
    required this.onSelectDifficulty,
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

  const _DifficultySheet({
    required this.game,
    required this.defaultDifficulty,
    required this.onDifficultyChosen,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedSheet(
      title: game.title,
      // subtitle: 'Tap a difficulty to start playing.',
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
            .toList(),
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
