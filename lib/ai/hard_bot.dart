import 'package:card_game/card_game.dart';
import 'package:euchre/ai/bot_player.dart';
import 'package:euchre/logic/card_ranking.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';

class HardBot implements BotPlayer {

  @override
  bool shouldOrderUp({
    required List<SuitedCard> hand,
    required SuitedCard turnedCard,
    required PlayerPosition dealer,
    required PlayerPosition self,
    required Map<Team, int> scores,
  }) {
    final trumpSuit = turnedCard.suit;
    final power = _trumpPower(hand, trumpSuit);
    final myScore = scores[self.team] ?? 0;
    final theirScore = scores[self.team.opponent] ?? 0;

    // More aggressive when behind, conservative when ahead
    final scorePressure = (theirScore - myScore).clamp(-3, 3);
    final threshold = 5 - scorePressure;

    // Dealer position bonus - they get the turned card
    if (dealer == self) {
      // We get the card - simulate having it
      final withTurned = [...hand, turnedCard];
      final powerWithCard = _trumpPower(withTurned, trumpSuit);
      return powerWithCard >= threshold - 1;
    }
    if (dealer == self.partner) {
      return power >= threshold - 1; // Partner gets the card
    }

    return power >= threshold;
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
      final power = _trumpPower(hand, suit);
      if (power > bestPower) {
        bestPower = power;
        bestSuit = suit;
      }
    }

    if (bestPower >= 4 || mustPick) {
      return bestSuit ?? CardSuit.values.firstWhere((s) => s != turnedSuit);
    }
    return null;
  }

  @override
  bool shouldGoAlone({
    required List<SuitedCard> hand,
    required CardSuit trumpSuit,
  }) {
    final power = _trumpPower(hand, trumpSuit);
    final hasRight = hand.any((c) => CardRanking.isRightBower(c, trumpSuit));
    final hasLeft = hand.any((c) => CardRanking.isLeftBower(c, trumpSuit));
    final trumpCount = hand.where((c) => CardRanking.isTrump(c, trumpSuit)).length;

    // Go alone with strong hands
    if (hasRight && hasLeft && trumpCount >= 3) return true;
    if (power >= 12 && trumpCount >= 3) return true;
    return false;
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
    if (legalPlays.length == 1) return legalPlays.first;

    // Track which cards have been played
    final playedCards = <SuitedCard>{};
    for (final trick in completedTricks) {
      for (final play in trick.plays) {
        playedCards.add(play.card);
      }
    }
    for (final play in currentTrick.plays) {
      playedCards.add(play.card);
    }

    if (currentTrick.plays.isEmpty) {
      return _chooseLead(legalPlays, trumpSuit, playedCards, completedTricks);
    }
    return _chooseFollow(
      legalPlays, trumpSuit, currentTrick, self, playedCards,
    );
  }

  @override
  SuitedCard chooseDiscard({
    required List<SuitedCard> hand,
    required CardSuit trumpSuit,
  }) {
    // Discard weakest card, preferring to keep trump and aces
    final sorted = List.of(hand)
      ..sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    return sorted.first;
  }

  SuitedCard _chooseLead(
    List<SuitedCard> legalPlays,
    CardSuit trumpSuit,
    Set<SuitedCard> playedCards,
    List<Trick> completedTricks,
  ) {
    // Count remaining trump in play
    final remainingTrump = _countRemainingTrump(trumpSuit, playedCards);

    // If we have the highest remaining trump, lead it to draw trump
    if (remainingTrump > 0) {
      final myTrump = legalPlays
          .where((c) => CardRanking.isTrump(c, trumpSuit))
          .toList()
        ..sort((a, b) =>
            CardRanking.cardStrength(b, trumpSuit)
                .compareTo(CardRanking.cardStrength(a, trumpSuit)));

      if (myTrump.isNotEmpty) {
        final highestMine = myTrump.first;
        if (_isHighestRemaining(highestMine, trumpSuit, playedCards)) {
          return highestMine;
        }
      }
    }

    // Lead with guaranteed winners (aces or kings where ace is played)
    for (final card in legalPlays) {
      if (!CardRanking.isTrump(card, trumpSuit) &&
          _isHighestRemainingInSuit(card, trumpSuit, playedCards)) {
        return card;
      }
    }

    // Lead lowest off-suit to probe
    final offSuit = legalPlays
        .where((c) => !CardRanking.isTrump(c, trumpSuit))
        .toList();
    if (offSuit.isNotEmpty) {
      offSuit.sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      return offSuit.first;
    }

    // Only trump - lead lowest
    final sorted = List.of(legalPlays)
      ..sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    return sorted.first;
  }

  SuitedCard _chooseFollow(
    List<SuitedCard> legalPlays,
    CardSuit trumpSuit,
    Trick currentTrick,
    PlayerPosition self,
    Set<SuitedCard> playedCards,
  ) {
    final ledSuit = CardRanking.effectiveSuit(
        currentTrick.plays.first.card, trumpSuit);
    final partnerWinning = _isPartnerWinning(currentTrick, trumpSuit, self);
    final isLastToPlay = currentTrick.plays.length == currentTrick.expectedPlays - 1;

    if (partnerWinning) {
      // Partner winning - throw off lowest
      // But if last to play, definitely throw off lowest
      final sorted = List.of(legalPlays)
        ..sort((a, b) =>
            CardRanking.cardStrength(a, trumpSuit)
                .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      return sorted.first;
    }

    // Try to win cheaply
    final currentBest = _currentBestRank(currentTrick, trumpSuit, ledSuit);
    final winners = legalPlays.where((c) =>
        CardRanking.trickRank(c, trumpSuit, ledSuit) > currentBest).toList();

    if (winners.isNotEmpty) {
      // Play cheapest winner if last to play, strongest if not
      winners.sort((a, b) =>
          CardRanking.cardStrength(a, trumpSuit)
              .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      return isLastToPlay ? winners.first : winners.last;
    }

    // Can't win - shed lowest value card, prefer discarding from short suits
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

  int _trumpPower(List<SuitedCard> hand, CardSuit trumpSuit) {
    int power = 0;
    for (final card in hand) {
      if (CardRanking.isRightBower(card, trumpSuit)) {
        power += 4;
      } else if (CardRanking.isLeftBower(card, trumpSuit)) {
        power += 3;
      } else if (card.value is AceSuitedCardValue &&
          CardRanking.effectiveSuit(card, trumpSuit) == trumpSuit) {
        power += 2;
      } else if (CardRanking.isTrump(card, trumpSuit)) {
        power += 1;
      } else if (card.value is AceSuitedCardValue) {
        power += 1; // Off-suit aces have some value
      }
    }
    return power;
  }

  int _countRemainingTrump(CardSuit trumpSuit, Set<SuitedCard> playedCards) {
    int count = 0;
    // All possible trump cards in Euchre deck
    for (final card in _allTrumpCards(trumpSuit)) {
      if (!playedCards.contains(card)) count++;
    }
    return count;
  }

  List<SuitedCard> _allTrumpCards(CardSuit trumpSuit) {
    final cards = <SuitedCard>[];
    // Right bower
    for (final value in _euchreValues) {
      final card = SuitedCard(suit: trumpSuit, value: value);
      cards.add(card);
    }
    // Left bower
    cards.add(SuitedCard(
      suit: CardRanking.sameColorSuit(trumpSuit),
      value: JackSuitedCardValue(),
    ));
    return cards;
  }

  static List<SuitedCardValue> get _euchreValues => <SuitedCardValue>[
    NumberSuitedCardValue(value: 9),
    NumberSuitedCardValue(value: 10),
    JackSuitedCardValue(),
    QueenSuitedCardValue(),
    KingSuitedCardValue(),
    AceSuitedCardValue(),
  ];

  bool _isHighestRemaining(
      SuitedCard card, CardSuit trumpSuit, Set<SuitedCard> playedCards) {
    final strength = CardRanking.cardStrength(card, trumpSuit);
    for (final other in _allTrumpCards(trumpSuit)) {
      if (playedCards.contains(other)) continue;
      if (other == card) continue;
      if (CardRanking.cardStrength(other, trumpSuit) > strength) return false;
    }
    return true;
  }

  bool _isHighestRemainingInSuit(
      SuitedCard card, CardSuit trumpSuit, Set<SuitedCard> playedCards) {
    final suit = CardRanking.effectiveSuit(card, trumpSuit);
    final strength = CardRanking.cardStrength(card, trumpSuit);
    for (final value in _euchreValues) {
      final other = SuitedCard(suit: suit, value: value);
      if (playedCards.contains(other)) continue;
      if (other == card) continue;
      if (CardRanking.effectiveSuit(other, trumpSuit) != suit) continue;
      if (CardRanking.cardStrength(other, trumpSuit) > strength) return false;
    }
    return true;
  }
}
