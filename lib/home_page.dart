import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:solitaire/dialogs/about_dialog.dart';
import 'package:solitaire/dialogs/achievement_dialog.dart';
import 'package:solitaire/dialogs/customization_dialog.dart';
import 'package:solitaire/dialogs/settings_dialog.dart';
import 'package:solitaire/game_view.dart';
import 'package:solitaire/games/free_cell.dart';
import 'package:solitaire/games/golf_solitaire.dart';
import 'package:solitaire/games/solitaire.dart';
import 'package:solitaire/games/pyramid_solitaire.dart';
import 'package:solitaire/games/spider_solitaire.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/utils/build_context_extensions.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Map<Game, Widget Function(Difficulty, bool startWithTutorial)> get gameBuilders => {
        Game.klondike: (Difficulty difficulty, bool startWithTutorial) => Solitaire(
              difficulty: difficulty,
              startWithTutorial: startWithTutorial,
            ),
        Game.spider: (Difficulty difficulty, bool startWithTutorial) => SpiderSolitaire(
              difficulty: difficulty,
              startWithTutorial: startWithTutorial,
            ),
        Game.freeCell: (Difficulty difficulty, bool startWithTutorial) => FreeCell(
              difficulty: difficulty,
              startWithTutorial: startWithTutorial,
            ),
        Game.pyramid: (Difficulty difficulty, bool startWithTutorial) => PyramidSolitaire(
              difficulty: difficulty,
              startWithTutorial: startWithTutorial,
            ),
        Game.golf: (Difficulty difficulty, bool startWithTutorial) => GolfSolitaire(
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
    }
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
            message: 'More',
            child: MenuAnchor(
              alignmentOffset: Offset(-75, 0),
              builder: (context, controller, child) {
                return IconButton(
                  onPressed: () => controller.open(),
                  icon: Icon(Icons.more_vert),
                );
              },
              menuChildren: [
                MenuItemButton(
                  leadingIcon: Icon(Icons.settings),
                  onPressed: () => SettingsDialog.show(context),
                  child: Text('Settings'),
                ),
              ],
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
              final difficulty = saveState.lastPlayedGameDifficulties[game] ?? Difficulty.classic;
              final gameState = saveState.gameStates[game];
              final gamesWon = gameState?.states[difficulty]?.gamesWon ?? 0;

              return _GameCard(
                game: game,
                gamesWon: gamesWon,
                gradient: gameGradients[game]!,
                icon: getGameIcon(game),
                onTap: () {
                  context.pushReplacement(() => GameView(cardGame: builder(difficulty, false)));
                  ref.read(saveStateNotifierProvider.notifier).saveGameStarted(
                        game: game,
                        difficulty: difficulty,
                      );
                },
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
  final int gamesWon;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;

  const _GameCard({
    required this.game,
    required this.gamesWon,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                color: Colors.black.withOpacity(0.3),
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
                              color: Colors.white.withOpacity(0.2),
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
                      // Games won badge
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$gamesWon',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Spacer(),
                      // Play hint
                      Center(
                        child: Text(
                          'Tap to Play',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
