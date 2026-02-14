import 'package:card_game/card_game.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';

class CardRanking {
  CardRanking._();

  static CardSuit sameColorSuit(CardSuit suit) => switch (suit) {
        CardSuit.hearts => CardSuit.diamonds,
        CardSuit.diamonds => CardSuit.hearts,
        CardSuit.clubs => CardSuit.spades,
        CardSuit.spades => CardSuit.clubs,
      };

  static bool isRightBower(SuitedCard card, CardSuit trumpSuit) =>
      card.value is JackSuitedCardValue && card.suit == trumpSuit;

  static bool isLeftBower(SuitedCard card, CardSuit trumpSuit) =>
      card.value is JackSuitedCardValue && card.suit == sameColorSuit(trumpSuit);

  static bool isBower(SuitedCard card, CardSuit trumpSuit) =>
      isRightBower(card, trumpSuit) || isLeftBower(card, trumpSuit);

  static bool isTrump(SuitedCard card, CardSuit trumpSuit) =>
      effectiveSuit(card, trumpSuit) == trumpSuit;

  /// Returns the effective suit of a card. The left bower counts as trump.
  static CardSuit effectiveSuit(SuitedCard card, CardSuit trumpSuit) {
    if (isLeftBower(card, trumpSuit)) return trumpSuit;
    return card.suit;
  }

  /// Base value of a card ignoring suit context, used for ranking.
  static int _baseValue(SuitedCardValue value) => switch (value) {
        NumberSuitedCardValue(:final value) => value,
        JackSuitedCardValue() => 11,
        QueenSuitedCardValue() => 12,
        KingSuitedCardValue() => 13,
        AceSuitedCardValue() => 14,
      };

  /// Returns a numeric rank for a card in the context of a trick.
  /// Higher is better. Off-suit non-trump cards that don't match led suit = 0.
  static int trickRank(SuitedCard card, CardSuit trumpSuit, CardSuit ledSuit) {
    if (isRightBower(card, trumpSuit)) return 100;
    if (isLeftBower(card, trumpSuit)) return 99;

    final effective = effectiveSuit(card, trumpSuit);

    if (effective == trumpSuit) {
      // Trump cards rank 80-94
      return 80 + _baseValue(card.value);
    }

    if (effective == ledSuit) {
      // Led-suit cards rank 1-14
      return _baseValue(card.value);
    }

    // Off-suit, non-trump: can't win
    return 0;
  }

  /// Determines the winner of a trick.
  static PlayerPosition trickWinner(List<TrickPlay> plays, CardSuit trumpSuit) {
    final ledSuit = effectiveSuit(plays.first.card, trumpSuit);

    PlayerPosition bestPlayer = plays.first.player;
    int bestRank = trickRank(plays.first.card, trumpSuit, ledSuit);

    for (int i = 1; i < plays.length; i++) {
      final rank = trickRank(plays[i].card, trumpSuit, ledSuit);
      if (rank > bestRank) {
        bestRank = rank;
        bestPlayer = plays[i].player;
      }
    }

    return bestPlayer;
  }

  /// Returns a general strength value for a card (for AI evaluation).
  /// Trump cards are valued higher than off-suit.
  static int cardStrength(SuitedCard card, CardSuit trumpSuit) {
    if (isRightBower(card, trumpSuit)) return 21;
    if (isLeftBower(card, trumpSuit)) return 20;
    if (effectiveSuit(card, trumpSuit) == trumpSuit) {
      return 14 + _baseValue(card.value);
    }
    return _baseValue(card.value);
  }
}
