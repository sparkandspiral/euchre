import 'dart:math';

import 'dart:async';

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
import 'package:solitaire/utils/axis_extensions.dart';
import 'package:solitaire/utils/constraints_extensions.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/utils/card_description.dart';
import 'package:solitaire/utils/suited_card_codec.dart';
import 'package:solitaire/widgets/card_scaffold.dart';
import 'package:solitaire/widgets/game_tutorial.dart';
import 'package:utils/utils.dart';

class GolfSolitaireState {
  final List<List<SuitedCard>> cards;
  final List<SuitedCard> deck;
  final List<SuitedCard> completedCards;
  final int chain;

  final bool canRollover;

  final ImmutableHistory<GolfSolitaireState> history;

  GolfSolitaireState({
    required this.cards,
    required this.deck,
    required this.completedCards,
    required this.chain,
    required this.canRollover,
    required this.history,
  });

  static GolfSolitaireState getInitialState({
    required bool startWithDraw,
    required bool canRollover,
    int? shuffleSeed,
  }) {
    final random = shuffleSeed == null ? Random() : Random(shuffleSeed);
    var deck = List.of(SuitedCard.deck)..shuffle(random);

    final cards = List.generate(7, (i) {
      final column = deck.take(5).toList();
      deck = deck.skip(5).toList();
      return column;
    });

    var completedCards = <SuitedCard>[];
    if (startWithDraw) {
      completedCards.add(deck.first);
      deck = deck.skip(1).toList();
    }

    return GolfSolitaireState(
      cards: cards,
      deck: deck,
      completedCards: completedCards,
      chain: 0,
      canRollover: canRollover,
      history: const ImmutableHistory.empty(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cards': cards
            .map((column) => column.map(encodeSuitedCard).toList())
            .toList(),
        'deck': deck.map(encodeSuitedCard).toList(),
        'completed': completedCards.map(encodeSuitedCard).toList(),
        'chain': chain,
        'canRollover': canRollover,
      };

  factory GolfSolitaireState.fromJson(Map<String, dynamic> json) {
    List<List<SuitedCard>> decodeColumns(List<dynamic> data) => data
        .map<List<SuitedCard>>((column) => (column as List)
            .map((card) => decodeSuitedCard(
                Map<String, dynamic>.from(card as Map<dynamic, dynamic>)))
            .toList())
        .toList();

    List<SuitedCard> decodeList(List<dynamic> data) => data
        .map((card) => decodeSuitedCard(
            Map<String, dynamic>.from(card as Map<dynamic, dynamic>)))
        .toList();

    return GolfSolitaireState(
      cards: decodeColumns(json['cards'] as List<dynamic>),
      deck: decodeList(json['deck'] as List<dynamic>),
      completedCards: decodeList(json['completed'] as List<dynamic>),
      chain: json['chain'] as int? ?? 0,
      canRollover: json['canRollover'] as bool? ?? true,
      history: const ImmutableHistory.empty(),
    );
  }

  SuitedCardDistanceMapper get distanceMapper => canRollover
      ? SuitedCardDistanceMapper.rollover
      : SuitedCardDistanceMapper.aceToKing;

  bool canSelect(SuitedCard card) =>
      completedCards.isEmpty ||
      distanceMapper.getDistance(completedCards.last, card) == 1;

  GolfSolitaireState withSelection(SuitedCard card) => GolfSolitaireState(
        cards: cards.map((column) => [...column]..remove(card)).toList(),
        deck: deck,
        completedCards: completedCards + [card],
        chain: chain + 1,
        canRollover: canRollover,
        history: history.pushCapped(this, maxLength: kDefaultHistoryLimit),
      );

  bool get canDraw => deck.isNotEmpty;

  GolfSolitaireState withDraw() => GolfSolitaireState(
        cards: cards,
        deck: deck.sublist(0, deck.length - 1),
        completedCards: completedCards + [deck.last],
        chain: 0,
        canRollover: canRollover,
        history: history.pushCapped(this, maxLength: kDefaultHistoryLimit),
      );

  HintSuggestion? findHint() {
    final foundation = completedCards.lastOrNull;
    final foundationDescription = foundation == null
        ? 'the foundation'
        : '${describeCard(foundation)} on the foundation';

    for (int column = 0; column < cards.length; column++) {
      final card = cards[column].lastOrNull;
      if (card != null && canSelect(card)) {
        final source = describeColumn(column);
        final target = foundation == null
            ? 'to start the foundation'
            : 'onto $foundationDescription';
        return HintSuggestion(
          message: 'Play ${describeCard(card)} from $source $target.',
        );
      }
    }

    if (canDraw) {
      return const HintSuggestion(
        message: 'Draw a new card to refresh the foundation.',
      );
    }

    return null;
  }

  GolfSolitaireState withUndo() => history.last;

  bool get isVictory => cards.every((column) => column.isEmpty);

  bool get hasAvailableMoves => findHint() != null;
}

class GolfSolitaire extends HookConsumerWidget {
  final Difficulty difficulty;
  final bool startWithTutorial;
  final DailyChallengeConfig? dailyChallenge;
  final ActiveGameSnapshot? snapshot;

  const GolfSolitaire({
    super.key,
    required this.difficulty,
    this.startWithTutorial = false,
    this.dailyChallenge,
    this.snapshot,
  });

  GolfSolitaireState get defaultInitialState => GolfSolitaireState.getInitialState(
        startWithDraw: difficulty.index >= Difficulty.royal.index,
        canRollover: difficulty != Difficulty.ace,
        shuffleSeed: dailyChallenge?.shuffleSeed,
      );

  GolfSolitaireState get initialState {
    if (dailyChallenge != null) return defaultInitialState;
    if (snapshot != null) {
      try {
        return GolfSolitaireState.fromJson(snapshot!.state);
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
        game: Game.golf,
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
        saveStateNotifier.clearActiveGame(Game.golf);
    useOnListenableChange(
      state,
      () => ref
          .read(achievementServiceProvider)
          .checkGolfSolitaireMoveAchievements(state: state.value),
    );

    final tableauKey = useMemoized(() => GlobalKey());
    final foundationKey = useMemoized(() => GlobalKey());
    final drawPileKey = useMemoized(() => GlobalKey());

    void startTutorial() {
      showGameTutorial(
        context,
        screens: [
          TutorialScreen.key(
            key: tableauKey,
            message:
                'Welcome to Golf Solitaire! Your goal is to clear all the cards from the tableau.',
          ),
          TutorialScreen.key(
            key: foundationKey,
            message:
                'Cards are cleared by moving them to the foundation. A card can be moved if its rank is one higher or one lower than the current foundation card. Aces and Kings wrap around (Ace > King > Queen or King > Ace > 2).',
          ),
          TutorialScreen.key(
            key: drawPileKey,
            message:
                'When no moves are available from the tableau, tap the draw pile to flip a new card to the foundation. This gives you new options to continue clearing cards.',
          ),
          TutorialScreen.everything(
              message:
                  "Win by clearing all cards from the tableau. If you run out of cards in the draw pile and can't make any more moves, the game is over. Tap to begin playing!"),
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
      game: Game.golf,
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
          .checkGolfSolitaireCompletionAchievements(
                state: state.value, difficulty: difficulty);
        if (dailyChallenge == null) {
          await clearSnapshot();
        }
      },
      builder: (context, constraints, cardBack, autoMoveEnabled, gameKey) {
        final axis = constraints.largestAxis;
        final minSize = constraints.smallest.longestSide;
        final spacing = minSize / 100;

        final sizeMultiplier = constraints.findCardSizeMultiplier(
          maxRows: axis == Axis.horizontal ? 2 : 7,
          maxCols: axis == Axis.horizontal ? 8 : 1,
          spacing: spacing,
        );

        final cardOffset = sizeMultiplier * 25;

        return CardGame<SuitedCard, dynamic>(
          gameKey: gameKey,
          style: playingCardStyle(
              sizeMultiplier: sizeMultiplier, cardBack: cardBack),
          children: [
            Row(
              children: [
                Expanded(
                  child: Flex(
                    key: tableauKey,
                    direction: axis,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: state.value.cards
                        .mapIndexed((i, column) =>
                            CardLinearGroup<SuitedCard, dynamic>(
                              cardOffset: axis.inverted.offset * cardOffset,
                              value: i,
                              values: column,
                              canCardBeGrabbed: (_, __) => false,
                              maxGrabStackSize: 0,
                              onCardPressed: (card) {
                                final lastCard =
                                    state.value.cards[i].lastOrNull;
                                if (lastCard != card) {
                                  return;
                                }
                                if (state.value.canSelect(card)) {
                                  ref.read(audioServiceProvider).playPlace();
                                  state.value = state.value.withSelection(card);
                                }
                              },
                            ))
                        .toList(),
                  ),
                ),
                SizedBox(width: spacing),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 40,
                  children: [
                    CardDeck<SuitedCard, dynamic>.flipped(
                      key: drawPileKey,
                      value: 'deck',
                      values: state.value.deck,
                      onCardPressed: (_) {
                        ref.read(audioServiceProvider).playDraw();
                        state.value = state.value.withDraw();
                      },
                    ),
                    CardDeck<SuitedCard, dynamic>(
                      key: foundationKey,
                      value: 'completed',
                      values: state.value.completedCards,
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
