import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:solitaire/model/daily_challenge.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/services/leaderboard_service.dart';

final dailyChallengeServiceProvider =
    Provider<DailyChallengeService>((ref) => DailyChallengeService(ref));

class DailyChallengeService {
  DailyChallengeService(this._ref);

  final Ref _ref;

  DailyChallengeConfig configFor(Game game, {DateTime? date}) {
    final today = date ?? DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    final startOfYear = DateTime(normalized.year);
    final puzzleNumber = normalized.difference(startOfYear).inDays + 1;
    final seed = _seedFor(normalized, game);
    // Set difficulty: Easy for all games, Medium for Klondike
    final difficulty = game == Game.klondike 
        ? Difficulty.royal 
        : Difficulty.classic;
    return DailyChallengeConfig(
      game: game,
      puzzleNumber: puzzleNumber,
      date: normalized,
      shuffleSeed: seed,
      difficulty: difficulty,
    );
  }

  bool isCompleted(Game game, DailyChallengeConfig config,
      Map<Game, DailyChallengeProgress> progress) {
    final entry = progress[game];
    return entry?.isCompleted(config.puzzleNumber) ?? false;
  }

  bool hasSubmitted(Game game, DailyChallengeConfig config,
      Map<Game, DailyChallengeProgress> progress) {
    final entry = progress[game];
    return entry?.hasSubmitted(config.puzzleNumber) ?? false;
  }

  Future<void> handleVictory({
    required BuildContext context,
    required Game game,
    required DailyChallengeConfig config,
    required Duration duration,
  }) async {
    final saveState = await _ref.read(saveStateNotifierProvider.future);
    final alreadySubmitted =
        hasSubmitted(game, config, saveState.dailyChallengeProgress);

    await _ref
        .read(saveStateNotifierProvider.notifier)
        .saveDailyCompletion(
          game: game,
          puzzleNumber: config.puzzleNumber,
          duration: duration,
          submitted: alreadySubmitted,
        );

    if (alreadySubmitted) {
      return;
    }

    final leaderboard = _ref.read(leaderboardServiceProvider);
    if (!context.mounted) return;
    final didSubmit = await leaderboard.submitScore(
      context: context,
      game: game,
      levelNumber: config.puzzleNumber,
      duration: duration,
    );

    if (didSubmit) {
      if (!context.mounted) return;
      await _ref
          .read(saveStateNotifierProvider.notifier)
          .markDailySubmission(
            game: game,
            puzzleNumber: config.puzzleNumber,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Score submitted to the daily leaderboard!'),
        ),
      );
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Unable to submit score right now.'),
        ),
      );
    }
  }

  int _seedFor(DateTime date, Game game) {
    // Object.hash is intentionally randomized between runs. Build a stable,
    // reproducible seed so the same daily puzzle is dealt after app restarts.
    //
    // Formula keeps values in the 32-bit signed int range while combining
    // the date parts and game index.
    final dayKey = date.year * 10000 + date.month * 100 + date.day;
    final mixed = (dayKey * 31) ^ game.index;
    return mixed & 0x7fffffff;
  }
}

