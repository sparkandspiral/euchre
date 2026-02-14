import 'package:card_game/card_game.dart';
import 'package:euchre/ai/bot_player.dart';
import 'package:euchre/logic/card_ranking.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';

class MediumBot implements BotPlayer {

  @override
  bool shouldOrderUp({
    required List<SuitedCard> hand,
    required SuitedCard turnedCard,
    required PlayerPosition dealer,
    required PlayerPosition self,
    required Map<Team, int> scores,
  }) {
    final trumpSuit = turnedCard.suit;
    final trumpPower = _calculateTrumpPower(hand, trumpSuit);

    // If we're the dealer, the turned card comes to us
    if (dealer == self) {
      return trumpPower >= 4;
    }
    // If partner is dealer, they get the card
    if (dealer == self.partner) {
      return trumpPower >= 4;
    }
    // Opponents benefit from ordering up
    return trumpPower >= 6;
  }

  @override
  CardSuit? pickTrumpSuit({
    required List<SuitedCard> hand,
    required CardSuit turnedSuit,
    required bool mustPick,
  }) {
    CardSuit? bestSuit;
    int bestPower = 0;

    for (final suit in CardSuit.values) {
      if (suit == turnedSuit) continue;
      final power = _calculateTrumpPower(hand, suit);
      if (power > bestPower) {
        bestPower = power;
        bestSuit = suit;
      }
    }

    if (bestPower >= 5 || mustPick) {
      return bestSuit ?? CardSuit.values.firstWhere((s) => s != turnedSuit);
    }
    return null;
  }

  @override
  bool shouldGoAlone({
    required List<SuitedCard> hand,
    required CardSuit trumpSuit,
  }) {
    // Go alone with both bowers + ace
    final hasRight = hand.any((c) => CardRanking.isRightBower(c, trumpSuit));
    final hasLeft = hand.any((c) => CardRanking.isLeftBower(c, trumpSuit));
    final hasAce = hand.any((c) =>
        c.value is AceSuitedCardValue &&
        CardRanking.effectiveSuit(c, trumpSuit) == trumpSuit);
    return hasRight && hasLeft && hasAce;
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
    if (currentTrick.plays.isEmpty) {
      return _chooseLead(legalPlays, trumpSuit);
    }
    return _chooseFollowOrTrump(
      legalPlays, trumpSuit, currentTrick, self,
    );
  }

  @override
  SuitedCard chooseDiscard({
    required List<SuitedCard> hand,
    required CardSuit trumpSuit,
  }) {
    // Discard the weakest card
    final sorted = List.of(hand)
      ..sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    return sorted.first;
  }

  SuitedCard _chooseLead(List<SuitedCard> legalPlays, CardSuit trumpSuit) {
    // Lead with highest off-suit ace if available
    final offSuitAces = legalPlays.where((c) =>
        c.value is AceSuitedCardValue &&
        !CardRanking.isTrump(c, trumpSuit)).toList();
    if (offSuitAces.isNotEmpty) return offSuitAces.first;

    // Lead with highest non-trump
    final nonTrump = legalPlays
        .where((c) => !CardRanking.isTrump(c, trumpSuit))
        .toList();
    if (nonTrump.isNotEmpty) {
      nonTrump.sort((a, b) =>
          CardRanking.cardStrength(b, trumpSuit)
              .compareTo(CardRanking.cardStrength(a, trumpSuit)));
      return nonTrump.first;
    }

    // Only trump left - lead highest
    final sorted = List.of(legalPlays)
      ..sort((a, b) =>
          CardRanking.cardStrength(b, trumpSuit)
              .compareTo(CardRanking.cardStrength(a, trumpSuit)));
    return sorted.first;
  }

  SuitedCard _chooseFollowOrTrump(
    List<SuitedCard> legalPlays,
    CardSuit trumpSuit,
    Trick currentTrick,
    PlayerPosition self,
  ) {
    final ledSuit = CardRanking.effectiveSuit(
        currentTrick.plays.first.card, trumpSuit);

    // Check if partner is currently winning
    final partnerWinning = _isPartnerWinning(currentTrick, trumpSuit, self);

    if (partnerWinning) {
      // Play lowest legal card
      final sorted = List.of(legalPlays)
        ..sort((a, b) =>
            CardRanking.cardStrength(a, trumpSuit)
                .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      return sorted.first;
    }

    // Try to win with the cheapest winning card
    final currentBest = _currentBestRank(currentTrick, trumpSuit, ledSuit);
    final winners = legalPlays.where((c) =>
        CardRanking.trickRank(c, trumpSuit, ledSuit) > currentBest).toList();

    if (winners.isNotEmpty) {
      // Play the cheapest winner
      winners.sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      return winners.first;
    }

    // Can't win - play lowest card
    final sorted = List.of(legalPlays)
      ..sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    return sorted.first;
  }

  bool _isPartnerWinning(Trick trick, CardSuit trumpSuit, PlayerPosition self) {
    if (trick.plays.isEmpty) return false;
    final ledSuit = CardRanking.effectiveSuit(trick.plays.first.card, trumpSuit);
    int bestRank = 0;
    PlayerPosition? bestPlayer;
    for (final play in trick.plays) {
      final rank = CardRanking.trickRank(play.card, trumpSuit, ledSuit);
      if (rank > bestRank) {
        bestRank = rank;
        bestPlayer = play.player;
      }
    }
    return bestPlayer?.team == self.team && bestPlayer != self;
  }

  int _currentBestRank(Trick trick, CardSuit trumpSuit, CardSuit ledSuit) {
    int best = 0;
    for (final play in trick.plays) {
      final rank = CardRanking.trickRank(play.card, trumpSuit, ledSuit);
      if (rank > best) best = rank;
    }
    return best;
  }

  int _calculateTrumpPower(List<SuitedCard> hand, CardSuit trumpSuit) {
    int power = 0;
    for (final card in hand) {
      if (CardRanking.isRightBower(card, trumpSuit)) {
        power += 4;
      } else if (CardRanking.isLeftBower(card, trumpSuit)) {
        power += 3;
      } else if (card.value is AceSuitedCardValue && card.suit == trumpSuit) {
        power += 2;
      } else if (CardRanking.isTrump(card, trumpSuit)) {
        power += 1;
      }
    }
    return power;
  }
}
