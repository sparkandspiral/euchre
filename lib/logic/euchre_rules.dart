import 'package:card_game/card_game.dart';
import 'package:euchre/logic/card_ranking.dart';

class EuchreRules {
  EuchreRules._();

  /// Returns the list of cards a player can legally play.
  /// Must follow the effective led suit if possible. The left bower
  /// counts as trump, not its printed suit.
  static List<SuitedCard> legalPlays({
    required List<SuitedCard> hand,
    required CardSuit? ledSuit,
    required CardSuit trumpSuit,
  }) {
    if (hand.isEmpty) return [];

    // If leading, any card is legal
    if (ledSuit == null) return List.of(hand);

    // Must follow the effective led suit
    final effectiveLed = ledSuit;
    final followSuit = hand
        .where((card) =>
            CardRanking.effectiveSuit(card, trumpSuit) == effectiveLed)
        .toList();

    if (followSuit.isNotEmpty) return followSuit;

    // Can't follow suit - play anything
    return List.of(hand);
  }

  /// Whether a specific card is a legal play given the current trick state.
  static bool isLegalPlay({
    required SuitedCard card,
    required List<SuitedCard> hand,
    required CardSuit? ledSuit,
    required CardSuit trumpSuit,
  }) {
    final legal = legalPlays(
      hand: hand,
      ledSuit: ledSuit,
      trumpSuit: trumpSuit,
    );
    return legal.any((c) => c == card);
  }

  /// Whether the Euchre deck uses this card (9, 10, J, Q, K, A).
  static bool isEuchreCard(SuitedCard card) {
    final value = card.value;
    if (value is NumberSuitedCardValue) {
      return value.value >= 9;
    }
    return true; // Face cards and aces
  }
}
