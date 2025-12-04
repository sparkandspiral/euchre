import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:solitaire/games/free_cell.dart';
import 'package:solitaire/games/golf_solitaire.dart';
import 'package:solitaire/games/pyramid_solitaire.dart';
import 'package:solitaire/games/solitaire.dart';
import 'package:solitaire/games/spider_solitaire.dart';
import 'package:solitaire/games/tri_peaks_solitaire.dart';
import 'package:solitaire/main.dart';
import 'package:solitaire/model/achievement.dart';
import 'package:solitaire/model/card_back.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:utils/utils.dart';

part 'achievement_service.g.dart';

class AchievementService {
  final Ref ref;

  static const _initialSpiderStockLength = 50;
  static const _totalPyramidCards = 28;

  const AchievementService(this.ref);

  Future<void> checkGameCompletionAchievements({
    required Game game,
    required Difficulty difficulty,
    required Duration duration,
  }) async {
    final saveState = await ref.read(saveStateNotifierProvider.future);

    if (duration < Duration(minutes: 1)) {
      await _markAchievement(Achievement.speedDealer);
    }

    if (saveState.winStreak == 3) {
      await _markAchievement(Achievement.stackTheDeck);
    }

    if (saveState.gameStates.length == Game.values.length &&
        saveState.gameStates.values.every(
            (gameState) => gameState.states[Difficulty.classic] != null)) {
      await _markAchievement(Achievement.fullHouse);
    }

    if (saveState.gameStates.length == Game.values.length &&
        saveState.gameStates.values
            .every((gameState) => gameState.states[Difficulty.royal] != null)) {
      await _markAchievement(Achievement.royalFlush);
    }

    if (saveState.gameStates.length == Game.values.length &&
        saveState.gameStates.values
            .every((gameState) => gameState.states[Difficulty.ace] != null)) {
      await _markAchievement(Achievement.aceUpYourSleeve);
    }
  }

  Future<void> checkGolfSolitaireMoveAchievements(
      {required GolfSolitaireState state}) async {
    if (state.chain == 20) {
      await _markAchievement(Achievement.grandSlam);
    }
  }

  Future<void> checkGolfSolitaireCompletionAchievements({
    required GolfSolitaireState state,
    required Difficulty difficulty,
  }) async {
    if (difficulty == Difficulty.ace && state.deck.isNotEmpty) {
      await _markAchievement(Achievement.birdie);
    }
  }

  Future<void> checkFreeCellMoveAchievements(
      {required FreeCellState state}) async {
    final completedFoundations = state.foundationCards.values
        .where((cards) => cards.length == 13)
        .toList();
    final emptyFoundations = state.foundationCards
        .where((suit, cards) =>
            cards.isEmpty &&
            state.history
                .every((state) => state.foundationCards[suit]!.isEmpty))
        .values
        .toList();

    if (completedFoundations.length == 1 && emptyFoundations.length == 3) {
      await _markAchievement(Achievement.suitedUp);
    }
  }

  Future<void> checkSolitaireCompletionAchievements({
    required Difficulty difficulty,
    required SolitaireState state,
  }) async {
    if (difficulty == Difficulty.ace && !state.usedUndo) {
      await _markAchievement(Achievement.cleanSweep);
    }

    if (!state.restartedDeck) {
      await _markAchievement(Achievement.deckWhisperer);
    }
  }

  Future<void> checkFreeCellCompletionAchievements({
    required Difficulty difficulty,
    required FreeCellState state,
  }) async {
    if (difficulty == Difficulty.ace && !state.usedUndo) {
      await _markAchievement(Achievement.perfectPlanning);
    }
  }

  Future<void> checkSpiderSolitaireMoveAchievements(
      {required SpiderSolitaireState state}) async {
    final clearedHalfWeb = state.stock.length == _initialSpiderStockLength &&
        state.completedSequences >= 4;
    if (clearedHalfWeb) {
      await _markAchievement(Achievement.silkRoad);
    }
  }

  Future<void> checkSpiderSolitaireCompletionAchievements({
    required Difficulty difficulty,
    required SpiderSolitaireState state,
  }) async {
    if (difficulty == Difficulty.ace && !state.usedUndo) {
      await _markAchievement(Achievement.eightfoldMaster);
    }
  }

  Future<void> checkPyramidSolitaireMoveAchievements({
    required PyramidSolitaireState state,
    required Difficulty difficulty,
  }) async {
    final startWithWasteCard = difficulty.index >= Difficulty.royal.index;
    final initialStock = 52 -
        _totalPyramidCards -
        (startWithWasteCard
            ? 1
            : 0); // subtract waste card if one is dealt at start
    final remainingCards = state.pyramid.fold<int>(
      0,
      (sum, row) => sum + row.where((card) => card != null).length,
    );
    final removedCards = _totalPyramidCards - remainingCards;
    final noDrawsYet = state.stock.length == initialStock;

    if (noDrawsYet && removedCards >= 10) {
      await _markAchievement(Achievement.desertRunner);
    }
  }

  Future<void> checkPyramidSolitaireCompletionAchievements({
    required PyramidSolitaireState state,
  }) async {
    if (state.stock.length >= 10) {
      await _markAchievement(Achievement.sunDial);
    }
  }

  Future<void> checkTriPeaksSolitaireMoveAchievements(
      {required TriPeaksSolitaireState state}) async {
    if (state.longestStreak >= 15) {
      await _markAchievement(Achievement.peakPerformance);
    }
  }

  Future<void> checkTriPeaksSolitaireCompletionAchievements({
    required TriPeaksSolitaireState state,
    required Difficulty difficulty,
  }) async {
    if (state.stock.length >= 10) {
      await _markAchievement(Achievement.summitMaster);
    }
  }

  Future<void> deleteAchievement(Achievement achievement) async {
    final saveState = await ref.read(saveStateNotifierProvider.future);
    if (!saveState.achievements.contains(achievement)) {
      return;
    }

    await ref
        .read(saveStateNotifierProvider.notifier)
        .deleteAchievement(achievement: achievement);

    final context = scaffoldMessengerKey.currentContext;
    if (context != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Achievement "${achievement.name}" Deleted!')),
      );
    }
  }

  Future<void> _markAchievement(Achievement achievement) async {
    final saveState = await ref.read(saveStateNotifierProvider.future);
    if (saveState.achievements.contains(achievement)) {
      return;
    }

    await ref
        .read(saveStateNotifierProvider.notifier)
        .saveAchievement(achievement: achievement);

    final context = scaffoldMessengerKey.currentContext;
    if (context != null) {
      CardBack? unlockedBack;
      for (final back in CardBack.values) {
        if (back.achievementLock == achievement) {
          unlockedBack = back;
          break;
        }
      }
      scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Row(
          spacing: 16,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 48,
                child: unlockedBack?.build() ??
                    ColoredBox(
                      color: Colors.white24,
                      child: Icon(
                        Icons.emoji_events,
                        color: Colors.orangeAccent,
                      ),
                    ),
              ),
            ),
            Text('Achievement "${achievement.name}" Unlocked!'),
          ],
        ),
      ));
    }
  }
}

@Riverpod(keepAlive: true)
AchievementService achievementService(Ref ref) => AchievementService(ref);
