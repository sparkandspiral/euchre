import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:solitaire/model/achievement.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/save_state.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/styles/game_visuals.dart';
import 'package:solitaire/utils/duration_extensions.dart';
import 'package:solitaire/widgets/themed_sheet.dart';

class StatsDialog {
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Consumer(
            builder: (context, ref, child) {
              final saveState =
                  ref.watch(saveStateNotifierProvider).valueOrNull;
              if (saveState == null) {
                return SizedBox.shrink();
              }

              final stats = _StatsSnapshot.fromSaveState(saveState);

              return ThemedSheet(
                title: 'Stats',
                subtitle: stats.subtitle,
                scrollController: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroStatGrid(stats: stats),
                    SizedBox(height: 24),
                    _AchievementProgress(
                      unlocked: stats.achievementsUnlocked,
                      total: stats.achievementsTotal,
                    ),
                    if (stats.totalWins == 0) ...[
                      SizedBox(height: 20),
                      _EmptyStateCard(),
                    ],
                    SizedBox(height: 24),
                    Text(
                      'Game breakdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...stats.gameStats.values
                        .map(
                          (gameStat) => Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: _GameStatsCard(stats: gameStat),
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

class _StatsSnapshot {
  final int totalWins;
  final Duration? fastestWin;
  final int winStreak;
  final int hintsRemaining;
  final int achievementsUnlocked;
  final int achievementsTotal;
  final Map<Game, _GameStats> gameStats;

  const _StatsSnapshot({
    required this.totalWins,
    required this.fastestWin,
    required this.winStreak,
    required this.hintsRemaining,
    required this.achievementsUnlocked,
    required this.achievementsTotal,
    required this.gameStats,
  });

  String get subtitle {
    if (totalWins == 0) {
      return 'Play a game to start building your stat sheet.';
    }
    final fastestText = _formatDuration(fastestWin);
    return '$totalWins wins across the collection • Fastest $fastestText';
  }

  factory _StatsSnapshot.fromSaveState(SaveState saveState) {
    final Map<Game, _GameStats> gameStats = {};
    int totalWins = 0;
    Duration? fastest;

    for (final game in Game.values) {
      final gameState = saveState.gameStates[game];
      final Map<Difficulty, _DifficultyStats> difficultyStats = {};

      for (final difficulty in Difficulty.values) {
        final difficultyState = gameState?.states[difficulty];
        final wins = difficultyState?.gamesWon ?? 0;
        final fastestWin = wins > 0 ? difficultyState?.fastestGame : null;
        difficultyStats[difficulty] = _DifficultyStats(
          difficulty: difficulty,
          wins: wins,
          fastestWin: fastestWin,
        );
        totalWins += wins;
        fastest = _pickFastest(fastest, fastestWin);
      }

      gameStats[game] = _GameStats(
        game: game,
        difficultyStats: difficultyStats,
        totalWins:
            difficultyStats.values.fold(0, (sum, stat) => sum + stat.wins),
        fastestWin:
            _fastestDuration(difficultyStats.values.map((s) => s.fastestWin)),
      );
    }

    return _StatsSnapshot(
      totalWins: totalWins,
      fastestWin: fastest,
      winStreak: saveState.winStreak,
      hintsRemaining: saveState.hints,
      achievementsUnlocked: saveState.achievements.length,
      achievementsTotal: Achievement.values.length,
      gameStats: gameStats,
    );
  }
}

class _GameStats {
  final Game game;
  final Map<Difficulty, _DifficultyStats> difficultyStats;
  final int totalWins;
  final Duration? fastestWin;

  const _GameStats({
    required this.game,
    required this.difficultyStats,
    required this.totalWins,
    required this.fastestWin,
  });
}

class _DifficultyStats {
  final Difficulty difficulty;
  final int wins;
  final Duration? fastestWin;

  const _DifficultyStats({
    required this.difficulty,
    required this.wins,
    required this.fastestWin,
  });
}

class _HeroStatGrid extends StatelessWidget {
  final _StatsSnapshot stats;

  const _HeroStatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _HeroMetric(
        icon: Symbols.local_fire_department,
        label: 'Win streak',
        value: stats.winStreak.toString(),
        description: 'Consecutive wins',
        accent: Color(0xFFFFA726),
      ),
      _HeroMetric(
        icon: Symbols.workspace_premium,
        label: 'Lifetime wins',
        value: stats.totalWins.toString(),
        description: 'Across all games',
        accent: Color(0xFFFFD54F),
      ),
      _HeroMetric(
        icon: Symbols.speed,
        label: 'Fastest win',
        value: _formatDuration(stats.fastestWin),
        description: 'Best recorded time',
        accent: Color(0xFF64B5F6),
      ),
      _HeroMetric(
        icon: Symbols.tips_and_updates,
        label: 'Hints saved',
        value: stats.hintsRemaining.toString(),
        description: 'In your inventory',
        accent: Color(0xFF4DB6AC),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final spacing = 12.0;
        final columns = width >= 880
            ? 4
            : width >= 520
                ? 2
                : 1;
        final cardWidth =
            columns == 1 ? width : (width - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: cardWidth,
                  child: _HeroStatCard(metric: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HeroMetric {
  final IconData icon;
  final String label;
  final String value;
  final String description;
  final Color accent;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.description,
    required this.accent,
  });
}

class _HeroStatCard extends StatelessWidget {
  final _HeroMetric metric;

  const _HeroStatCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            metric.accent.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: metric.accent.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              metric.icon,
              color: Colors.white,
              size: 22,
              fill: 1,
            ),
          ),
          SizedBox(height: 12),
          Text(
            metric.value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            metric.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            metric.description,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementProgress extends StatelessWidget {
  final int unlocked;
  final int total;

  const _AchievementProgress({
    required this.unlocked,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        total == 0 ? 0.0 : (unlocked / total).clamp(0, 1).toDouble();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sheetTileColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Symbols.workspace_premium,
                  color: Colors.amberAccent,
                  size: 22,
                  fill: 1,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievements',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$unlocked of $total unlocked',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.auto_graph,
            color: Colors.white54,
            size: 28,
            fill: 1,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Once you start winning, detailed stats for every game and difficulty will populate here.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameStatsCard extends StatelessWidget {
  final _GameStats stats;

  const _GameStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final winLabel = stats.totalWins == 1 ? '1 win' : '${stats.totalWins} wins';
    final fastest = _formatDuration(stats.fastestWin);

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sheetTileColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stats.totalWins > 0
              ? stats.game.accentColor.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.4,
        ),
        boxShadow: [
          if (stats.totalWins > 0)
            BoxShadow(
              color: stats.game.accentColor.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: stats.game.accentGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  stats.game.icon,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.game.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '$winLabel • Fastest $fastest',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          _DifficultyGrid(stats: stats),
        ],
      ),
    );
  }
}

class _DifficultyGrid extends StatelessWidget {
  final _GameStats stats;

  const _DifficultyGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final difficultyCards = stats.difficultyStats.values.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final spacing = 12.0;
        final columns = width >= 720
            ? 3
            : width >= 460
                ? 2
                : 1;
        final cardWidth =
            columns == 1 ? width : (width - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: difficultyCards
              .map(
                (card) => SizedBox(
                  width: cardWidth,
                  child: _DifficultyStatCard(stats: card),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DifficultyStatCard extends StatelessWidget {
  final _DifficultyStats stats;

  const _DifficultyStatCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final accent = _difficultyAccent(stats.difficulty);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stats.wins > 0
              ? accent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  stats.difficulty.icon,
                  color: accent,
                  size: 18,
                  fill: 1,
                ),
              ),
              SizedBox(width: 8),
              Text(
                stats.difficulty.title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '${stats.wins} wins',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Fastest ${_formatDuration(stats.fastestWin)}',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

Duration? _pickFastest(Duration? current, Duration? candidate) {
  if (candidate == null) {
    return current;
  }
  if (current == null || candidate.inMilliseconds < current.inMilliseconds) {
    return candidate;
  }
  return current;
}

Duration? _fastestDuration(Iterable<Duration?> durations) {
  Duration? fastest;
  for (final duration in durations) {
    if (duration == null) {
      continue;
    }
    fastest = _pickFastest(fastest, duration);
  }
  return fastest;
}

String _formatDuration(Duration? duration) =>
    duration == null ? '—' : duration.format();

Color _difficultyAccent(Difficulty difficulty) => switch (difficulty) {
      Difficulty.classic => Color(0xFF26A69A),
      Difficulty.royal => Color(0xFFFFB74D),
      Difficulty.ace => Color(0xFFEF5350),
    };
