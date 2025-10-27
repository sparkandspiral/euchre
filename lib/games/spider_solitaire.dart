import 'package:card_game/card_game.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/services/achievement_service.dart';
import 'package:solitaire/services/audio_service.dart';
// Removed playing_card_style import - custom CardGameStyle is provided here
import 'package:solitaire/styles/playing_card_builder.dart';
import 'package:solitaire/utils/axis_extensions.dart';
import 'package:solitaire/utils/constraints_extensions.dart';
import 'package:solitaire/widgets/card_scaffold.dart';
import 'package:solitaire/widgets/game_tutorial.dart';
import 'package:utils/utils.dart';

// Wrapper class to make each card instance unique even if they have the same suit/value
class SpiderCard extends Equatable {
  final SuitedCard card;
  final int uniqueId;

  const SpiderCard(this.card, this.uniqueId);

  CardSuit get suit => card.suit;
  SuitedCardValue get value => card.value;

  @override
  List<Object?> get props => [card, uniqueId];
}

class SpiderSolitaireState {
  final List<List<SpiderCard>> hiddenCards;
  final List<List<SpiderCard>> revealedCards;
  final List<SpiderCard> stock;
  final int completedSequences;
  final int suitCount;

  final bool usedUndo;
  final List<SpiderSolitaireState> history;

  SpiderSolitaireState({
    required this.hiddenCards,
    required this.revealedCards,
    required this.stock,
    required this.completedSequences,
    required this.suitCount,
    required this.usedUndo,
    required this.history,
  });

  static SpiderSolitaireState getInitialState({required int suitCount}) {
    // Spider Solitaire always uses 104 cards (8 complete suits)
    // 1 suit: 8 sets of same suit
    // 2 suits: 4 sets of each suit
    // 4 suits: 2 sets of each suit
    final suits = CardSuit.values.take(suitCount).toList();
    final setsPerSuit = 8 ~/ suitCount; // 8 sets total divided by number of suits
    var deck = <SpiderCard>[];
    var uniqueId = 0;
    
    // Create the required number of sets per suit to get 104 cards total
    for (var suit in suits) {
      for (var setIndex = 0; setIndex < setsPerSuit; setIndex++) {
        final values = <SuitedCardValue>[
          AceSuitedCardValue(),
          NumberSuitedCardValue(value: 2),
          NumberSuitedCardValue(value: 3),
          NumberSuitedCardValue(value: 4),
          NumberSuitedCardValue(value: 5),
          NumberSuitedCardValue(value: 6),
          NumberSuitedCardValue(value: 7),
          NumberSuitedCardValue(value: 8),
          NumberSuitedCardValue(value: 9),
          NumberSuitedCardValue(value: 10),
          JackSuitedCardValue(),
          QueenSuitedCardValue(),
          KingSuitedCardValue(),
        ];
        
        for (var value in values) {
          deck.add(SpiderCard(SuitedCard(suit: suit, value: value), uniqueId++));
        }
      }
    }

    deck = deck.shuffled();

    // Deal initial tableau: first 4 columns get 6 cards, last 6 get 5 cards
    final hiddenCards = <List<SpiderCard>>[];
    final revealedCards = <List<SpiderCard>>[];

    for (var i = 0; i < 10; i++) {
      final cardsInColumn = i < 4 ? 6 : 5;
      final hidden = deck.take(cardsInColumn - 1).toList();
      deck = deck.skip(cardsInColumn - 1).toList();

      final revealed = [deck.first];
      deck = deck.skip(1).toList();

      hiddenCards.add(hidden);
      revealedCards.add(revealed);
    }

    return SpiderSolitaireState(
      hiddenCards: hiddenCards,
      revealedCards: revealedCards,
      stock: deck,
      completedSequences: 0,
      suitCount: suitCount,
      usedUndo: false,
      history: [],
    );
  }

  int getCardValue(SpiderCard card) => SuitedCardValueMapper.aceAsLowest.getValue(card.card);

  bool isValidSequence(List<SpiderCard> cards) {
    if (cards.isEmpty) return true;

    for (var i = 0; i < cards.length - 1; i++) {
      final currentCard = cards[i];
      final nextCard = cards[i + 1];

      // Must be descending order
      if (getCardValue(currentCard) != getCardValue(nextCard) + 1) {
        return false;
      }
    }

    return true;
  }

  bool isValidSuitSequence(List<SpiderCard> cards) {
    if (cards.isEmpty) return true;
    if (!isValidSequence(cards)) return false;

    final suit = cards.first.suit;
    return cards.every((card) => card.suit == suit);
  }

  bool canMoveToColumn(List<SpiderCard> cards, int targetColumn) {
    if (cards.isEmpty) return false;
    if (!isValidSequence(cards)) return false;

    if (revealedCards[targetColumn].isEmpty) {
      return true;
    }

    final targetTopCard = revealedCards[targetColumn].last;
    final movingBottomCard = cards.first;

    // Can move if the moving card is one less than the target card
    return getCardValue(movingBottomCard) + 1 == getCardValue(targetTopCard);
  }

  SpiderSolitaireState withMoveFromColumn(List<SpiderCard> cards, int fromColumn, int toColumn) {
    if (!canMoveToColumn(cards, toColumn)) {
      return this;
    }

    final newRevealedCards = [...revealedCards];
    newRevealedCards[fromColumn] =
        newRevealedCards[fromColumn].sublist(0, newRevealedCards[fromColumn].length - cards.length);
    newRevealedCards[toColumn] = [...newRevealedCards[toColumn], ...cards];

    final newHiddenCards = [...hiddenCards];

    // Reveal hidden card if revealed cards is empty
    if (newRevealedCards[fromColumn].isEmpty && newHiddenCards[fromColumn].isNotEmpty) {
      newRevealedCards[fromColumn] = [newHiddenCards[fromColumn].last];
      newHiddenCards[fromColumn] = [...newHiddenCards[fromColumn]]..removeLast();
    }

    var newState = copyWith(
      revealedCards: newRevealedCards,
      hiddenCards: newHiddenCards,
    );

    // Check for complete sequences
    return newState._checkAndRemoveCompleteSequences();
  }

  SpiderSolitaireState _checkAndRemoveCompleteSequences() {
    var newRevealedCards = [...revealedCards];
    var newHiddenCards = [...hiddenCards];
    var newCompletedSequences = completedSequences;

    for (var i = 0; i < newRevealedCards.length; i++) {
      final column = newRevealedCards[i];
      if (column.length < 13) continue;

      // Check last 13 cards for complete sequence (King to Ace)
      final last13 = column.sublist(column.length - 13);
      if (last13.length == 13 &&
          isValidSuitSequence(last13) &&
          last13.first.value == KingSuitedCardValue() &&
          last13.last.value == AceSuitedCardValue()) {
        // Remove complete sequence
        newRevealedCards[i] = column.sublist(0, column.length - 13);
        newCompletedSequences++;

        // Reveal hidden card if revealed cards is empty
        if (newRevealedCards[i].isEmpty && newHiddenCards[i].isNotEmpty) {
          newRevealedCards[i] = [newHiddenCards[i].last];
          newHiddenCards[i] = [...newHiddenCards[i]]..removeLast();
        }
      }
    }

    if (newCompletedSequences > completedSequences) {
      return SpiderSolitaireState(
        hiddenCards: newHiddenCards,
        revealedCards: newRevealedCards,
        stock: stock,
        completedSequences: newCompletedSequences,
        suitCount: suitCount,
        usedUndo: usedUndo,
        history: history + [this],
      );
    }

    return this;
  }

  SpiderSolitaireState withDealFromStock() {
    if (stock.length < 10) return this;

    // Check if all columns have at least one card
    if (revealedCards.any((column) => column.isEmpty)) {
      return this;
    }

    final newRevealedCards = [...revealedCards];
    final newStock = [...stock];

    for (var i = 0; i < 10; i++) {
      if (newStock.isEmpty) break;
      newRevealedCards[i] = [...newRevealedCards[i], newStock.first];
      newStock.removeAt(0);
    }

    var newState = copyWith(
      revealedCards: newRevealedCards,
      stock: newStock,
    );

    // Check for complete sequences after dealing
    return newState._checkAndRemoveCompleteSequences();
  }

  SpiderSolitaireState? withAutoMove(int column, List<SpiderCard> cards) {
    if (cards.isEmpty) return null;
    if (!isValidSequence(cards)) return null;

    // Find best column to move to
    List<int> validNonEmptyColumns = [];
    List<int> validEmptyColumns = [];

    for (int i = 0; i < revealedCards.length; i++) {
      if (i != column && canMoveToColumn(cards, i)) {
        if (revealedCards[i].isEmpty) {
          validEmptyColumns.add(i);
        } else {
          validNonEmptyColumns.add(i);
        }
      }
    }

    // Prefer moving to non-empty columns unless moving a King
    if (validNonEmptyColumns.isNotEmpty) {
      return withMoveFromColumn(cards, column, validNonEmptyColumns.first);
    } else if (validEmptyColumns.isNotEmpty && cards.first.value == KingSuitedCardValue()) {
      return withMoveFromColumn(cards, column, validEmptyColumns.first);
    }

    return null;
  }

  SpiderSolitaireState withUndo() {
    return history.last.copyWith(saveNewStateToHistory: false, usedUndo: true);
  }

  bool get isVictory => completedSequences == 8;

  bool get canDeal => stock.length >= 10 && revealedCards.every((column) => column.isNotEmpty);

  SpiderSolitaireState copyWith({
    List<List<SpiderCard>>? hiddenCards,
    List<List<SpiderCard>>? revealedCards,
    List<SpiderCard>? stock,
    int? completedSequences,
    bool? usedUndo,
    bool saveNewStateToHistory = true,
  }) {
    return SpiderSolitaireState(
      hiddenCards: hiddenCards ?? this.hiddenCards,
      revealedCards: revealedCards ?? this.revealedCards,
      stock: stock ?? this.stock,
      completedSequences: completedSequences ?? this.completedSequences,
      suitCount: suitCount,
      usedUndo: usedUndo ?? this.usedUndo,
      history: history + [if (saveNewStateToHistory) this],
    );
  }
}

class SpiderSolitaire extends HookConsumerWidget {
  final Difficulty difficulty;
  final bool startWithTutorial;

  const SpiderSolitaire({super.key, required this.difficulty, this.startWithTutorial = false});

  int get suitCount => switch (difficulty) {
        Difficulty.classic => 1,
        Difficulty.royal => 2,
        Difficulty.ace => 4,
      };

  SpiderSolitaireState get initialState => SpiderSolitaireState.getInitialState(
        suitCount: suitCount,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = useState(initialState);

    useOnListenableChange(
      state,
      () => ref.read(achievementServiceProvider).checkSpiderSolitaireMoveAchievements(state: state.value),
    );

    final tableauKey = useMemoized(() => GlobalKey());
    final stockKey = useMemoized(() => GlobalKey());
    final completedKey = useMemoized(() => GlobalKey());

    void startTutorial() {
      showGameTutorial(
        context,
        screens: [
          TutorialScreen.key(
            key: tableauKey,
            message:
                'Welcome to Spider Solitaire! Build sequences in descending order from King to Ace. You can move any sequence of cards that are in descending order.',
          ),
          TutorialScreen.key(
            key: completedKey,
            message:
                'When you complete a sequence from King to Ace of the same suit, it is automatically removed. Complete all 8 sequences to win!',
          ),
          TutorialScreen.key(
            key: stockKey,
            message:
                'When you run out of moves, tap the stock to deal one card to each column. You must have at least one card in each column before dealing.',
          ),
          TutorialScreen.everything(
            message:
                'Empty columns can be filled with any card or sequence. Try to build in-suit sequences when possible - they move together as a unit. Strategic use of empty columns is key to winning. Tap to begin playing!',
          ),
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
      game: Game.spider,
      difficulty: difficulty,
      onNewGame: () => state.value = initialState,
      onRestart: () => state.value = (state.value.history.firstOrNull ?? state.value).copyWith(usedUndo: false),
      onTutorial: startTutorial,
      onUndo: state.value.history.isEmpty ? null : () => state.value = state.value.withUndo(),
      isVictory: state.value.isVictory,
      onVictory: () => ref
          .read(achievementServiceProvider)
          .checkSpiderSolitaireCompletionAchievements(difficulty: difficulty, state: state.value),
      builder: (context, constraints, cardBack, autoMoveEnabled, gameKey) {
        final axis = constraints.largestAxis;
        final minSize = constraints.smallest.longestSide;
        final spacing = minSize / 100;

        final sizeMultiplier = constraints.findCardSizeMultiplier(
          maxRows: axis == Axis.horizontal ? 4 : 10,
          maxCols: axis == Axis.horizontal ? 10 : 2,
          spacing: spacing,
        );

        final cardOffset = sizeMultiplier * 25;

        final stockDisplay = GestureDetector(
          key: stockKey,
          behavior: HitTestBehavior.opaque,
          onTap: state.value.canDeal
              ? () {
                  ref.read(audioServiceProvider).playDraw();
                  state.value = state.value.withDealFromStock();
                }
              : null,
          child: Opacity(
            opacity: state.value.canDeal ? 1.0 : 0.5,
            child: CardDeck<SpiderCard, dynamic>.flipped(
              value: 'stock',
              values: state.value.stock.take(10).toList(),
            ),
          ),
        );

        final completedDisplay = Column(
          key: completedKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${state.value.completedSequences}/8',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            Text(
              'Complete',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ],
        );

        return CardGame<SpiderCard, dynamic>(
          gameKey: gameKey,
          style: CardGameStyle<SpiderCard, dynamic>(
            cardSize: Size(69, 93) * sizeMultiplier,
            emptyGroupBuilder: (group, state) => Stack(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  decoration: BoxDecoration(
                    color: switch (state) {
                      CardState.regular => Colors.white,
                      CardState.highlighted => Color(0xFF9FC7FF),
                      CardState.error => Color(0xFFFFADAD),
                    }.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            cardBuilder: (value, group, flipped, cardState) => AnimatedFlippable(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              isFlipped: flipped,
              front: Stack(
                fit: StackFit.expand,
                children: [
                  PlayingCardBuilder(card: value.card),
                  Center(
                    child: AnimatedContainer(
                      margin: EdgeInsets.all(2),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      decoration: BoxDecoration(
                        color: switch (cardState) {
                          CardState.regular => null,
                          CardState.highlighted => Color(0xFF9FC7FF).withValues(alpha: 0.5),
                          CardState.error => Color(0xFFFFADAD).withValues(alpha: 0.5),
                        },
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              back: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.hardEdge,
                child: Container(
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: cardBack.build(),
                ),
              ),
            ),
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (axis == Axis.horizontal) ...[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    spacing: spacing * 2,
                    children: [
                      stockDisplay,
                      completedDisplay,
                    ],
                  ),
                  SizedBox(width: spacing),
                ],
                Expanded(
                  child: Flex(
                    key: tableauKey,
                    direction: axis,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: spacing,
                    children: List<Widget>.generate(10, (i) {
                      final hiddenSpiderCards = state.value.hiddenCards[i];
                      final revealedSpiderCards = state.value.revealedCards[i];
                      
                      // Combined list for order/flip state
                      final allSpiderCards = hiddenSpiderCards + revealedSpiderCards;

                      return CardLinearGroup<SpiderCard, dynamic>(
                        value: i,
                        cardOffset: axis.inverted.offset * cardOffset,
                        maxGrabStackSize: null,
                        values: allSpiderCards,
                        canCardBeGrabbed: (_, card) {
                          // Check if card is in revealed cards
                          final cardIndex = allSpiderCards.indexOf(card);
                          if (cardIndex < hiddenSpiderCards.length) return false;
                          
                          // Get spider cards subsequence
                          final revealedIndex = cardIndex - hiddenSpiderCards.length;
                          final subsequence = revealedSpiderCards.sublist(revealedIndex);
                          return state.value.isValidSequence(subsequence);
                        },
                        isCardFlipped: (_, card) => hiddenSpiderCards.contains(card),
                        onCardPressed: (card) {
                          final cardIndex = allSpiderCards.indexOf(card);
                          if (cardIndex < hiddenSpiderCards.length) return;

                          final revealedIndex = cardIndex - hiddenSpiderCards.length;
                          final spiderCards = revealedSpiderCards.sublist(revealedIndex);

                          final newState = state.value.withAutoMove(i, spiderCards);
                          if (newState != null) {
                            ref.read(audioServiceProvider).playPlace();
                            state.value = newState;
                          }
                        },
                        canMoveCardHere: (move) {
                          return state.value.canMoveToColumn(move.cardValues, i);
                        },
                        onCardMovedHere: (move) {
                          if (move.fromGroupValue is! int) return;
                          final fromColumn = move.fromGroupValue as int;
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value.withMoveFromColumn(
                            move.cardValues,
                            fromColumn,
                            i,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
                if (axis == Axis.vertical) ...[
                  SizedBox(width: spacing),
                  Column(
                    spacing: spacing * 2,
                    children: [
                      stockDisplay,
                      completedDisplay,
                    ],
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

