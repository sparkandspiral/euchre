import 'dart:math';

import 'package:card_game/card_game.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/immutable_history.dart';
import 'package:solitaire/model/hint.dart';
import 'package:solitaire/services/achievement_service.dart';
import 'package:solitaire/services/audio_service.dart';
import 'package:solitaire/styles/playing_card_builder.dart';
import 'package:solitaire/utils/constraints_extensions.dart';
import 'package:solitaire/utils/card_description.dart';
import 'package:solitaire/widgets/card_scaffold.dart';
import 'package:solitaire/widgets/game_tutorial.dart';
import 'package:utils/utils.dart';

class PyramidCardPos {
  final int row;
  final int col;
  const PyramidCardPos(this.row, this.col);
}

class PyramidCard extends Equatable {
  final SuitedCard card;
  final int uniqueId;

  const PyramidCard(this.card, this.uniqueId);

  @override
  List<Object?> get props => [card, uniqueId];
}

class PyramidSolitaireState {
  // 7 rows; row i has i+1 cards. Null entries represent removed cards.
  final List<List<PyramidCard?>> pyramid;

  final List<PyramidCard> stock; // draw pile
  final List<PyramidCard> waste; // exposed from stock (top playable)

  final ImmutableHistory<PyramidSolitaireState> history;
  final bool usedUndo;
  final PyramidCardPos? selected;

  PyramidSolitaireState({
    required this.pyramid,
    required this.stock,
    required this.waste,
    required this.history,
    required this.usedUndo,
    required this.selected,
  });

  static PyramidSolitaireState getInitialState({
    required int drawPerTap,
    required bool buryAces,
    required bool startWithWasteCard,
  }) {
    var suitedDeck = SuitedCard.deck.shuffled();

    // Optionally bury Aces at bottom of stock to increase difficulty similar to Ace mode patterns
    if (buryAces) {
      final aces =
          suitedDeck.where((c) => c.value == AceSuitedCardValue()).toList();
      suitedDeck =
          suitedDeck.where((c) => c.value != AceSuitedCardValue()).toList() +
              aces;
    }

    // Wrap in unique PyramidCard instances
    var deck = <PyramidCard>[];
    var uid = 0;
    for (final c in suitedDeck) {
      deck.add(PyramidCard(c, uid++));
    }

    // Build pyramid structure
    final pyramid = <List<PyramidCard?>>[];
    for (var r = 0; r < 7; r++) {
      final row =
          deck.take(r + 1).toList().map<PyramidCard?>((c) => c).toList();
      deck = deck.skip(r + 1).toList();
      pyramid.add(row);
    }

    // Remaining deck -> stock; waste initially empty
    // Optionally start with a waste card
    var waste = <PyramidCard>[];
    if (startWithWasteCard && deck.isNotEmpty) {
      waste.add(deck.first);
      deck = deck.skip(1).toList();
    }

    return PyramidSolitaireState(
      pyramid: pyramid,
      stock: deck,
      waste: waste,
      history: const ImmutableHistory.empty(),
      usedUndo: false,
      selected: null,
    );
  }

  static bool _hasCard(List<List<PyramidCard?>> pyramid, int row, int col) {
    if (row < 0 || row >= pyramid.length) return false;
    if (col < 0 || col >= pyramid[row].length) return false;
    return true;
  }

  int _value(PyramidCard card) =>
      SuitedCardValueMapper.aceAsLowest.getValue(card.card);

  bool isExposed(int row, int col) {
    if (!_hasCard(pyramid, row, col)) return false;
    final card = pyramid[row][col];
    if (card == null) return false;
    if (row == pyramid.length - 1) return true;
    final leftCovered =
        _hasCard(pyramid, row + 1, col) && pyramid[row + 1][col] != null;
    final rightCovered = _hasCard(pyramid, row + 1, col + 1) &&
        pyramid[row + 1][col + 1] != null;
    return !(leftCovered || rightCovered);
  }

  List<PyramidCardPos> getExposedPositions() {
    final positions = <PyramidCardPos>[];
    for (var r = 0; r < pyramid.length; r++) {
      for (var c = 0; c < pyramid[r].length; c++) {
        if (isExposed(r, c)) positions.add(PyramidCardPos(r, c));
      }
    }
    return positions;
  }

  bool canRemovePair(PyramidCard a, PyramidCard b) =>
      _value(a) + _value(b) == 13;
  bool canRemoveKing(PyramidCard a) => _value(a) == 13;

  PyramidSolitaireState withRemoveAt(int row, int col) {
    if (!isExposed(row, col)) return this;
    final card = pyramid[row][col];
    if (card == null) return this;
    if (!canRemoveKing(card)) return this;

    final newPyramid = pyramid.map((list) => [...list]).toList();
    newPyramid[row][col] = null;

    return copyWith(pyramid: newPyramid, clearSelected: true);
  }

  PyramidSolitaireState withRemovePairFromPyramid(
      PyramidCardPos a, PyramidCardPos b) {
    if (!isExposed(a.row, a.col) || !isExposed(b.row, b.col)) return this;
    final cardA = pyramid[a.row][a.col];
    final cardB = pyramid[b.row][b.col];
    if (cardA == null || cardB == null) return this;
    if (!canRemovePair(cardA, cardB)) return this;

    final newPyramid = pyramid.map((list) => [...list]).toList();
    newPyramid[a.row][a.col] = null;
    newPyramid[b.row][b.col] = null;

    return copyWith(pyramid: newPyramid, clearSelected: true);
  }

  PyramidSolitaireState withRemoveWithWaste(PyramidCardPos pos) {
    if (!isExposed(pos.row, pos.col) || waste.isEmpty) return this;
    final cardA = pyramid[pos.row][pos.col];
    final cardB = waste.last;
    if (cardA == null) return this;
    if (!canRemovePair(cardA, cardB)) return this;

    final newWaste = [...waste]..removeLast();
    final newPyramid = pyramid.map((list) => [...list]).toList();
    newPyramid[pos.row][pos.col] = null;

    return copyWith(
      pyramid: newPyramid,
      waste: newWaste,
      clearSelected: true,
    );
  }

  bool get canDraw => stock.isNotEmpty;

  PyramidSolitaireState withDraw() {
    if (stock.isEmpty) return this;
    return copyWith(
        stock: stock.sublist(0, stock.length - 1), waste: waste + [stock.last]);
  }

  HintSuggestion? findHint() {
    final exposedPositions = <PyramidCardPos>[];
    for (var row = 0; row < pyramid.length; row++) {
      for (var col = 0; col < pyramid[row].length; col++) {
        if (isExposed(row, col)) {
          exposedPositions.add(PyramidCardPos(row, col));
        }
      }
    }

    for (final pos in exposedPositions) {
      final card = pyramid[pos.row][pos.col];
      if (card == null) continue;
      if (canRemoveKing(card)) {
        return HintSuggestion(
          message:
              'Remove the king ${describeCard(card.card)} at ${describeRowPosition(pos.row, pos.col)}.',
        );
      }
    }

    for (var i = 0; i < exposedPositions.length; i++) {
      for (var j = i + 1; j < exposedPositions.length; j++) {
        final aPos = exposedPositions[i];
        final bPos = exposedPositions[j];
        final cardA = pyramid[aPos.row][aPos.col];
        final cardB = pyramid[bPos.row][bPos.col];
        if (cardA == null || cardB == null) continue;
        if (canRemovePair(cardA, cardB)) {
          return HintSuggestion(
            message:
                'Pair ${describeCard(cardA.card)} at ${describeRowPosition(aPos.row, aPos.col)} with ${describeCard(cardB.card)} at ${describeRowPosition(bPos.row, bPos.col)}.',
          );
        }
      }
    }

    final wasteCard = waste.lastOrNull;
    if (wasteCard != null) {
      for (final pos in exposedPositions) {
        final pyramidCard = pyramid[pos.row][pos.col];
        if (pyramidCard == null) continue;
        if (canRemovePair(pyramidCard, wasteCard)) {
          return HintSuggestion(
            message:
                'Match ${describeCard(pyramidCard.card)} at ${describeRowPosition(pos.row, pos.col)} with the waste card ${describeCard(wasteCard.card)}.',
          );
        }
      }
    }

    if (canDraw) {
      return const HintSuggestion(
        message: 'Draw a new waste card from the stock.',
      );
    }

    return null;
  }

  PyramidSolitaireState withUndo() =>
      history.last.copyWith(saveNewStateToHistory: false, usedUndo: true);

  bool get isVictory => pyramid.every((row) => row.isEmpty);

  PyramidSolitaireState copyWith({
    List<List<PyramidCard?>>? pyramid,
    List<PyramidCard>? stock,
    List<PyramidCard>? waste,
    bool? usedUndo,
    PyramidCardPos? selected,
    bool clearSelected = false,
    bool saveNewStateToHistory = true,
  }) {
    final nextHistory = saveNewStateToHistory
        ? history.pushCapped(this, maxLength: kDefaultHistoryLimit)
        : history;

    return PyramidSolitaireState(
      pyramid: pyramid ?? this.pyramid,
      stock: stock ?? this.stock,
      waste: waste ?? this.waste,
      usedUndo: usedUndo ?? this.usedUndo,
      selected: clearSelected ? null : (selected ?? this.selected),
      history: nextHistory,
    );
  }
}

class PyramidSolitaire extends HookConsumerWidget {
  final Difficulty difficulty;
  final bool startWithTutorial;

  const PyramidSolitaire(
      {super.key, required this.difficulty, this.startWithTutorial = false});

  int get drawPerTap => 1; // standard pyramid draws 1 to waste

  PyramidSolitaireState get initialState =>
      PyramidSolitaireState.getInitialState(
        drawPerTap: drawPerTap,
        buryAces: difficulty == Difficulty.ace,
        startWithWasteCard: difficulty.index >= Difficulty.royal.index,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = useState(initialState);
    useOnListenableChange(
      state,
      () => ref
          .read(achievementServiceProvider)
          .checkPyramidSolitaireMoveAchievements(
              state: state.value, difficulty: difficulty),
    );

    final pyramidKey = useMemoized(() => GlobalKey());
    final stockKey = useMemoized(() => GlobalKey());
    final wasteKey = useMemoized(() => GlobalKey());
    final pairingGuideKey = useMemoized(() => GlobalKey());

    void startTutorial() {
      showGameTutorial(
        context,
        screens: [
          TutorialScreen.key(
            key: pyramidKey,
            message:
                'Welcome to Pyramid! Remove cards that sum to 13. Kings stand alone. Only exposed cards (with both covering cards removed) can be tapped.',
          ),
          TutorialScreen.key(
            key: wasteKey,
            message:
                'You can pair an exposed pyramid card with the top waste card if they sum to 13. Tap to try pairing!',
          ),
          TutorialScreen.key(
            key: pairingGuideKey,
            message:
                'Need help remembering the pairs? Use this quick guide to match A+Q, 2+J, 3+10, 4+9, 5+8, and 6+7. Kings remove themselves.',
          ),
          TutorialScreen.key(
            key: stockKey,
            message:
                'Tap the stock to draw a new waste card when you need options.',
          ),
          TutorialScreen.everything(
            message: 'Clear the entire pyramid to win. Tap to begin playing!',
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

    return CardScaffold(
      game: Game.pyramid,
      difficulty: difficulty,
      onNewGame: () => state.value = initialState,
      onRestart: () => state.value =
          (state.value.history.firstOrNull ?? state.value)
              .copyWith(usedUndo: false),
      onTutorial: startTutorial,
      onUndo: state.value.history.isEmpty
          ? null
          : () => state.value = state.value.withUndo(),
      onHint: () => state.value.findHint(),
      isVictory: state.value.isVictory,
      onVictory: () => ref
          .read(achievementServiceProvider)
          .checkPyramidSolitaireCompletionAchievements(state: state.value),
      builder: (context, constraints, cardBack, autoMoveEnabled, gameKey) {
        final axis = constraints.largestAxis;
        final minSize = constraints.smallest.longestSide;
        final spacing = minSize / 100;

        const totalRows = 7;
        final baseRowCards = state.value.pyramid.isNotEmpty
            ? state.value.pyramid.last.length
            : 7;
        const rowStepFactor = 0.58;

        double horizontalGap;
        double outerMargin;
        double sizeMultiplier;

        if (axis == Axis.vertical) {
          horizontalGap = 1.0;
          outerMargin = spacing * 0.25;
          final effectiveHeightUnits =
              1 + rowStepFactor * (totalRows - 1); // in card heights
          final verticalAvailable =
              max(0.0, constraints.maxHeight - spacing * 8);
          final verticalMultiplier =
              verticalAvailable / (93 * effectiveHeightUnits);

          final availableWidth = max(
            0.0,
            constraints.maxWidth -
                outerMargin * 2 -
                horizontalGap * (baseRowCards - 1),
          );
          final horizontalMultiplier = availableWidth / (69 * baseRowCards);

          sizeMultiplier = min(horizontalMultiplier, verticalMultiplier);
        } else {
          horizontalGap = spacing;
          outerMargin = spacing;
          sizeMultiplier = constraints.findCardSizeMultiplier(
            maxRows: 4.5,
            maxCols: 9.5,
            spacing: spacing,
          );
        }

        final cardWidth = 69 * sizeMultiplier;
        final cardHeight = 93 * sizeMultiplier;
        final cardSpacingX = cardWidth + horizontalGap;
        final rowStep = cardHeight * rowStepFactor;

        void handleCardTap(int row, int col) {
          final card = state.value.pyramid[row][col];
          if (card == null || !state.value.isExposed(row, col)) return;

          void selectCard() {
            state.value =
                state.value.copyWith(selected: PyramidCardPos(row, col));
          }

          if (state.value.canRemoveKing(card)) {
            ref.read(audioServiceProvider).playPlace();
            state.value = state.value.withRemoveAt(row, col);
            return;
          }

          final wasteCard = state.value.waste.lastOrNull;
          if (wasteCard != null && state.value.canRemovePair(card, wasteCard)) {
            ref.read(audioServiceProvider).playPlace();
            state.value =
                state.value.withRemoveWithWaste(PyramidCardPos(row, col));
            return;
          }

          final selected = state.value.selected;
          if (selected == null) {
            selectCard();
            return;
          }

          if (selected.row == row && selected.col == col) {
            state.value = state.value.copyWith(clearSelected: true);
            return;
          }

          final other = state.value.pyramid[selected.row][selected.col];
          if (other != null && state.value.canRemovePair(card, other)) {
            ref.read(audioServiceProvider).playPlace();
            state.value = state.value.withRemovePairFromPyramid(
              PyramidCardPos(row, col),
              PyramidCardPos(selected.row, selected.col),
            );
            return;
          }

          selectCard();
        }

        Widget buildCard(int row, int col) {
          final card = state.value.pyramid[row][col];
          final cards =
              card == null ? const <PyramidCard>[] : <PyramidCard>[card];
          return SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: CardLinearGroup<PyramidCard, String>(
              value: 'pyr-$row-$col',
              values: cards,
              maxGrabStackSize: 0,
              cardOffset: Offset.zero,
              canCardBeGrabbed: (_, __) => false,
              isCardFlipped: (_, __) => false,
              onCardPressed:
                  cards.isEmpty ? null : (_) => handleCardTap(row, col),
            ),
          );
        }

        PyramidCardPos? parsePyramidGroupId(String groupValue) {
          if (!groupValue.startsWith('pyr-')) {
            return null;
          }
          final parts = groupValue.split('-');
          if (parts.length != 3) {
            return null;
          }
          final row = int.tryParse(parts[1]);
          final col = int.tryParse(parts[2]);
          if (row == null || col == null) {
            return null;
          }
          return PyramidCardPos(row, col);
        }

        Widget buildPyramidStack() {
          final baseRowWidth =
              cardWidth * baseRowCards + horizontalGap * (baseRowCards - 1);
          final tableauWidth = baseRowWidth + outerMargin * 2;
          final tableauHeight = cardHeight + rowStep * (totalRows - 1);

          final positionedCards = <Widget>[];
          for (var row = 0; row < totalRows; row++) {
            final rowLength = state.value.pyramid[row].length;
            final startOffset = outerMargin +
                (baseRowWidth -
                        (cardWidth * rowLength +
                            horizontalGap * (rowLength - 1))) /
                    2;
            for (var col = 0; col < rowLength; col++) {
              final left = startOffset + col * cardSpacingX;
              final top = row * rowStep;
              positionedCards.add(
                Positioned(
                  left: left,
                  top: top,
                  child: buildCard(row, col),
                ),
              );
            }
          }

          return SizedBox(
            key: pyramidKey,
            width: tableauWidth,
            height: tableauHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: positionedCards,
              fit: StackFit.passthrough,
            ),
          );
        }

        final stockDeck = CardDeck<PyramidCard, String>.flipped(
          key: stockKey,
          value: 'stock',
          values: state.value.stock,
          onCardPressed: (_) {
            if (!state.value.canDraw) return;
            ref.read(audioServiceProvider).playDraw();
            state.value = state.value.withDraw();
          },
        );

        final wasteDeck = CardDeck<PyramidCard, String>(
          key: wasteKey,
          value: 'waste',
          values: state.value.waste,
          onCardPressed: (pressed) {
            if (state.value.waste.isEmpty ||
                pressed != state.value.waste.last) {
              return;
            }
            final topCard = state.value.waste.last;
            if (state.value.canRemoveKing(topCard)) {
              ref.read(audioServiceProvider).playPlace();
              state.value = state.value.copyWith(
                waste: state.value.waste.sublist(
                  0,
                  state.value.waste.length - 1,
                ),
                clearSelected: true,
              );
              return;
            }

            final selected = state.value.selected;
            if (selected != null) {
              final other = state.value.pyramid[selected.row][selected.col];
              if (other != null && state.value.canRemovePair(topCard, other)) {
                ref.read(audioServiceProvider).playPlace();
                state.value = state.value.withRemoveWithWaste(selected);
              }
            }
          },
        );

        Widget buildPairingGuide() {
          const combos = [
            'K alone',
            'A + Q',
            '2 + J',
            '3 + 10',
            '4 + 9',
            '5 + 8',
            '6 + 7',
          ];

          return Container(
            key: pairingGuideKey,
            padding: EdgeInsets.symmetric(
              horizontal: spacing * 2,
              vertical: spacing * 1.2,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Pairs that make 13',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16 * sizeMultiplier.clamp(0.8, 1.4),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: spacing),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: spacing,
                  runSpacing: spacing * 0.6,
                  children: combos
                      .map(
                        (combo) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing * 1.2,
                            vertical: spacing * 0.6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            combo,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14 * sizeMultiplier.clamp(0.9, 1.3),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        }

        Widget buildDeckArea() {
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
            spacing: spacing * 1.5,
            children: [
              deckDisplay,
              buildPairingGuide(),
            ],
          );
        }

        final deckGap = spacing + cardHeight * 0.1;

        return CardGame<PyramidCard, String>(
          gameKey: gameKey,
          style: CardGameStyle<PyramidCard, String>(
            cardSize: Size(69, 93) * sizeMultiplier,
            emptyGroupBuilder: (group, state) => const SizedBox.shrink(),
            cardBuilder: (value, group, flipped, cardState) {
              final position = parsePyramidGroupId(group);
              final selectedPos = state.value.selected;
              final isSelected = position != null &&
                  selectedPos?.row == position.row &&
                  selectedPos?.col == position.col;
              final isPlayable = position != null &&
                  state.value.isExposed(position.row, position.col);
              final showDepthShadow = position != null && !isPlayable;
              final accentColor = Theme.of(context).colorScheme.secondary;
              final shadows = <BoxShadow>[
                if (isSelected)
                  BoxShadow(
                    color: accentColor.withOpacity(0.45),
                    blurRadius: 18,
                    spreadRadius: 1.2,
                  ),
                if (showDepthShadow)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
              ];

              return AnimatedContainer(
                duration: Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: accentColor,
                          width: 2.2,
                        )
                      : null,
                  boxShadow: shadows.isEmpty ? null : shadows,
                ),
                child: AnimatedFlippable(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  isFlipped: flipped,
                  front: PlayingCardBuilder(card: value.card),
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
              );
            },
          ),
          children: [
            if (axis == Axis.horizontal)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: buildPyramidStack(),
                    ),
                  ),
                  SizedBox(width: spacing * 2),
                  buildDeckArea(),
                ],
              )
            else
              Column(
                children: [
                  Expanded(
                    child: Center(child: buildPyramidStack()),
                  ),
                  SizedBox(height: deckGap),
                  buildDeckArea(),
                ],
              ),
          ],
        );
      },
    );
  }
}
