import 'dart:async';
import 'dart:math';

import 'package:card_game/card_game.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
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
import 'package:solitaire/styles/playing_card_asset_bundle_cache.dart';
import 'package:solitaire/styles/playing_card_style.dart';
import 'package:solitaire/utils/axis_extensions.dart';
import 'package:solitaire/utils/constraints_extensions.dart';
import 'package:solitaire/utils/card_description.dart';
import 'package:solitaire/utils/suited_card_codec.dart';
import 'package:solitaire/utils/shuffle.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/widgets/card_scaffold.dart';
import 'package:solitaire/widgets/delayed_auto_move_listener.dart';
import 'package:solitaire/widgets/game_tutorial.dart';
import 'package:utils/utils.dart';
import 'package:vector_graphics/vector_graphics.dart';

abstract class GroupValue extends Equatable {
  const GroupValue();
}

class TableauGroupValue extends GroupValue {
  final int columnIndex;

  const TableauGroupValue(this.columnIndex);

  @override
  List<Object?> get props => [columnIndex];
}

class FreeCellGroupValue extends GroupValue {
  final int cellIndex;

  const FreeCellGroupValue(this.cellIndex);

  @override
  List<Object?> get props => [cellIndex];
}

class FoundationGroupValue extends GroupValue {
  final CardSuit suit;

  const FoundationGroupValue(this.suit);

  @override
  List<Object?> get props => [suit];
}

class FreeCellState {
  final List<List<SuitedCard>> tableauCards;
  final List<SuitedCard?> freeCells;
  final Map<CardSuit, List<SuitedCard>> foundationCards;

  final bool usedUndo;
  final bool canAutoMove;
  final ImmutableHistory<FreeCellState> history;

  FreeCellState({
    required this.tableauCards,
    required this.freeCells,
    required this.foundationCards,
    required this.usedUndo,
    required this.canAutoMove,
    required this.history,
  });

  static FreeCellState getInitialState({
    required int freeCellCount,
    required bool acesAtBottom,
    int? shuffleSeed,
  }) {
    var deck = List.of(SuitedCard.deck);
    if (shuffleSeed == null) {
      deck.shuffle();
    } else {
      shuffleWithSeed(deck, shuffleSeed);
    }

    final aces =
        deck.where((card) => card.value == AceSuitedCardValue()).toList();
    if (acesAtBottom) {
      deck = deck.where((card) => card.value != AceSuitedCardValue()).toList();
    }

    final tableauCards = List.generate(8, (i) {
      final cardsPerColumn = i < 4 ? 7 : 6;
      final cardsToTake = cardsPerColumn - (acesAtBottom && i < 4 ? 1 : 0);

      final column = deck.take(cardsToTake).toList();
      deck = deck.skip(cardsToTake).toList();

      if (acesAtBottom && i < 4 && aces.isNotEmpty) {
        column.insert(0, aces.removeAt(0));
      }

      return column;
    });

    return FreeCellState(
      tableauCards: tableauCards,
      freeCells: List.filled(freeCellCount, null),
      foundationCards:
          Map.fromEntries(CardSuit.values.map((suit) => MapEntry(suit, []))),
      usedUndo: false,
      history: const ImmutableHistory.empty(),
      canAutoMove: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'tableau': tableauCards
            .map((column) => column.map(encodeSuitedCard).toList())
            .toList(),
        'freeCells': freeCells
            .map((card) => card == null ? null : encodeSuitedCard(card))
            .toList(),
        'foundations': foundationCards.map((suit, cards) => MapEntry(
            suit.index.toString(), cards.map(encodeSuitedCard).toList())),
        'usedUndo': usedUndo,
        'canAutoMove': canAutoMove,
      };

  factory FreeCellState.fromJson(Map<String, dynamic> json) {
    List<List<SuitedCard>> decodeTableau(List<dynamic> data) => data
        .map<List<SuitedCard>>((column) => (column as List)
            .map((card) => decodeSuitedCard(
                Map<String, dynamic>.from(card as Map<dynamic, dynamic>)))
            .toList())
        .toList();

    List<SuitedCard?> decodeFreeCells(List<dynamic> data) => data
        .map<SuitedCard?>((value) => value == null
            ? null
            : decodeSuitedCard(
                Map<String, dynamic>.from(value as Map<dynamic, dynamic>)))
        .toList();

    final foundationsJson =
        (json['foundations'] as Map?)?.cast<String, dynamic>() ?? {};
    final foundations = <CardSuit, List<SuitedCard>>{};
    foundationsJson.forEach((key, value) {
      final suit = CardSuit.values[int.parse(key)];
      foundations[suit] = (value as List)
          .map((card) => decodeSuitedCard(
              Map<String, dynamic>.from(card as Map<dynamic, dynamic>)))
          .toList();
    });

    return FreeCellState(
      tableauCards: decodeTableau(json['tableau'] as List<dynamic>),
      freeCells: decodeFreeCells(json['freeCells'] as List<dynamic>),
      foundationCards: foundations,
      usedUndo: json['usedUndo'] as bool? ?? false,
      canAutoMove: json['canAutoMove'] as bool? ?? true,
      history: const ImmutableHistory.empty(),
    );
  }

  int getCardValue(SuitedCard card) =>
      SuitedCardValueMapper.aceAsLowest.getValue(card);

  int get maxMoveSize {
    final emptyCells = freeCells.where((cell) => cell == null).length;
    final emptyTableaux = tableauCards.where((column) => column.isEmpty).length;

    return (emptyCells + 1) * pow(2, emptyTableaux).toInt();
  }

  int getMaxMoveSizeForTarget(int targetColumn) {
    final emptyCells = freeCells.where((cell) => cell == null).length;
    final emptyTableauxCount =
        tableauCards.where((column) => column.isEmpty).length;

    final effectiveEmptyTableauxCount = tableauCards[targetColumn].isEmpty
        ? max(0, emptyTableauxCount - 1)
        : emptyTableauxCount;

    return (emptyCells + 1) * pow(2, effectiveEmptyTableauxCount).toInt();
  }

  bool canAddToFoundation(SuitedCard card) {
    final foundationSuitCards = foundationCards[card.suit]!;
    return (foundationSuitCards.isEmpty &&
            card.value == AceSuitedCardValue()) ||
        (foundationSuitCards.isNotEmpty &&
            getCardValue(foundationSuitCards.last) + 1 == getCardValue(card));
  }

  bool isValidSequence(List<SuitedCard> cards) {
    if (cards.isEmpty) return true;

    for (var i = 0; i < cards.length - 1; i++) {
      final currentCard = cards[i];
      final nextCard = cards[i + 1];

      if (currentCard.suit.color == nextCard.suit.color ||
          getCardValue(currentCard) != getCardValue(nextCard) + 1) {
        return false;
      }
    }

    return true;
  }

  bool canMoveToTableau(List<SuitedCard> cards, int targetColumn) {
    if (cards.isEmpty) return false;

    final effectiveMaxMoveSize = getMaxMoveSizeForTarget(targetColumn);

    if (cards.length > effectiveMaxMoveSize) {
      return false;
    }

    if (tableauCards[targetColumn].isEmpty) {
      return true;
    } else {
      final targetTopCard = tableauCards[targetColumn].last;
      final movingBottomCard = cards.first;

      return movingBottomCard.suit.color != targetTopCard.suit.color &&
          getCardValue(movingBottomCard) + 1 == getCardValue(targetTopCard);
    }
  }

  bool canMoveToFreeCell(SuitedCard card, int cellIndex) =>
      freeCells[cellIndex] == null;

  HintSuggestion? findHint() {
    for (int column = 0; column < tableauCards.length; column++) {
      final card = tableauCards[column].lastOrNull;
      if (card != null && canAddToFoundation(card)) {
        return HintSuggestion(
          message:
              'Move ${describeCard(card)} from ${describeColumn(column)} to the ${describeSuitName(card.suit)} foundation.',
          fromTarget: 'tableau-$column',
          toTarget: 'foundation',
          highlightTargets: ['tableau-$column', 'foundation'],
        );
      }
    }

    for (int cell = 0; cell < freeCells.length; cell++) {
      final card = freeCells[cell];
      if (card != null && canAddToFoundation(card)) {
        return HintSuggestion(
          message:
              'Move ${describeCard(card)} from ${describeFreeCell(cell)} to the ${describeSuitName(card.suit)} foundation.',
          fromTarget: 'free-$cell',
          toTarget: 'foundation',
          highlightTargets: ['free-$cell', 'foundation'],
        );
      }
    }

    for (int cell = 0; cell < freeCells.length; cell++) {
      final card = freeCells[cell];
      if (card == null) continue;

      for (int column = 0; column < tableauCards.length; column++) {
        if (canMoveToTableau([card], column)) {
          final targetTop = tableauCards[column].lastOrNull;
          final targetDescription = targetTop == null
              ? 'empty ${describeColumn(column)}'
              : '${describeCard(targetTop)} in ${describeColumn(column)}';
          return HintSuggestion(
            message:
                'Play ${describeCard(card)} from ${describeFreeCell(cell)} onto $targetDescription.',
            fromTarget: 'free-$cell',
            toTarget: 'tableau-$column',
            highlightTargets: ['free-$cell', 'tableau-$column'],
          );
        }
      }
    }

    HintSuggestion? bestMove;
    for (int from = 0; from < tableauCards.length; from++) {
      final columnCards = tableauCards[from];
      for (int start = 0; start < columnCards.length; start++) {
        final moving = columnCards.sublist(start);
        if (!isValidSequence(moving)) {
          continue;
        }

        for (int target = 0; target < tableauCards.length; target++) {
          if (target == from) continue;
          if (!canMoveToTableau(moving, target)) continue;

          final targetTop = tableauCards[target].lastOrNull;
          final targetDescription = targetTop == null
              ? 'empty ${describeColumn(target)}'
              : '${describeCard(targetTop)} in ${describeColumn(target)}';

          final clearsColumn =
              start == 0 && moving.length == columnCards.length;
          final hint = HintSuggestion(
            message:
                'Move ${describeCardSequence(moving)} from ${describeColumn(from)} onto $targetDescription.',
            detail: clearsColumn
                ? 'This opens ${describeColumn(from)} for future plays.'
                : null,
            fromTarget: 'tableau-$from',
            toTarget: 'tableau-$target',
            highlightTargets: ['tableau-$from', 'tableau-$target'],
          );

          if (clearsColumn) {
            return hint;
          }

          bestMove ??= hint;
        }
      }
    }

    if (bestMove != null) {
      return bestMove;
    }

    final emptyCell = freeCells.indexWhere((cell) => cell == null);
    if (emptyCell != -1) {
      final columnIndex =
          tableauCards.indexWhere((column) => column.length > 1);
      if (columnIndex != -1) {
        final card = tableauCards[columnIndex].last;
        return HintSuggestion(
          message:
              'Store ${describeCard(card)} from ${describeColumn(columnIndex)} in ${describeFreeCell(emptyCell)} to free space.',
          fromTarget: 'tableau-$columnIndex',
          toTarget: 'free-$emptyCell',
          highlightTargets: [
            'tableau-$columnIndex',
            'free-$emptyCell',
          ],
        );
      }
    }

    return null;
  }

  FreeCellState withMoveFromTableauToTableau(
      List<SuitedCard> cards, int fromColumn, int toColumn) {
    if (!canMoveToTableau(cards, toColumn)) {
      return this;
    }

    final newTableauCards = [...tableauCards];

    newTableauCards[fromColumn] = newTableauCards[fromColumn]
        .sublist(0, newTableauCards[fromColumn].length - cards.length);

    newTableauCards[toColumn] = [...newTableauCards[toColumn], ...cards];

    return copyWith(
      tableauCards: newTableauCards,
      canAutoMove: true,
    );
  }

  FreeCellState withMoveFromTableauToFreeCell(int fromColumn, int toCellIndex) {
    if (tableauCards[fromColumn].isEmpty || freeCells[toCellIndex] != null) {
      return this;
    }

    final card = tableauCards[fromColumn].last;
    final newTableauCards = [...tableauCards];
    newTableauCards[fromColumn] = [...tableauCards[fromColumn]]..removeLast();

    final newFreeCells = [...freeCells];
    newFreeCells[toCellIndex] = card;

    return copyWith(
      tableauCards: newTableauCards,
      freeCells: newFreeCells,
      canAutoMove: true,
    );
  }

  FreeCellState withMoveFromFreeCellToTableau(int fromCellIndex, int toColumn) {
    final card = freeCells[fromCellIndex];

    if (card == null) {
      return this;
    }

    if (!canMoveToTableau([card], toColumn)) {
      return this;
    }

    final newFreeCells = [...freeCells];
    newFreeCells[fromCellIndex] = null;

    final newTableauCards = [...tableauCards];
    newTableauCards[toColumn] = [...tableauCards[toColumn], card];

    return copyWith(
      tableauCards: newTableauCards,
      freeCells: newFreeCells,
      canAutoMove: true,
    );
  }

  FreeCellState withMoveFromTableauToFoundation(int fromColumn) {
    if (tableauCards[fromColumn].isEmpty) {
      return this;
    }

    final card = tableauCards[fromColumn].last;

    if (!canAddToFoundation(card)) {
      return this;
    }

    final newTableauCards = [...tableauCards];
    newTableauCards[fromColumn] = [...tableauCards[fromColumn]]..removeLast();

    final newFoundationCards = {
      ...foundationCards,
      card.suit: [...foundationCards[card.suit]!, card],
    };

    return copyWith(
      tableauCards: newTableauCards,
      foundationCards: newFoundationCards,
      canAutoMove: true,
    );
  }

  FreeCellState withMoveFromFreeCellToFoundation(int fromCellIndex) {
    final card = freeCells[fromCellIndex];

    if (card == null || !canAddToFoundation(card)) {
      return this;
    }

    final newFreeCells = [...freeCells];
    newFreeCells[fromCellIndex] = null;

    final newFoundationCards = {
      ...foundationCards,
      card.suit: [...foundationCards[card.suit]!, card],
    };

    return copyWith(
      freeCells: newFreeCells,
      foundationCards: newFoundationCards,
      canAutoMove: true,
    );
  }

  FreeCellState withMoveFromFreeCellToFreeCell(
      int fromCellIndex, int toCellIndex) {
    final card = freeCells[fromCellIndex];

    if (card == null || freeCells[toCellIndex] != null) {
      return this;
    }

    final newFreeCells = [...freeCells];
    newFreeCells[fromCellIndex] = null;
    newFreeCells[toCellIndex] = card;

    return copyWith(
      freeCells: newFreeCells,
      canAutoMove: true,
    );
  }

  FreeCellState withMoveFromFoundationToTableau(CardSuit suit, int toColumn) {
    final foundationPile = foundationCards[suit]!;

    if (foundationPile.isEmpty) {
      return this;
    }

    final card = foundationPile.last;

    if (!canMoveToTableau([card], toColumn)) {
      return this;
    }

    final newFoundationCards = {
      ...foundationCards,
      suit: [...foundationPile]..removeLast(),
    };

    final newTableauCards = [...tableauCards];
    newTableauCards[toColumn] = [...tableauCards[toColumn], card];

    return copyWith(
      tableauCards: newTableauCards,
      foundationCards: newFoundationCards,
      canAutoMove: false,
    );
  }

  FreeCellState withMove(
      List<SuitedCard> cards, GroupValue fromValue, GroupValue toValue) {
    if (fromValue is TableauGroupValue && toValue is TableauGroupValue) {
      return withMoveFromTableauToTableau(
          cards, fromValue.columnIndex, toValue.columnIndex);
    }

    if (fromValue is TableauGroupValue && toValue is FreeCellGroupValue) {
      return withMoveFromTableauToFreeCell(
          fromValue.columnIndex, toValue.cellIndex);
    }

    if (fromValue is FreeCellGroupValue && toValue is TableauGroupValue) {
      return withMoveFromFreeCellToTableau(
          fromValue.cellIndex, toValue.columnIndex);
    }

    if (fromValue is FreeCellGroupValue && toValue is FreeCellGroupValue) {
      return withMoveFromFreeCellToFreeCell(
          fromValue.cellIndex, toValue.cellIndex);
    }

    if (fromValue is TableauGroupValue && toValue is FoundationGroupValue) {
      return withMoveFromTableauToFoundation(fromValue.columnIndex);
    }

    if (fromValue is FreeCellGroupValue && toValue is FoundationGroupValue) {
      return withMoveFromFreeCellToFoundation(fromValue.cellIndex);
    }

    if (fromValue is FoundationGroupValue && toValue is TableauGroupValue) {
      return withMoveFromFoundationToTableau(
          fromValue.suit, toValue.columnIndex);
    }

    return this;
  }

  FreeCellState? withAutoMove(
      {TableauGroupValue? tableauGroup,
      FreeCellGroupValue? freeCellGroup,
      FoundationGroupValue? foundationGroup,
      int? cardIndexInTableau}) {
    if (tableauGroup != null) {
      final column = tableauCards[tableauGroup.columnIndex];

      if (column.isEmpty) {
        return null;
      }

      if (cardIndexInTableau != null &&
          cardIndexInTableau < column.length - 1) {
        final subsequence = column.sublist(cardIndexInTableau);
        if (isValidSequence(subsequence) && subsequence.length <= maxMoveSize) {
          List<int> validNonEmptyColumns = [];
          List<int> validEmptyColumns = [];

          for (int i = 0; i < tableauCards.length; i++) {
            if (i != tableauGroup.columnIndex &&
                canMoveToTableau(subsequence, i)) {
              if (tableauCards[i].isEmpty) {
                validEmptyColumns.add(i);
              } else {
                validNonEmptyColumns.add(i);
              }
            }
          }

          if (validNonEmptyColumns.isNotEmpty) {
            return withMoveFromTableauToTableau(subsequence,
                tableauGroup.columnIndex, validNonEmptyColumns.first);
          } else if (validEmptyColumns.isNotEmpty) {
            return withMoveFromTableauToTableau(
                subsequence, tableauGroup.columnIndex, validEmptyColumns.first);
          }
        }
        return null;
      }

      final card = column.last;

      if (canAddToFoundation(card)) {
        return withMoveFromTableauToFoundation(tableauGroup.columnIndex);
      }

      List<int> validNonEmptyColumns = [];
      List<int> validEmptyColumns = [];

      for (int i = 0; i < tableauCards.length; i++) {
        if (i != tableauGroup.columnIndex && canMoveToTableau([card], i)) {
          if (tableauCards[i].isEmpty) {
            validEmptyColumns.add(i);
          } else {
            validNonEmptyColumns.add(i);
          }
        }
      }

      if (validNonEmptyColumns.isNotEmpty) {
        return withMoveFromTableauToTableau(
            [card], tableauGroup.columnIndex, validNonEmptyColumns.first);
      } else if (validEmptyColumns.isNotEmpty) {
        return withMoveFromTableauToTableau(
            [card], tableauGroup.columnIndex, validEmptyColumns.first);
      }

      for (int i = 0; i < freeCells.length; i++) {
        if (freeCells[i] == null) {
          return withMoveFromTableauToFreeCell(tableauGroup.columnIndex, i);
        }
      }
    } else if (freeCellGroup != null) {
      final card = freeCells[freeCellGroup.cellIndex];
      if (card == null) {
        return null;
      }

      if (canAddToFoundation(card)) {
        return withMoveFromFreeCellToFoundation(freeCellGroup.cellIndex);
      }

      List<int> validNonEmptyColumns = [];
      List<int> validEmptyColumns = [];

      for (int i = 0; i < tableauCards.length; i++) {
        if (canMoveToTableau([card], i)) {
          if (tableauCards[i].isEmpty) {
            validEmptyColumns.add(i);
          } else {
            validNonEmptyColumns.add(i);
          }
        }
      }

      if (validNonEmptyColumns.isNotEmpty) {
        return withMoveFromFreeCellToTableau(
            freeCellGroup.cellIndex, validNonEmptyColumns.first);
      } else if (validEmptyColumns.isNotEmpty) {
        return withMoveFromFreeCellToTableau(
            freeCellGroup.cellIndex, validEmptyColumns.first);
      }
    } else if (foundationGroup != null) {
      final foundationPile = foundationCards[foundationGroup.suit]!;
      if (foundationPile.isEmpty) {
        return null;
      }

      final card = foundationPile.last;

      for (int i = 0; i < tableauCards.length; i++) {
        if (canMoveToTableau([card], i)) {
          return withMoveFromFoundationToTableau(foundationGroup.suit, i);
        }
      }
    } else {
      final lowestFoundationValue = foundationCards.values
          .map((cards) => cards.isEmpty ? 0 : getCardValue(cards.last))
          .reduce(min);

      final safeAutoMoveThreshold = lowestFoundationValue + 2;

      bool isSafeToAutoMove(SuitedCard card) {
        return canAddToFoundation(card) &&
            getCardValue(card) <= safeAutoMoveThreshold;
      }

      for (int i = 0; i < tableauCards.length; i++) {
        if (tableauCards[i].isNotEmpty) {
          final card = tableauCards[i].last;
          if (isSafeToAutoMove(card)) {
            return withMoveFromTableauToFoundation(i);
          }
        }
      }

      for (int i = 0; i < freeCells.length; i++) {
        final card = freeCells[i];
        if (card != null && isSafeToAutoMove(card)) {
          return withMoveFromFreeCellToFoundation(i);
        }
      }
    }

    return null;
  }

  FreeCellState withUndo() {
    return history.last.copyWith(
        canAutoMove: false, saveNewStateToHistory: false, usedUndo: true);
  }

  bool get isVictory =>
      foundationCards.values.every((cards) => cards.length == 13);

  bool get hasAvailableMoves => findHint() != null;

  FreeCellState copyWith({
    List<List<SuitedCard>>? tableauCards,
    List<SuitedCard?>? freeCells,
    Map<CardSuit, List<SuitedCard>>? foundationCards,
    bool? usedUndo,
    bool? canAutoMove,
    bool saveNewStateToHistory = true,
  }) {
    final nextHistory = saveNewStateToHistory
        ? history.pushCapped(this, maxLength: kDefaultHistoryLimit)
        : history;

    return FreeCellState(
      tableauCards: tableauCards ?? this.tableauCards,
      freeCells: freeCells ?? this.freeCells,
      foundationCards: foundationCards ?? this.foundationCards,
      usedUndo: usedUndo ?? this.usedUndo,
      canAutoMove: canAutoMove ?? this.canAutoMove,
      history: nextHistory,
    );
  }
}

class FreeCell extends HookConsumerWidget {
  final Difficulty difficulty;
  final bool startWithTutorial;
  final DailyChallengeConfig? dailyChallenge;
  final ActiveGameSnapshot? snapshot;

  const FreeCell(
      {super.key,
      required this.difficulty,
      this.startWithTutorial = false,
      this.dailyChallenge,
      this.snapshot});

  FreeCellState get defaultInitialState => FreeCellState.getInitialState(
        freeCellCount: switch (difficulty) {
          Difficulty.classic => 4,
          Difficulty.royal || Difficulty.ace => 3,
        },
        acesAtBottom: difficulty == Difficulty.ace,
        shuffleSeed: dailyChallenge?.shuffleSeed,
      );

  FreeCellState get initialState {
    if (dailyChallenge != null) return defaultInitialState;
    if (snapshot != null) {
      try {
        return FreeCellState.fromJson(snapshot!.state);
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
        game: Game.freeCell,
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
        saveStateNotifier.clearActiveGame(Game.freeCell);

    useOnListenableChange(
      state,
      () => ref
          .read(achievementServiceProvider)
          .checkFreeCellMoveAchievements(state: state.value),
    );

    final tableauKey = useMemoized(() => GlobalKey());
    final foundationKey = useMemoized(() => GlobalKey());
    final freeCellsKey = useMemoized(() => GlobalKey());
    final tableauColumnKeys =
        useMemoized(() => List.generate(8, (_) => GlobalKey()));
    final freeCellKeys =
        useMemoized(() => List.generate(state.value.freeCells.length, (_) => GlobalKey()));

    void startTutorial() {
      showGameTutorial(
        context,
        screens: [
          TutorialScreen.key(
            key: tableauKey,
            message:
                'Welcome to FreeCell! All cards start face-up in the tableau. Build down in alternating colors (red on black, black on red) in descending order.',
          ),
          TutorialScreen.key(
            key: freeCellsKey,
            message:
                'These are temporary storage spaces. Each can hold one card at a time, giving you flexibility to move cards around the tableau.',
          ),
          TutorialScreen.key(
            key: foundationKey,
            message:
                'Build four foundation piles, one for each suit, from Ace to King. Move Aces here first, then build up in suit order.',
          ),
          TutorialScreen.everything(
            message:
                'Win by moving all cards to the foundations. While you technically move one card at a time, the game lets you move groups of properly sequenced cards if you have enough empty free cells and tableau spaces to make the individual moves. Empty tableau spaces can be filled with any card. Strategic use of free cells is key to winning. Tap to begin playing!',
          ),
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
      game: Game.freeCell,
      difficulty: difficulty,
      dailyChallenge: dailyChallenge,
      initialElapsed:
          Duration(milliseconds: snapshot?.elapsedMilliseconds ?? 0),
      hintTargetKeys: {
        'foundation': foundationKey,
        for (var i = 0; i < tableauColumnKeys.length; i++)
          'tableau-$i': tableauColumnKeys[i],
        for (var i = 0; i < freeCellKeys.length; i++)
          'free-$i': freeCellKeys[i],
      },
      onNewGame: () {
        if (dailyChallenge == null) {
          unawaited(clearSnapshot());
        }
        startReference.value = DateTime.now();
        state.value = defaultInitialState;
      },
      onRestart: () {
        startReference.value = DateTime.now();
        state.value =
            (state.value.history.firstOrNull ?? state.value)
                .copyWith(canAutoMove: true);
      },
      onTutorial: startTutorial,
      onUndo: state.value.history.isEmpty
          ? null
          : () => state.value = state.value.withUndo(),
      onHint: () => state.value.findHint(),
      isVictory: state.value.isVictory,
      hasMoves: state.value.hasAvailableMoves,
      onVictory: (_, __) async {
        await ref
            .read(achievementServiceProvider)
            .checkFreeCellCompletionAchievements(
                difficulty: difficulty, state: state.value);
        if (dailyChallenge == null) {
          await clearSnapshot();
        }
      },
      builder: (context, constraints, cardBack, autoMoveEnabled, gameKey) {
        final axis = constraints.largestAxis;
        final minSize = constraints.smallest.longestSide;
        final spacing = minSize / 100;

        final sizeMultiplier = constraints.findCardSizeMultiplier(
          maxRows: axis == Axis.horizontal ? 4 : 8,
          maxCols: axis == Axis.horizontal ? 8 : 2,
          spacing: spacing,
        );

        final cardOffset = sizeMultiplier * 25;

        return DelayedAutoMoveListener(
          enabled: autoMoveEnabled,
          stateGetter: () => state.value,
          nextStateGetter: (state) =>
              state.canAutoMove ? state.withAutoMove() : null,
          gameKey: gameKey,
          onNewState: (newState) {
            ref.read(audioServiceProvider).playPlace();
            state.value = newState;
          },
          child: CardGame<SuitedCard, GroupValue>(
            gameKey: gameKey,
            style: playingCardStyle(
              sizeMultiplier: sizeMultiplier,
              cardBack: cardBack,
              emptyGroupOverlayBuilder: (group) => group is FoundationGroupValue
                  ? VectorGraphic(
                      loader:
                          PlayingCardAssetBundleCache.getSuitLoader(group.suit),
                      colorFilter:
                          ColorFilter.mode(Colors.white30, BlendMode.srcIn),
                    )
                  : null,
            ),
            children: [
              Flex(
                direction: axis.inverted,
                children: [
                  Flex(
                    direction: axis,
                    children: [
                      Expanded(
                        child: Flex(
                          key: freeCellsKey,
                          direction: axis,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ...state.value.freeCells.mapIndexed((i, card) =>
                                CardDeck<SuitedCard, GroupValue>(
                                  key: freeCellKeys[i],
                                  value: FreeCellGroupValue(i),
                                  values: card == null ? [] : [card],
                                  canGrab: true,
                                  canMoveCardHere: (move) =>
                                      move.cardValues.length == 1 &&
                                      card == null,
                                  onCardMovedHere: (move) {
                                    ref.read(audioServiceProvider).playPlace();
                                    state.value = state.value.withMove(
                                        move.cardValues,
                                        move.fromGroupValue,
                                        FreeCellGroupValue(i));
                                  },
                                  onCardPressed: (card) {
                                    final newState = state.value.withAutoMove(
                                        freeCellGroup: FreeCellGroupValue(i));
                                    if (newState != null) {
                                      ref
                                          .read(audioServiceProvider)
                                          .playPlace();
                                      state.value = newState;
                                    }
                                  },
                                )),
                            ...List.filled(
                              4 - state.value.freeCells.length,
                              SizedBox.fromSize(
                                  size: Size(69, 93) * sizeMultiplier),
                            ),
                          ],
                        ),
                      ),
                      SizedBox.square(dimension: spacing),
                      Expanded(
                        child: Flex(
                          key: foundationKey,
                          direction: axis,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: state.value.foundationCards.entries
                              .map<Widget>(
                                  (entry) => CardDeck<SuitedCard, GroupValue>(
                                        value: FoundationGroupValue(entry.key),
                                        values: entry.value,
                                        canGrab: true,
                                        canMoveCardHere: (move) =>
                                            move.cardValues.length == 1 &&
                                            canAddToFoundation(
                                                move.cardValues.first,
                                                entry.key,
                                                entry.value),
                                        onCardMovedHere: (move) {
                                          ref
                                              .read(audioServiceProvider)
                                              .playPlace();
                                          state.value = state.value.withMove(
                                              move.cardValues,
                                              move.fromGroupValue,
                                              FoundationGroupValue(entry.key));
                                        },
                                        onCardPressed: (card) {
                                          final newState =
                                              state.value.withAutoMove(
                                            foundationGroup:
                                                FoundationGroupValue(entry.key),
                                          );
                                          if (newState != null) {
                                            ref
                                                .read(audioServiceProvider)
                                                .playPlace();
                                            state.value = newState;
                                          }
                                        },
                                      ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox.square(dimension: spacing),
                  Expanded(
                    child: Flex(
                      key: tableauKey,
                      direction: axis,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List<Widget>.generate(
                        8,
                        (i) {
                          final columnCards = state.value.tableauCards[i];

                          return CardLinearGroup<SuitedCard, GroupValue>(
                            key: tableauColumnKeys[i],
                            value: TableauGroupValue(i),
                            cardOffset: axis.inverted.offset * cardOffset,
                            maxGrabStackSize: state.value.maxMoveSize,
                            values: columnCards,
                            canCardBeGrabbed: (index, card) {
                              final subsequence = columnCards.sublist(index);
                              return state.value.isValidSequence(subsequence);
                            },
                            canMoveCardHere: (move) => state.value
                                .canMoveToTableau(move.cardValues, i),
                            onCardMovedHere: (move) {
                              ref.read(audioServiceProvider).playPlace();
                              state.value = state.value.withMove(
                                  move.cardValues,
                                  move.fromGroupValue,
                                  TableauGroupValue(i));
                            },
                            onCardPressed: (card) {
                              final cardIndex = columnCards.indexOf(card);

                              final newState = state.value.withAutoMove(
                                  tableauGroup: TableauGroupValue(i),
                                  cardIndexInTableau: cardIndex);

                              if (newState != null) {
                                ref.read(audioServiceProvider).playPlace();
                                state.value = newState;
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static bool canAddToFoundation(
      SuitedCard card, CardSuit suit, List<SuitedCard> foundationPile) {
    if (card.suit != suit) return false;

    final cardValue = SuitedCardValueMapper.aceAsLowest.getValue(card);

    return foundationPile.isEmpty && card.value == AceSuitedCardValue() ||
        (foundationPile.isNotEmpty &&
            SuitedCardValueMapper.aceAsLowest.getValue(foundationPile.last) +
                    1 ==
                cardValue);
  }
}
