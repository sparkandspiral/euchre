import 'package:card_game/card_game.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/services/achievement_service.dart';
import 'package:solitaire/services/audio_service.dart';
import 'package:solitaire/styles/playing_card_style.dart';
import 'package:solitaire/utils/constraints_extensions.dart';
import 'package:solitaire/widgets/card_scaffold.dart';
import 'package:solitaire/widgets/game_tutorial.dart';
import 'package:utils/utils.dart';

class TriPeaksSolitaireState {
  final List<List<SuitedCard>> tableau; // 4 rows with peaks structure
  final List<SuitedCard> stock;
  final List<SuitedCard> waste;
  final int streak;
  final int longestStreak;
  final bool canRollover;

  final List<TriPeaksSolitaireState> history;

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
  }) {
    var deck = SuitedCard.deck.shuffled();

    // Tri-Peaks layout: 18 cards in 4 rows forming 3 peaks
    // Row 0 (top): 3 cards (one per peak)
    // Row 1: 6 cards
    // Row 2: 9 cards
    // Row 3 (bottom): 10 cards in a line (not part of peaks)
    // Total in tableau: 28 cards

    final tableau = <List<SuitedCard>>[];
    
    // Row 0: 3 cards (peaks)
    tableau.add(deck.take(3).toList());
    deck = deck.skip(3).toList();
    
    // Row 1: 6 cards
    tableau.add(deck.take(6).toList());
    deck = deck.skip(6).toList();
    
    // Row 2: 9 cards
    tableau.add(deck.take(9).toList());
    deck = deck.skip(9).toList();
    
    // Row 3: 10 cards (bottom row)
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
      history: [],
    );
  }

  SuitedCardDistanceMapper get distanceMapper =>
      canRollover ? SuitedCardDistanceMapper.rollover : SuitedCardDistanceMapper.aceToKing;

  bool canSelect(SuitedCard card) =>
      waste.isEmpty || distanceMapper.getDistance(waste.last, card) == 1;

  // Check if a card is exposed (not covered by any cards in the row below)
  bool isCardExposed(int row, int col) {
    if (row == 3) return true; // Bottom row is always exposed

    // For rows 0-2, check if any cards in the next row cover this card
    // A card at (row, col) is covered by cards at (row+1, col) and (row+1, col+1) for peaks
    // But we need to handle the three-peak structure

    // Peak structure coverage:
    // Row 0 (positions 0,1,2) -> covered by Row 1 (positions 0-1, 2-3, 4-5)
    // Row 1 (positions 0-5) -> covered by Row 2 (positions 0-8)
    // Row 2 (positions 0-8) -> covered by Row 3 (positions 0-9)

    if (row == 0) {
      // Three peaks at top
      final leftChild = col * 2;
      final rightChild = col * 2 + 1;
      return tableau[1].length <= leftChild || tableau[1].length <= rightChild;
    } else if (row == 1) {
      // Second row
      final leftChild = (col ~/ 2) * 3 + (col % 2) * 1;
      final rightChild = leftChild + 1;
      return tableau[2].length <= leftChild || tableau[2].length <= rightChild;
    } else if (row == 2) {
      // Third row
      final childIndex = col;
      return tableau[3].length <= childIndex || tableau[3].length <= childIndex + 1;
    }

    return true;
  }

  TriPeaksSolitaireState withSelection(int row, int col) {
    final card = tableau[row][col];
    final newTableau = tableau.mapIndexed((r, cards) {
      if (r == row) {
        return [...cards]..removeAt(col);
      }
      return [...cards];
    }).toList();

    final newStreak = streak + 1;
    return TriPeaksSolitaireState(
      tableau: newTableau,
      stock: stock,
      waste: waste + [card],
      streak: newStreak,
      longestStreak: newStreak > longestStreak ? newStreak : longestStreak,
      canRollover: canRollover,
      history: history + [this],
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
        history: history + [this],
      );

  TriPeaksSolitaireState withUndo() => history.last;

  bool get isVictory => tableau.every((row) => row.isEmpty);

  bool get hasAvailableMoves {
    if (canDraw) return true;
    
    for (var row = 0; row < tableau.length; row++) {
      for (var col = 0; col < tableau[row].length; col++) {
        if (isCardExposed(row, col) && canSelect(tableau[row][col])) {
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

  const TriPeaksSolitaire({
    super.key,
    required this.difficulty,
    this.startWithTutorial = false,
  });

  TriPeaksSolitaireState get initialState => TriPeaksSolitaireState.getInitialState(
        startWithWaste: difficulty.index >= Difficulty.royal.index,
        canRollover: difficulty != Difficulty.ace,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = useState(initialState);
    useOnListenableChange(
      state,
      () => ref.read(achievementServiceProvider).checkTriPeaksSolitaireMoveAchievements(state: state.value),
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
        Future.delayed(Duration(milliseconds: 200)).then((_) => startTutorial());
      }
      return null;
    });

    return CardScaffold(
      game: Game.triPeaks,
      difficulty: difficulty,
      onNewGame: () => state.value = initialState,
      onRestart: () => state.value = state.value.history.firstOrNull ?? state.value,
      onUndo: state.value.history.isEmpty ? null : () => state.value = state.value.withUndo(),
      isVictory: state.value.isVictory,
      onTutorial: startTutorial,
      onVictory: () => ref
          .read(achievementServiceProvider)
          .checkTriPeaksSolitaireCompletionAchievements(state: state.value, difficulty: difficulty),
      builder: (context, constraints, cardBack, autoMoveEnabled, gameKey) {
        final axis = constraints.largestAxis;
        final minSize = constraints.smallest.longestSide;
        final spacing = minSize / 100;

        final sizeMultiplier = constraints.findCardSizeMultiplier(
          maxRows: axis == Axis.horizontal ? 5 : 10,
          maxCols: axis == Axis.horizontal ? 12 : 10,
          spacing: spacing,
        );

        final cardWidth = 69 * sizeMultiplier;
        final cardHeight = 93 * sizeMultiplier;

        // Build the three peaks layout
        Widget buildTriPeaks() {
          return Stack(
            key: tableauKey,
            children: [
              // Row 3 (bottom) - 10 cards in a line
              Positioned(
                top: cardHeight * 3 + spacing * 3,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: (cardWidth + spacing) * 10 - spacing,
                    height: cardHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(state.value.tableau[3].length, (col) {
                        final card = state.value.tableau[3][col];
                        final isExposed = state.value.isCardExposed(3, col);
                        final canSelect = isExposed && state.value.canSelect(card);
                        
                        return Padding(
                          padding: EdgeInsets.only(right: col < state.value.tableau[3].length - 1 ? spacing : 0),
                          child: Opacity(
                            opacity: !isExposed ? 0.7 : 1.0,
                            child: Container(
                              decoration: canSelect
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.6),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              // Row 2 - 9 cards
              Positioned(
                top: cardHeight * 2 + spacing * 2,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: (cardWidth + spacing) * 9 - spacing,
                    height: cardHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(state.value.tableau[2].length, (col) {
                        final card = state.value.tableau[2][col];
                        final isExposed = state.value.isCardExposed(2, col);
                        final canSelect = isExposed && state.value.canSelect(card);
                        
                        return Padding(
                          padding: EdgeInsets.only(right: col < state.value.tableau[2].length - 1 ? spacing : 0),
                          child: Opacity(
                            opacity: !isExposed ? 0.7 : 1.0,
                            child: Container(
                              decoration: canSelect
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.6),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              // Row 1 - 6 cards
              Positioned(
                top: cardHeight + spacing,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: (cardWidth + spacing) * 6 - spacing,
                    height: cardHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(state.value.tableau[1].length, (col) {
                        final card = state.value.tableau[1][col];
                        final isExposed = state.value.isCardExposed(1, col);
                        final canSelect = isExposed && state.value.canSelect(card);
                        
                        return Padding(
                          padding: EdgeInsets.only(right: col < state.value.tableau[1].length - 1 ? spacing : 0),
                          child: Opacity(
                            opacity: !isExposed ? 0.7 : 1.0,
                            child: Container(
                              decoration: canSelect
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.6),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              // Row 0 (top) - 3 cards (peaks)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: (cardWidth + spacing) * 3 - spacing,
                    height: cardHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(state.value.tableau[0].length, (col) {
                        final card = state.value.tableau[0][col];
                        final isExposed = state.value.isCardExposed(0, col);
                        final canSelect = isExposed && state.value.canSelect(card);
                        
                        return Padding(
                          padding: EdgeInsets.only(right: col < state.value.tableau[0].length - 1 ? spacing : 0),
                          child: Opacity(
                            opacity: !isExposed ? 0.7 : 1.0,
                            child: Container(
                              decoration: canSelect
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.6),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        Widget buildTriPeaksCards() {
          return Stack(
            children: [
              // Row 3 cards
              Positioned(
                top: cardHeight * 3 + spacing * 3,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: (cardWidth + spacing) * 10 - spacing,
                    height: cardHeight,
                    child: CardLinearGroup<SuitedCard, dynamic>(
                      value: 'row-3',
                      values: state.value.tableau[3],
                      maxGrabStackSize: 0,
                      cardOffset: Offset(cardWidth + spacing, 0),
                      canCardBeGrabbed: (_, __) => false,
                      onCardPressed: (card) {
                        final col = state.value.tableau[3].indexOf(card);
                        if (col == -1) return;
                        if (state.value.isCardExposed(3, col) && state.value.canSelect(card)) {
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value.withSelection(3, col);
                        }
                      },
                    ),
                  ),
                ),
              ),
              // Row 2 cards
              Positioned(
                top: cardHeight * 2 + spacing * 2,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: (cardWidth + spacing) * 9 - spacing,
                    height: cardHeight,
                    child: CardLinearGroup<SuitedCard, dynamic>(
                      value: 'row-2',
                      values: state.value.tableau[2],
                      maxGrabStackSize: 0,
                      cardOffset: Offset(cardWidth + spacing, 0),
                      canCardBeGrabbed: (_, __) => false,
                      onCardPressed: (card) {
                        final col = state.value.tableau[2].indexOf(card);
                        if (col == -1) return;
                        if (state.value.isCardExposed(2, col) && state.value.canSelect(card)) {
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value.withSelection(2, col);
                        }
                      },
                    ),
                  ),
                ),
              ),
              // Row 1 cards
              Positioned(
                top: cardHeight + spacing,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: (cardWidth + spacing) * 6 - spacing,
                    height: cardHeight,
                    child: CardLinearGroup<SuitedCard, dynamic>(
                      value: 'row-1',
                      values: state.value.tableau[1],
                      maxGrabStackSize: 0,
                      cardOffset: Offset(cardWidth + spacing, 0),
                      canCardBeGrabbed: (_, __) => false,
                      onCardPressed: (card) {
                        final col = state.value.tableau[1].indexOf(card);
                        if (col == -1) return;
                        if (state.value.isCardExposed(1, col) && state.value.canSelect(card)) {
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value.withSelection(1, col);
                        }
                      },
                    ),
                  ),
                ),
              ),
              // Row 0 cards (peaks)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: (cardWidth + spacing) * 3 - spacing,
                    height: cardHeight,
                    child: CardLinearGroup<SuitedCard, dynamic>(
                      value: 'row-0',
                      values: state.value.tableau[0],
                      maxGrabStackSize: 0,
                      cardOffset: Offset(cardWidth + spacing, 0),
                      canCardBeGrabbed: (_, __) => false,
                      onCardPressed: (card) {
                        final col = state.value.tableau[0].indexOf(card);
                        if (col == -1) return;
                        if (state.value.isCardExposed(0, col) && state.value.canSelect(card)) {
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value.withSelection(0, col);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return CardGame<SuitedCard, dynamic>(
          gameKey: gameKey,
          style: playingCardStyle(sizeMultiplier: sizeMultiplier, cardBack: cardBack),
          children: [
            Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      buildTriPeaks(),
                      buildTriPeaksCards(),
                    ],
                  ),
                ),
                SizedBox(width: spacing * 2),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: spacing * 3,
                  children: [
                    // Streak indicator
                    if (state.value.streak > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'Streak: ${state.value.streak}',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16 * sizeMultiplier,
                          ),
                        ),
                      ),
                    CardDeck<SuitedCard, dynamic>.flipped(
                      key: stockKey,
                      value: 'stock',
                      values: state.value.stock,
                      onCardPressed: (_) {
                        if (state.value.canDraw) {
                          ref.read(audioServiceProvider).playDraw();
                          state.value = state.value.withDraw();
                        }
                      },
                    ),
                    CardDeck<SuitedCard, dynamic>(
                      key: wasteKey,
                      value: 'waste',
                      values: state.value.waste,
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

