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
  // 7 rows; row i has i+1 cards. Hidden shows covered cards beneath.
  final List<List<PyramidCard>> pyramid;
  final List<List<bool>>
      hidden; // true means face-down (covered), false means revealed

  final List<PyramidCard> stock; // draw pile
  final List<PyramidCard> waste; // exposed from stock (top playable)

  final ImmutableHistory<PyramidSolitaireState> history;
  final bool usedUndo;
  final PyramidCardPos? selected;

  PyramidSolitaireState({
    required this.pyramid,
    required this.hidden,
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
    final pyramid = <List<PyramidCard>>[];
    final hidden = <List<bool>>[];
    for (var r = 0; r < 7; r++) {
      final row = deck.take(r + 1).toList();
      deck = deck.skip(r + 1).toList();
      pyramid.add(row);
      // All cards start face-up in pyramid solitaire
      hidden.add(List<bool>.filled(r + 1, false));
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
      hidden: hidden,
      stock: deck,
      waste: waste,
      history: const ImmutableHistory.empty(),
      usedUndo: false,
      selected: null,
    );
  }

  static bool _hasCard(List<List<PyramidCard>> pyramid, int row, int col) {
    if (row < 0 || row >= pyramid.length) return false;
    if (col < 0 || col >= pyramid[row].length) return false;
    return true;
  }

  int _value(PyramidCard card) =>
      SuitedCardValueMapper.aceAsLowest.getValue(card.card);

  bool isExposed(int row, int col) {
    if (!_hasCard(pyramid, row, col)) return false;
    return hidden[row][col] == false;
  }

  List<PyramidCardPos> getExposedPositions() {
    final positions = <PyramidCardPos>[];
    for (var r = 0; r < pyramid.length; r++) {
      for (var c = 0; c < pyramid[r].length; c++) {
        if (!hidden[r][c]) positions.add(PyramidCardPos(r, c));
      }
    }
    return positions;
  }

  bool canRemovePair(PyramidCard a, PyramidCard b) =>
      _value(a) + _value(b) == 13;
  bool canRemoveKing(PyramidCard a) => _value(a) == 13;

  PyramidSolitaireState _revealIfUncovered(
      PyramidSolitaireState state, int row, int col) {
    // After removing a card at row+1, col or col+1, the covering card at row,col may become exposed
    if (!_hasCard(state.pyramid, row, col)) return state;
    if (!state.hidden[row][col]) return state;

    final covered = _hasCard(state.pyramid, row + 1, col) &&
        _hasCard(state.pyramid, row + 1, col + 1);
    if (!covered) {
      final newHiddenRow = [...state.hidden[row]];
      newHiddenRow[col] = false;
      final newHidden = [...state.hidden];
      newHidden[row] = newHiddenRow;
      return state.copyWith(hidden: newHidden);
    }
    return state;
  }

  PyramidSolitaireState withRemoveAt(int row, int col) {
    if (!isExposed(row, col)) return this;
    final card = pyramid[row][col];
    if (!canRemoveKing(card)) return this;

    final newPyramid = pyramid
        .mapIndexed((r, list) => r == row
            ? (list.sublist(0, col) + list.sublist(col + 1))
            : [...list])
        .toList();
    final newHidden = hidden
        .mapIndexed((r, list) => r == row
            ? (list.sublist(0, col) + list.sublist(col + 1))
            : [...list])
        .toList();

    var newState = copyWith(pyramid: newPyramid, hidden: newHidden);
    // Reveal parent cards
    if (row > 0) {
      newState = _revealIfUncovered(newState, row - 1, col);
      newState = _revealIfUncovered(newState, row - 1, col - 1);
    }
    return newState.copyWith(selected: null);
  }

  PyramidSolitaireState withRemovePairFromPyramid(
      PyramidCardPos a, PyramidCardPos b) {
    if (!isExposed(a.row, a.col) || !isExposed(b.row, b.col)) return this;
    final cardA = pyramid[a.row][a.col];
    final cardB = pyramid[b.row][b.col];
    if (!canRemovePair(cardA, cardB)) return this;

    final remove = (List<PyramidCard> list, int i) =>
        list.sublist(0, i) + list.sublist(i + 1);
    final removeBool =
        (List<bool> list, int i) => list.sublist(0, i) + list.sublist(i + 1);

    var newPyramid = [...pyramid];
    var newHidden = [...hidden];

    // Remove higher index first to avoid reindexing issues if same row
    final pairs = [a, b]..sort((x, y) =>
        x.row == y.row ? y.col.compareTo(x.col) : y.row.compareTo(x.row));
    for (final p in pairs) {
      newPyramid[p.row] = remove(newPyramid[p.row], p.col);
      newHidden[p.row] = removeBool(newHidden[p.row], p.col);
    }

    var newState = copyWith(pyramid: newPyramid, hidden: newHidden);
    // Reveal parents
    for (final p in [a, b]) {
      if (p.row > 0) {
        newState = _revealIfUncovered(newState, p.row - 1, p.col);
        newState = _revealIfUncovered(newState, p.row - 1, p.col - 1);
      }
    }
    return newState.copyWith(selected: null);
  }

  PyramidSolitaireState withRemoveWithWaste(PyramidCardPos pos) {
    if (!isExposed(pos.row, pos.col) || waste.isEmpty) return this;
    final cardA = pyramid[pos.row][pos.col];
    final cardB = waste.last;
    if (!canRemovePair(cardA, cardB)) return this;

    final newWaste = [...waste]..removeLast();
    final newPyramidRow = pyramid[pos.row].sublist(0, pos.col) +
        pyramid[pos.row].sublist(pos.col + 1);
    final newHiddenRow = hidden[pos.row].sublist(0, pos.col) +
        hidden[pos.row].sublist(pos.col + 1);

    var newState = copyWith(
      pyramid: [...pyramid]..[pos.row] = newPyramidRow,
      hidden: [...hidden]..[pos.row] = newHiddenRow,
      waste: newWaste,
    );
    if (pos.row > 0) {
      newState = _revealIfUncovered(newState, pos.row - 1, pos.col);
      newState = _revealIfUncovered(newState, pos.row - 1, pos.col - 1);
    }
    return newState.copyWith(selected: null);
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
    List<List<PyramidCard>>? pyramid,
    List<List<bool>>? hidden,
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
      hidden: hidden ?? this.hidden,
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

    final pyramidKey = useMemoized(() => GlobalKey());
    final stockKey = useMemoized(() => GlobalKey());
    final wasteKey = useMemoized(() => GlobalKey());

    void startTutorial() {
      showGameTutorial(
        context,
        screens: [
          TutorialScreen.key(
            key: pyramidKey,
            message:
                'Welcome to Pyramid! Remove cards summing to 13. Kings can be removed alone. Only exposed cards (not covered by two cards below) can be selected.',
          ),
          TutorialScreen.key(
            key: wasteKey,
            message:
                'You can pair an exposed pyramid card with the top waste card if they sum to 13. Tap to try pairing!',
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
      // No per-game achievement checks for Pyramid currently; global checks handled by CardScaffold
      builder: (context, constraints, cardBack, autoMoveEnabled, gameKey) {
        final axis = constraints.largestAxis;
        final minSize = constraints.smallest.longestSide;
        final spacing = minSize / 100;

        final maxRows = axis == Axis.horizontal
            ? 4.0
            : 10.0; // allow a bit more headroom in portrait
        final maxCols = axis == Axis.horizontal ? 9.0 : 7.0;

        final sizeMultiplier = constraints.findCardSizeMultiplier(
          maxRows: maxRows,
          maxCols: maxCols,
          spacing: spacing,
        );

        Widget buildPyramid() {
          final cardWidth = 69 * sizeMultiplier;
          return Column(
            key: pyramidKey,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: spacing,
            children: List.generate(state.value.pyramid.length, (r) {
              final rowCards = state.value.pyramid[r];

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: spacing,
                children: List.generate(rowCards.length, (c) {
                  final isSelected = state.value.selected?.row == r &&
                      state.value.selected?.col == c;

                  return Container(
                    decoration: isSelected
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.yellow.withOpacity(0.8),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          )
                        : null,
                    child: SizedBox(
                      width: cardWidth,
                      height: 93 * sizeMultiplier,
                    ),
                  );
                }),
              );
            }),
          );
        }

        Widget buildPyramidCards() {
          final cardWidth = 69 * sizeMultiplier;
          final cardHeight = 93 * sizeMultiplier;

          return Stack(
            children: List.generate(state.value.pyramid.length, (r) {
              final rowCards = state.value.pyramid[r];
              final rowHidden = state.value.hidden[r];
              final rowWidth = (cardWidth * rowCards.length) +
                  (spacing * (rowCards.length - 1));

              return Positioned(
                top: r * (cardHeight + spacing),
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: rowWidth,
                    height: cardHeight,
                    child: CardLinearGroup<PyramidCard, dynamic>(
                      value: 'pyr-row-$r',
                      values: rowCards,
                      maxGrabStackSize: 0,
                      cardOffset: Offset(cardWidth + spacing, 0),
                      canCardBeGrabbed: (index, __) => !rowHidden[index],
                      isCardFlipped: (index, __) => rowHidden[index],
                      onCardPressed: (pressedCard) {
                        final c = rowCards.indexOf(pressedCard);
                        if (c == -1) return;
                        if (rowHidden[c]) return;
                        if (state.value.canRemoveKing(pressedCard)) {
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value.withRemoveAt(r, c);
                          return;
                        }
                        if (state.value.waste.isNotEmpty &&
                            state.value.canRemovePair(
                                pressedCard, state.value.waste.last)) {
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value
                              .withRemoveWithWaste(PyramidCardPos(r, c));
                          return;
                        }
                        final selected = state.value.selected;
                        if (selected == null) {
                          state.value = state.value
                              .copyWith(selected: PyramidCardPos(r, c));
                          return;
                        }
                        if (selected.row == r && selected.col == c) {
                          state.value =
                              state.value.copyWith(clearSelected: true);
                          return;
                        }
                        final other =
                            state.value.pyramid[selected.row][selected.col];
                        if (state.value.canRemovePair(pressedCard, other)) {
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value.withRemovePairFromPyramid(
                            PyramidCardPos(r, c),
                            PyramidCardPos(selected.row, selected.col),
                          );
                          return;
                        }
                        state.value = state.value
                            .copyWith(selected: PyramidCardPos(r, c));
                      },
                      canMoveCardHere: (_) => false,
                    ),
                  ),
                ),
              );
            }),
          );
        }

        return CardGame<PyramidCard, dynamic>(
          gameKey: gameKey,
          style: CardGameStyle<PyramidCard, dynamic>(
            cardSize: Size(69, 93) * sizeMultiplier,
            emptyGroupBuilder: (group, state) => const SizedBox.shrink(),
            cardBuilder: (value, group, flipped, cardState) =>
                AnimatedFlippable(
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
          ),
          children: [
            Flex(
              direction: axis,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              spacing: spacing,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      buildPyramid(),
                      buildPyramidCards(),
                    ],
                  ),
                ),
                SizedBox(width: spacing),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: spacing * 2,
                  children: [
                    GestureDetector(
                      key: stockKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: state.value.canDraw
                          ? () {
                              ref.read(audioServiceProvider).playDraw();
                              state.value = state.value.withDraw();
                            }
                          : null,
                      child: CardDeck<PyramidCard, dynamic>.flipped(
                        value: 'stock',
                        values: state.value.stock,
                      ),
                    ),
                    CardDeck<PyramidCard, dynamic>(
                      key: wasteKey,
                      value: 'waste',
                      values: state.value.waste.isEmpty
                          ? const []
                          : [state.value.waste.last],
                      canGrab: false,
                      onCardPressed: (top) {
                        if (state.value.waste.isEmpty) return;
                        final topCard = state.value.waste.last;
                        // Remove King in waste
                        if (state.value.canRemoveKing(topCard)) {
                          ref.read(audioServiceProvider).playPlace();
                          state.value = state.value.copyWith(
                              waste: state.value.waste
                                  .sublist(0, state.value.waste.length - 1),
                              clearSelected: true);
                          return;
                        }
                        // Try pair with selected pyramid card
                        final selected = state.value.selected;
                        if (selected != null) {
                          final other =
                              state.value.pyramid[selected.row][selected.col];
                          if (state.value.canRemovePair(topCard, other)) {
                            ref.read(audioServiceProvider).playPlace();
                            state.value = state.value.withRemoveWithWaste(
                                PyramidCardPos(selected.row, selected.col));
                          }
                        }
                      },
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
