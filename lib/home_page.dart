import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:solitaire/dialogs/achievement_dialog.dart';
import 'package:solitaire/dialogs/customization_dialog.dart';
import 'package:solitaire/dialogs/settings_dialog.dart';
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
import 'package:solitaire/utils/build_context_extensions.dart';

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

  // Game-specific gradient colors
  Map<Game, List<Color>> get gameGradients => {
        Game.klondike: [Color(0xFF00A8CC), Color(0xFF0074B7)],
        Game.spider: [Color(0xFF8B2FC9), Color(0xFF5C0099)],
        Game.freeCell: [Color(0xFFE63946), Color(0xFFC41E3A)],
        Game.pyramid: [Color(0xFFE67E22), Color(0xFFD35400)],
        Game.golf: [Color(0xFF27AE60), Color(0xFF1E8449)],
        Game.triPeaks: [Color(0xFFFFD700), Color(0xFFB8860B)],
      };

  // Game logos
  Map<Game, String> get gameLogos => {
        Game.klondike: 'assets/logos/klondike.png',
        Game.spider: 'assets/logos/spider.png',
        Game.freeCell: 'assets/logos/freecell.png',
        Game.pyramid: 'assets/logos/pyramid.png',
        Game.golf: 'assets/logos/golf.png',
        Game.triPeaks: 'assets/logos/tripeaks.png',
      };

  // Game icons
  IconData getGameIcon(Game game) {
    switch (game) {
      case Game.klondike:
        return Icons.stars;
      case Game.spider:
        return Icons.apps;
      case Game.freeCell:
        return Icons.dashboard;
      case Game.pyramid:
        return Icons.change_history;
      case Game.golf:
        return Icons.terrain;
      case Game.triPeaks:
        return Icons.filter_hdr;
    }
  }

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
    final notifier = ref.read(saveStateNotifierProvider.notifier);
    var selectedDifficulty = currentDefault;
    var defaultDifficulty = currentDefault;

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setState) {
            return _DifficultySheet(
              game: game,
              selectedDifficulty: selectedDifficulty,
              defaultDifficulty: defaultDifficulty,
              onSelectDifficulty: (difficulty) {
                setState(() => selectedDifficulty = difficulty);
              },
              onDefaultChanged: (difficulty) async {
                setState(() => defaultDifficulty = difficulty);
                await notifier.saveDefaultDifficulty(
                    game: game, difficulty: difficulty);
              },
              onPlay: () {
                Navigator.of(sheetContext).pop();
                _startGame(
                  context: rootContext,
                  ref: ref,
                  game: game,
                  builder: builder,
                  difficulty: selectedDifficulty,
                );
              },
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
            Icon(Icons.games, size: 28),
            SizedBox(width: 12),
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
                gradient: gameGradients[game]!,
                icon: getGameIcon(game),
                logoAsset: gameLogos[game]!,
                defaultDifficulty: difficulty,
                onSelectDifficulty: () => _showDifficultySelector(
                  rootContext: context,
                  ref: ref,
                  game: game,
                  builder: builder,
                  currentDefault: difficulty,
                ),
                onQuickStart: () => _startGame(
                  context: context,
                  ref: ref,
                  game: game,
                  builder: builder,
                  difficulty: difficulty,
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
  final Difficulty defaultDifficulty;
  final VoidCallback onSelectDifficulty;
  final VoidCallback onQuickStart;

  const _GameCard({
    required this.game,
    required this.gradient,
    required this.icon,
    required this.logoAsset,
    required this.defaultDifficulty,
    required this.onSelectDifficulty,
    required this.onQuickStart,
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
                          Tooltip(
                            message: 'Quick start (${defaultDifficulty.title})',
                            child: IconButton(
                              onPressed: onQuickStart,
                              icon: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 26,
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
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                size: 14,
                                color: Colors.white70,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Default: ${defaultDifficulty.title}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
  final Difficulty selectedDifficulty;
  final Difficulty defaultDifficulty;
  final ValueChanged<Difficulty> onSelectDifficulty;
  final ValueChanged<Difficulty> onDefaultChanged;
  final VoidCallback onPlay;

  const _DifficultySheet({
    required this.game,
    required this.selectedDifficulty,
    required this.defaultDifficulty,
    required this.onSelectDifficulty,
    required this.onDefaultChanged,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Container(
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Color(0xFF0A2340),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  game.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose a difficulty before you play.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 24),
                ...Difficulty.values.map(
                  (difficulty) => _DifficultyOptionTile(
                    game: game,
                    difficulty: difficulty,
                    isSelected: selectedDifficulty == difficulty,
                    isDefault: defaultDifficulty == difficulty,
                    onTap: () => onSelectDifficulty(difficulty),
                    onSetDefault: () => onDefaultChanged(difficulty),
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPlay,
                    child: Text('Play ${selectedDifficulty.title}'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyOptionTile extends StatelessWidget {
  final Game game;
  final Difficulty difficulty;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;

  const _DifficultyOptionTile({
    required this.game,
    required this.difficulty,
    required this.isSelected,
    required this.isDefault,
    required this.onTap,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    final descriptionStyle = TextStyle(
      color: Colors.white70,
      fontSize: 13,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF132A4A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Color(0xFFFFD700)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  difficulty.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(difficulty.title, style: titleStyle),
                        SizedBox(width: 8),
                        if (isSelected)
                          _DifficultyBadge(
                            label: 'Selected',
                            color: Color(0xFFFFD700),
                          ),
                        if (isDefault)
                          Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: _DifficultyBadge(
                              label: 'Default',
                              color: Color(0xFF6BE5FF),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      difficulty.getDescription(game),
                      style: descriptionStyle,
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: isDefault
                    ? 'Quick start uses this difficulty'
                    : 'Set as quick start default',
                child: IconButton(
                  onPressed: onSetDefault,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: Icon(
                    isDefault
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DifficultyBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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
