import 'dart:math';
import 'package:card_game/card_game.dart';
import 'package:euchre/model/player.dart';

class DeckBuilder {
  DeckBuilder._();

  /// Creates a 24-card Euchre deck: 9, 10, J, Q, K, A of each suit.
  static List<SuitedCard> euchreDeck() {
    final List<SuitedCardValue> values = [
      NumberSuitedCardValue(value: 9),
      NumberSuitedCardValue(value: 10),
      JackSuitedCardValue(),
      QueenSuitedCardValue(),
      KingSuitedCardValue(),
      AceSuitedCardValue(),
    ];

    return [
      for (final suit in CardSuit.values)
        for (final value in values)
          SuitedCard(suit: suit, value: value),
    ];
  }

  /// Shuffles and deals a Euchre hand.
  /// Returns hands for each player (5 cards each), kitty (4 cards),
  /// and turned card (top of kitty).
  /// Deals in standard 3-2-3-2 then 2-3-2-3 pattern.
  static DealResult deal(PlayerPosition dealer, [int? seed]) {
    final deck = euchreDeck();
    final rng = seed != null ? Random(seed) : Random();
    deck.shuffle(rng);

    final hands = <PlayerPosition, List<SuitedCard>>{
      for (final pos in PlayerPosition.values) pos: [],
    };

    // Deal starting from left of dealer
    var dealTo = dealer.next;
    // First round: 3-2-3-2
    final firstRoundCounts = [3, 2, 3, 2];
    int cardIndex = 0;

    for (int i = 0; i < 4; i++) {
      final count = firstRoundCounts[i];
      for (int j = 0; j < count; j++) {
        hands[dealTo]!.add(deck[cardIndex++]);
      }
      dealTo = dealTo.next;
    }

    // Second round: 2-3-2-3
    dealTo = dealer.next;
    final secondRoundCounts = [2, 3, 2, 3];
    for (int i = 0; i < 4; i++) {
      final count = secondRoundCounts[i];
      for (int j = 0; j < count; j++) {
        hands[dealTo]!.add(deck[cardIndex++]);
      }
      dealTo = dealTo.next;
    }

    // Remaining 4 cards are the kitty
    final kitty = deck.sublist(cardIndex);
    final turnedCard = kitty.first;

    return DealResult(
      hands: hands,
      kitty: kitty,
      turnedCard: turnedCard,
    );
  }
}

class DealResult {
  final Map<PlayerPosition, List<SuitedCard>> hands;
  final List<SuitedCard> kitty;
  final SuitedCard turnedCard;

  const DealResult({
    required this.hands,
    required this.kitty,
    required this.turnedCard,
  });
}
