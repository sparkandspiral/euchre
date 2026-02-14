import 'dart:math';
import 'package:card_game/card_game.dart';
import 'package:euchre/ai/bot_player.dart';
import 'package:euchre/logic/card_ranking.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';

class EasyBot implements BotPlayer {
  final _rng = Random();

  @override
  bool shouldOrderUp({
    required List<SuitedCard> hand,
    required SuitedCard turnedCard,
    required PlayerPosition dealer,
    required PlayerPosition self,
    required Map<Team, int> scores,
  }) {
    // Easy bot: order up only with 3+ trump including a bower
    final trumpSuit = turnedCard.suit;
    final trumpCount = hand.where((c) => CardRanking.isTrump(c, trumpSuit)).length;
    final hasBower = hand.any((c) => CardRanking.isBower(c, trumpSuit));

    // If dealer is on our team, the turned card helps
    if (dealer.team == self.team) {
      return trumpCount >= 2 && hasBower;
    }
    return trumpCount >= 3 && hasBower;
  }

  @override
  CardSuit? pickTrumpSuit({
    required List<SuitedCard> hand,
    required CardSuit turnedSuit,
    required bool mustPick,
  }) {
    // Find suit with most cards (excluding the turned suit)
    final suitCounts = <CardSuit, int>{};
    for (final suit in CardSuit.values) {
      if (suit == turnedSuit) continue;
      suitCounts[suit] = hand.where((c) => CardRanking.effectiveSuit(c, suit) == suit).length;
    }

    final bestSuit = suitCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b);

    if (bestSuit.value >= 3 || mustPick) {
      return bestSuit.key;
    }
    return null;
  }

  @override
  bool shouldGoAlone({
    required List<SuitedCard> hand,
    required CardSuit trumpSuit,
  }) {
    return false; // Easy bot never goes alone
  }

  @override
  SuitedCard chooseCard({
    required List<SuitedCard> hand,
    required List<SuitedCard> legalPlays,
    required CardSuit trumpSuit,
    required Trick currentTrick,
    required PlayerPosition self,
    required List<Trick> completedTricks,
    required Map<Team, int> scores,
  }) {
    // Easy bot: random legal card
    return legalPlays[_rng.nextInt(legalPlays.length)];
  }

  @override
  SuitedCard chooseDiscard({
    required List<SuitedCard> hand,
    required CardSuit trumpSuit,
  }) {
    // Discard lowest non-trump card, or lowest trump if all trump
    final nonTrump = hand.where((c) => !CardRanking.isTrump(c, trumpSuit)).toList();
    if (nonTrump.isNotEmpty) {
      nonTrump.sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      return nonTrump.first;
    }
    // All trump - discard lowest
    final sorted = List.of(hand)
      ..sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    return sorted.first;
  }
}
