import 'dart:async';
import 'dart:math';

import 'package:card_game/card_game.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:solitaire/model/active_game_snapshot.dart';
import 'package:solitaire/model/daily_challenge.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/immutable_history.dart';
import 'package:solitaire/model/hint.dart';
import 'package:solitaire/services/achievement_service.dart';
import 'package:solitaire/services/audio_service.dart';
import 'package:solitaire/styles/playing_card_style.dart';
import 'package:solitaire/utils/constraints_extensions.dart';
import 'package:solitaire/utils/card_description.dart';
import 'package:solitaire/utils/suited_card_codec.dart';
import 'package:solitaire/widgets/card_scaffold.dart';
import 'package:solitaire/widgets/game_tutorial.dart';
import 'package:utils/utils.dart';
import 'package:solitaire/providers/save_state_notifier.dart';

class TriPeaksSolitaireState {
  final List<List<SuitedCard?>>
      tableau; // 4 rows with peaks structure, null = removed card
  final List<SuitedCard> stock;
  final List<SuitedCard> waste;
  final int streak;
  final int longestStreak;
  final bool canRollover;

  final ImmutableHistory<TriPeaksSolitaireState> history;

  TriPeaksSolitaireState({
    required this.tableau,
    required this.stock,
    required this.waste,
    required this.streak,
    required this.longestStreak,
    required this.canRollover,
    required this.history,
  });

  static TriPeaksSolitaireState getInitialState({
    required bool startWithWaste,
    required bool canRollover,
    int? shuffleSeed,
  }) {
    final random = shuffleSeed == null ? Random() : Random(shuffleSeed);
    var deck = List.of(SuitedCard.deck)..shuffle(random);

    // Classic Tri-Peaks layout: 28 cards in 4 rows forming 3 peaks
    // Row 0 (peaks): 3 cards (indices 0, 1, 2)
    // Row 1: 6 cards (indices 0-5)
    // Row 2: 9 cards (indices 0-8)
    // Row 3 (base): 10 cards (indices 0-9)
    // Total: 28 cards

    final tableau = <List<SuitedCard?>>[];

    // Row 0: 3 cards (peaks) - these will be at positions 0, 1, 2
    tableau.add(deck.take(3).toList());
    deck = deck.skip(3).toList();

    // Row 1: 6 cards
    tableau.add(deck.take(6).toList());
    deck = deck.skip(6).toList();

    // Row 2: 9 cards
    tableau.add(deck.take(9).toList());
    deck = deck.skip(9).toList();

    // Row 3: 10 cards (bottom row - always exposed)
    tableau.add(deck.take(10).toList());
    deck = deck.skip(10).toList();

    // Remaining cards become stock
    var waste = <SuitedCard>[];
    if (startWithWaste && deck.isNotEmpty) {
      waste.add(deck.first);
      deck = deck.skip(1).toList();
    }

    return TriPeaksSolitaireState(
      tableau: tableau,
      stock: deck,
      waste: waste,
      streak: 0,
      longestStreak: 0,
      canRollover: canRollover,
      history: const ImmutableHistory.empty(),
    );
  }

  Map<String, dynamic> toJson() => {
        'tableau': tableau
            .map((row) => row
                .map((card) => card == null ? null : encodeSuitedCard(card))
                .toList())
            .toList(),
        'stock': stock.map(encodeSuitedCard).toList(),
        'waste': waste.map(encodeSuitedCard).toList(),
        'streak': streak,
        'longestStreak': longestStreak,
        'canRollover': canRollover,
      };

  factory TriPeaksSolitaireState.fromJson(Map<String, dynamic> json) {
    List<List<SuitedCard?>> decodeTableau(List<dynamic> data) => data
        .map<List<SuitedCard?>>((row) => (row as List)
            .map<SuitedCard?>((card) => card == null
                ? null
                : decodeSuitedCard(
                    Map<String, dynamic>.from(card as Map<dynamic, dynamic>)))
            .toList())
        .toList();
    List<SuitedCard> decodeList(List<dynamic> data) => data
        .map((card) => decodeSuitedCard(
            Map<String, dynamic>.from(card as Map<dynamic, dynamic>)))
        .toList();

    return TriPeaksSolitaireState(
      tableau: decodeTableau(json['tableau'] as List<dynamic>),
      stock: decodeList(json['stock'] as List<dynamic>),
      waste: decodeList(json['waste'] as List<dynamic>),
      streak: json['streak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      canRollover: json['canRollover'] as bool? ?? true,
      history: const ImmutableHistory.empty(),
    );
  }

  SuitedCardDistanceMapper get distanceMapper => canRollover
      ? SuitedCardDistanceMapper.rollover
      : SuitedCardDistanceMapper.aceToKing;

  bool canSelect(SuitedCard card) =>
      waste.isEmpty || distanceMapper.getDistance(waste.last, card) == 1;

  // Check if a card is exposed (not covered by any cards in the row below)
  // Classic Tri-Peaks coverage pattern:
  // Row 0: card at index i is covered by cards at row 1 indices [i*2, i*2+1]
  // Row 1: card at index i is covered by cards at row 2 indices based on peak group
  // Row 2: card at index i is covered by cards at row 3 indices [i, i+1]
  bool isCardExposed(int row, int col) {
    final card = tableau[row][col];
    if (card == null) return false; // Card already removed
    if (row == 3) return true; // Bottom row is always exposed

    if (row == 0) {
      // Peak cards: Each peak (0, 1, 2) is covered by 2 cards in row 1
      final leftChild = col * 2;
      final rightChild = col * 2 + 1;
      return tableau[1][leftChild] == null && tableau[1][rightChild] == null;
    } else if (row == 1) {
      // Row 1: Covered by row 2 cards
      // Each pair in row 1 corresponds to a group of 3 in row 2
      final peakGroup = col ~/ 2; // Which peak (0, 1, or 2)
      final posInPair = col % 2; // Position within pair (0 or 1)
      final baseIndex = peakGroup * 3;

      if (posInPair == 0) {
        // Left card of pair: covered by left and middle of trio
        return tableau[2][baseIndex] == null &&
            tableau[2][baseIndex + 1] == null;
      } else {
        // Right card of pair: covered by middle and right of trio
        return tableau[2][baseIndex + 1] == null &&
            tableau[2][baseIndex + 2] == null;
      }
    } else if (row == 2) {
      // Row 2: Covered by row 3 cards
      final leftChild = col;
      final rightChild = col + 1;
      return tableau[3][leftChild] == null && tableau[3][rightChild] == null;
    }

    return true;
  }

  TriPeaksSolitaireState withSelection(int row, int col) {
    final card = tableau[row][col];
    if (card == null) return this;

    final newTableau = tableau.map((r) => [...r]).toList();
    newTableau[row][col] = null;

    final newStreak = streak + 1;
    return TriPeaksSolitaireState(
      tableau: newTableau,
      stock: stock,
      waste: waste + [card],
      streak: newStreak,
      longestStreak: newStreak > longestStreak ? newStreak : longestStreak,
      canRollover: canRollover,
      history: history.pushCapped(this, maxLength: kDefaultHistoryLimit),
    );
  }

  bool get canDraw => stock.isNotEmpty;

  TriPeaksSolitaireState withDraw() => TriPeaksSolitaireState(
        tableau: tableau,
        stock: stock.sublist(0, stock.length - 1),
        waste: waste + [stock.last],
        streak: 0,
        longestStreak: longestStreak,
        canRollover: canRollover,
        history: history.pushCapped(this, maxLength: kDefaultHistoryLimit),
      );

  HintSuggestion? findHint() {
    final wasteCard = waste.lastOrNull;
    for (int row = 0; row < tableau.length; row++) {
      for (int col = 0; col < tableau[row].length; col++) {
        final card = tableau[row][col];
        if (card == null || !isCardExposed(row, col) || !canSelect(card)) {
          continue;
        }

        final target = wasteCard == null
            ? 'start the waste pile'
            : 'play on ${describeCard(wasteCard)}';
        return HintSuggestion(
          message:
              'Play ${describeCard(card)} from ${describeRowPosition(row, col)} to $target.',
        );
      }
    }

    if (canDraw) {
      return const HintSuggestion(
        message: 'Draw a card from the stock to refresh the waste pile.',
      );
    }

    return null;
  }

  TriPeaksSolitaireState withUndo() => history.last;

  bool get isVictory =>
      tableau.every((row) => row.every((card) => card == null));

  bool get hasAvailableMoves {
    if (canDraw) return true;

    for (var row = 0; row < tableau.length; row++) {
      for (var col = 0; col < tableau[row].length; col++) {
        final card = tableau[row][col];
        if (card != null && isCardExposed(row, col) && canSelect(card)) {
          return true;
        }
      }
    }
    return false;
  }
}

class TriPeaksSolitaire extends HookConsumerWidget {
  final Difficulty difficulty;
  final bool startWithTutorial;
  final DailyChallengeConfig? dailyChallenge;
  final ActiveGameSnapshot? snapshot;

  const TriPeaksSolitaire({
    super.key,
    required this.difficulty,
    this.startWithTutorial = false,
    this.dailyChallenge,
    this.snapshot,
  });

  TriPeaksSolitaireState get defaultInitialState =>
      TriPeaksSolitaireState.getInitialState(
        startWithWaste: difficulty.index >= Difficulty.royal.index,
        canRollover: difficulty != Difficulty.ace,
        shuffleSeed: dailyChallenge?.shuffleSeed,
      );

  TriPeaksSolitaireState get initialState {
    if (dailyChallenge != null) return defaultInitialState;
    if (snapshot != null) {
      try {
        return TriPeaksSolitaireState.fromJson(snapshot!.state);
      } catch (_) {
        return defaultInitialState;
      }
    }
    return defaultInitialState;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = useState(initialState);
    final startReference = useState<DateTime>(
      DateTime.now().subtract(
        Duration(milliseconds: snapshot?.elapsedMilliseconds ?? 0),
      ),
    );
    final saveStateNotifier = ref.read(saveStateNotifierProvider.notifier);

    Future<void> persistSnapshot() async {
      if (dailyChallenge != null || state.value.isVictory) return;
      final activeSnapshot = ActiveGameSnapshot(
        game: Game.triPeaks,
        difficulty: difficulty,
        isDaily: false,
        shuffleSeed: null,
        state: state.value.toJson(),
        updatedAt: DateTime.now(),
        elapsedMilliseconds:
            DateTime.now().difference(startReference.value).inMilliseconds,
      );
      await saveStateNotifier.saveActiveGameSnapshot(activeSnapshot);
    }

    Future<void> clearSnapshot() =>
        saveStateNotifier.clearActiveGame(Game.triPeaks);

    useOnListenableChange(
      state,
      () => ref
          .read(achievementServiceProvider)
          .checkTriPeaksSolitaireMoveAchievements(state: state.value),
    );

    final tableauKey = useMemoized(() => GlobalKey());
    final wasteKey = useMemoized(() => GlobalKey());
    final stockKey = useMemoized(() => GlobalKey());

    void startTutorial() {
      showGameTutorial(
        context,
        screens: [
          TutorialScreen.key(
            key: tableauKey,
            message:
                'Welcome to Tri-Peaks! Your goal is to clear all cards from the three pyramid peaks by selecting cards that are one rank higher or lower than the waste pile card.',
          ),
          TutorialScreen.key(
            key: wasteKey,
            message:
                'Select exposed cards (not covered by other cards) that are one higher or one lower than the current waste card. Build long streaks for bonus points!',
          ),
          TutorialScreen.key(
            key: stockKey,
            message:
                'When no moves are available, tap the stock pile to draw a new card to the waste pile. Plan carefully - you only get one pass through the deck!',
          ),
          TutorialScreen.everything(
              message:
                  'Clear all three peaks to win! The longer your card streak, the better. Tap to begin playing!'),
        ],
      );
    }

    useOneTimeEffect(() {
      if (startWithTutorial) {
        Future.delayed(Duration(milliseconds: 200))
            .then((_) => startTutorial());
      }
      return null;
    });

    useOnListenableChange(
      state,
      () {
        if (!state.value.isVictory) {
          persistSnapshot();
        }
      },
    );

    return CardScaffold(
      game: Game.triPeaks,
      difficulty: difficulty,
      dailyChallenge: dailyChallenge,
      initialElapsed:
          Duration(milliseconds: snapshot?.elapsedMilliseconds ?? 0),
      onNewGame: () {
        if (dailyChallenge == null) {
          unawaited(clearSnapshot());
        }
        startReference.value = DateTime.now();
        state.value = defaultInitialState;
      },
      onRestart: () {
        startReference.value = DateTime.now();
        state.value = state.value.history.firstOrNull ?? state.value;
      },
      onUndo: state.value.history.isEmpty
          ? null
          : () => state.value = state.value.withUndo(),
      onHint: () => state.value.findHint(),
      isVictory: state.value.isVictory,
      hasMoves: state.value.hasAvailableMoves,
      onTutorial: startTutorial,
      onVictory: (_, __) async {
        await ref
            .read(achievementServiceProvider)
            .checkTriPeaksSolitaireCompletionAchievements(
                state: state.value, difficulty: difficulty);
        if (dailyChallenge == null) {
          await clearSnapshot();
        }
      },
      builder: (context, constraints, cardBack, autoMoveEnabled, gameKey) {
        final axis = constraints.largestAxis;
        final minSize = constraints.smallest.longestSide;
        final spacing = minSize / 100;
        final maxRows = axis == Axis.vertical ? 7.4 : 6.0;
        final maxCols = axis == Axis.vertical ? 9.0 : 13.0;

        double sizeMultiplier;
        final verticalMultiplier =
            ((constraints.maxHeight - (maxRows - 1) * spacing) / maxRows) / 93;
        final horizontalGap = axis == Axis.vertical ? 1.0 : spacing;
        final outerMargin = axis == Axis.vertical ? spacing * 0.25 : spacing;

        if (axis == Axis.vertical) {
          final availableWidth =
              constraints.maxWidth - outerMargin * 2 - horizontalGap * 9;
          final horizontalMultiplier =
              availableWidth > 0 ? availableWidth / (69 * 10) : verticalMultiplier;
          sizeMultiplier = min(horizontalMultiplier, verticalMultiplier);
        } else {
          sizeMultiplier = constraints.findCardSizeMultiplier(
            maxRows: maxRows,
            maxCols: maxCols,
            spacing: spacing,
          );
        }

        final cardWidth = 69 * sizeMultiplier;
        final cardHeight = 93 * sizeMultiplier;
        final cardSpacingX = cardWidth + horizontalGap;
        final rowStep = cardHeight * 0.55;

        // Build a single card widget
        Widget buildCard(int row, int col) {
          final card = state.value.tableau[row][col];
          final isExposed = card != null && state.value.isCardExposed(row, col);
          final canSelect =
              card != null && isExposed && state.value.canSelect(card);

          return SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: canSelect
                  ? () {
                      ref.read(audioServiceProvider).playPlace();
                      state.value = state.value.withSelection(row, col);
                    }
                  : null,
              child: CardLinearGroup<SuitedCard, dynamic>(
                value: 'card-$row-$col',
                values: card == null ? const <SuitedCard>[] : [card],
                maxGrabStackSize: 0,
                cardOffset: Offset.zero,
                canCardBeGrabbed: (_, __) => false,
                isCardFlipped: card == null
                    ? null
                    : (_, __) => !isExposed, // Face down if not exposed
              ),
            ),
          );
        }

        final tableauHeight = cardHeight + rowStep * 3;

        // Build the three peaks layout with overlapping structure
        Widget buildTriPeaks() {
          final row3Lefts =
              List<double>.generate(10, (i) => outerMargin + i * cardSpacingX);
          final row3Centers =
              row3Lefts.map((left) => left + cardWidth / 2).toList();

          final row2Lefts = List<double>.generate(9, (i) {
            final center = (row3Centers[i] + row3Centers[i + 1]) / 2;
            return center - cardWidth / 2;
          });
          final row2Centers =
              row2Lefts.map((left) => left + cardWidth / 2).toList();

          final row1Lefts = List<double>.generate(6, (col) {
            final peakGroup = col ~/ 2;
            final posInPair = col % 2;
            final baseIndex = peakGroup * 3;
            final first = posInPair == 0 ? baseIndex : baseIndex + 1;
            final second = posInPair == 0 ? baseIndex + 1 : baseIndex + 2;
            final center = (row2Centers[first] + row2Centers[second]) / 2;
            return center - cardWidth / 2;
          });
          final row1Centers =
              row1Lefts.map((left) => left + cardWidth / 2).toList();

          final row0Lefts = List<double>.generate(3, (col) {
            final leftChild = col * 2;
            final rightChild = col * 2 + 1;
            final center =
                (row1Centers[leftChild] + row1Centers[rightChild]) / 2;
            return center - cardWidth / 2;
          });

          final rowTops = [
            0.0,
            rowStep,
            rowStep * 2,
            rowStep * 3,
          ];

          final rows = [
            (row: 0, tops: rowTops[0], lefts: row0Lefts),
            (row: 1, tops: rowTops[1], lefts: row1Lefts),
            (row: 2, tops: rowTops[2], lefts: row2Lefts),
            (row: 3, tops: rowTops[3], lefts: row3Lefts),
          ];

          final positionedCards = <Widget>[];
          for (final entry in rows) {
            for (var col = 0; col < entry.lefts.length; col++) {
              positionedCards.add(
                Positioned(
                  top: entry.tops,
                  left: entry.lefts[col],
                  child: buildCard(entry.row, col),
                ),
              );
            }
          }

          final tableauWidth = row3Lefts.last + cardWidth + outerMargin;

          return SizedBox(
            width: tableauWidth,
            height: tableauHeight,
            key: tableauKey,
            child: Stack(
              clipBehavior: Clip.none,
              children: positionedCards,
            ),
          );
        }

        final stockDeck = CardDeck<SuitedCard, dynamic>.flipped(
          key: stockKey,
          value: 'stock',
          values: state.value.stock,
          onCardPressed: (_) {
            if (state.value.canDraw) {
              ref.read(audioServiceProvider).playDraw();
              state.value = state.value.withDraw();
            }
          },
        );

        final wasteDeck = CardDeck<SuitedCard, dynamic>(
          key: wasteKey,
          value: 'waste',
          values: state.value.waste,
        );

        Widget buildPiles() {
          final deckDisplay = axis == Axis.vertical
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    stockDeck,
                    SizedBox(width: spacing * 2),
                    wasteDeck,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: spacing * 2,
                  children: [
                    stockDeck,
                    wasteDeck,
                  ],
                );

          return Column(
            mainAxisSize: MainAxisSize.min,
            spacing: spacing * 2,
            children: [
              deckDisplay,
            ],
          );
        }

        final deckGap = spacing + cardHeight * 0.1;

        return CardGame<SuitedCard, dynamic>(
          gameKey: gameKey,
          style: playingCardStyle(
              sizeMultiplier: sizeMultiplier, cardBack: cardBack),
          children: [
            if (axis == Axis.horizontal)
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: buildTriPeaks(),
                    ),
                  ),
                  SizedBox(width: spacing * 2),
                  buildPiles(),
                ],
              )
            else
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: tableauHeight,
                            child: Align(
                              alignment: Alignment.center,
                              child: buildTriPeaks(),
                            ),
                          ),
                          SizedBox(height: deckGap),
                          buildPiles(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
