import 'package:card_game/card_game.dart';
import 'package:euchre/logic/card_ranking.dart';
import 'package:euchre/logic/euchre_rules.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';

class CoachAdvice {
  final String recommendation;
  final String reasoning;
  final SuitedCard? suggestedCard;
  final CardSuit? suggestedSuit;

  const CoachAdvice({
    required this.recommendation,
    required this.reasoning,
    this.suggestedCard,
    this.suggestedSuit,
  });
}

class CoachAdvisor {
  const CoachAdvisor();

  CoachAdvice? advise(EuchreRoundState round, Map<Team, int> scores) {
    if (round.currentPlayer != PlayerPosition.south) return null;

    return switch (round.phase) {
      GamePhase.bidRound1 => _adviseBidRound1(round, scores),
      GamePhase.bidRound2 => _adviseBidRound2(round, scores),
      GamePhase.dealerDiscard => _adviseDiscard(round),
      GamePhase.playing => _advisePlay(round, scores),
      _ => null,
    };
  }

  CoachAdvice _adviseBidRound1(EuchreRoundState round, Map<Team, int> scores) {
    final hand = round.handFor(PlayerPosition.south);
    final trumpSuit = round.turnedCard.suit;
    final power = _trumpPower(hand, trumpSuit);
    final trumpCount = hand.where((c) => CardRanking.isTrump(c, trumpSuit)).length;
    final hasRight = hand.any((c) => CardRanking.isRightBower(c, trumpSuit));
    final hasLeft = hand.any((c) => CardRanking.isLeftBower(c, trumpSuit));
    final offAces = hand.where((c) =>
        c.value is AceSuitedCardValue &&
        !CardRanking.isTrump(c, trumpSuit)).length;

    final isDealer = round.dealer == PlayerPosition.south;
    final partnerIsDealer = round.dealer == PlayerPosition.north;

    // Simulate dealer having the turned card
    int effectivePower = power;
    if (isDealer) {
      final withTurned = [...hand, round.turnedCard];
      effectivePower = _trumpPower(withTurned, trumpSuit);
    } else if (partnerIsDealer) {
      effectivePower = power + 1; // Partner gets a trump boost
    }

    final myScore = scores[Team.playerTeam] ?? 0;
    final theirScore = scores[Team.opponentTeam] ?? 0;
    final scorePressure = (theirScore - myScore).clamp(-3, 3);
    final threshold = 5 - scorePressure;

    final reasons = <String>[];

    // Build hand analysis
    if (hasRight) reasons.add('You have the right bower (strongest card)');
    if (hasLeft) reasons.add('You have the left bower');
    if (trumpCount >= 3) {
      reasons.add('$trumpCount trump cards gives you strong trump control');
    } else if (trumpCount == 2) {
      reasons.add('2 trump cards is decent');
    } else if (trumpCount <= 1) {
      reasons.add('Only $trumpCount trump card${trumpCount == 1 ? '' : 's'} \u2013 weak trump holding');
    }
    if (offAces > 0) reasons.add('$offAces off-suit ace${offAces > 1 ? 's' : ''} for side tricks');

    if (isDealer) {
      reasons.add('As dealer, you\'ll pick up the ${_cardName(round.turnedCard)}');
    } else if (partnerIsDealer) {
      reasons.add('Your partner (dealer) would pick up the ${_cardName(round.turnedCard)}');
    }

    if (theirScore > myScore + 2) {
      reasons.add('Behind on score \u2013 be more aggressive');
    } else if (myScore > theirScore + 2) {
      reasons.add('Ahead on score \u2013 can afford to be patient');
    }

    final shouldOrder = effectivePower >= (isDealer || partnerIsDealer ? threshold - 1 : threshold);

    if (shouldOrder) {
      // Check go alone
      final goAlone = hasRight && hasLeft && trumpCount >= 3;
      if (goAlone) {
        return CoachAdvice(
          recommendation: 'Order up & go alone',
          reasoning: '${reasons.join('. ')}. With both bowers and strong trump, you can likely take all 5 tricks alone for 4 points.',
        );
      }
      return CoachAdvice(
        recommendation: 'Order up',
        reasoning: '${reasons.join('. ')}. Hand strength ($effectivePower) is above the threshold \u2013 good chance of taking 3+ tricks.',
      );
    } else {
      return CoachAdvice(
        recommendation: 'Pass',
        reasoning: '${reasons.join('. ')}. Hand strength ($effectivePower) is below the threshold \u2013 risk of getting euchred.',
      );
    }
  }

  CoachAdvice _adviseBidRound2(EuchreRoundState round, Map<Team, int> scores) {
    final hand = round.handFor(PlayerPosition.south);
    final turnedSuit = round.turnedCard.suit;
    final isDealer = round.dealer == PlayerPosition.south;

    CardSuit? bestSuit;
    int bestPower = 0;
    final suitAnalysis = <String>[];

    for (final suit in CardSuit.values) {
      if (suit == turnedSuit) continue;
      final power = _trumpPower(hand, suit);
      final count = hand.where((c) => CardRanking.isTrump(c, suit)).length;
      suitAnalysis.add('${_suitName(suit)}: $count trump, power $power');
      if (power > bestPower) {
        bestPower = power;
        bestSuit = suit;
      }
    }

    final reasons = <String>[];
    reasons.add('${_suitName(turnedSuit)} was turned down');
    reasons.addAll(suitAnalysis);

    if (bestPower >= 4 || isDealer) {
      final suit = bestSuit ?? CardSuit.values.firstWhere((s) => s != turnedSuit);
      if (isDealer && bestPower < 4) {
        reasons.add('As dealer you must pick (stick the dealer) \u2013 ${_suitName(suit)} is your strongest option');
      } else {
        reasons.add('${_suitName(suit)} is strong enough to call');
      }
      return CoachAdvice(
        recommendation: 'Pick ${_suitName(suit)}',
        reasoning: reasons.join('. ') + '.',
        suggestedSuit: suit,
      );
    } else {
      reasons.add('No suit is strong enough to call safely');
      return CoachAdvice(
        recommendation: 'Pass',
        reasoning: reasons.join('. ') + '.',
      );
    }
  }

  CoachAdvice _adviseDiscard(EuchreRoundState round) {
    final hand = round.handFor(PlayerPosition.south);
    final trumpSuit = round.trumpSuit!;

    // Find weakest card to discard
    final sorted = List.of(hand)
      ..sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    final discard = sorted.first;

    final reasons = <String>[];
    if (CardRanking.isTrump(discard, trumpSuit)) {
      reasons.add('${_cardName(discard)} is your weakest trump \u2013 discard to keep stronger cards');
    } else {
      reasons.add('${_cardName(discard)} is your weakest off-suit card');
      final discardSuit = CardRanking.effectiveSuit(discard, trumpSuit);
      final suitCount = hand.where((c) =>
          CardRanking.effectiveSuit(c, trumpSuit) == discardSuit).length;
      if (suitCount == 1) {
        reasons.add('Discarding creates a void in ${_suitName(discardSuit)}, letting you trump that suit');
      }
    }

    return CoachAdvice(
      recommendation: 'Discard ${_cardName(discard)}',
      reasoning: reasons.join('. ') + '.',
      suggestedCard: discard,
    );
  }

  CoachAdvice _advisePlay(EuchreRoundState round, Map<Team, int> scores) {
    final hand = round.handFor(PlayerPosition.south);
    final trumpSuit = round.trumpSuit!;
    final trick = round.currentTrick;
    if (trick == null) return CoachAdvice(recommendation: '', reasoning: '');

    final ledSuit = trick.plays.isNotEmpty
        ? CardRanking.effectiveSuit(trick.plays.first.card, trumpSuit)
        : null;

    final legalPlays = EuchreRules.legalPlays(
      hand: hand,
      ledSuit: ledSuit,
      trumpSuit: trumpSuit,
    );

    if (legalPlays.length == 1) {
      return CoachAdvice(
        recommendation: 'Play ${_cardName(legalPlays.first)}',
        reasoning: 'Only legal play available.',
        suggestedCard: legalPlays.first,
      );
    }

    // Collect played cards for analysis
    final playedCards = <SuitedCard>{};
    for (final t in round.completedTricks) {
      for (final play in t.plays) {
        playedCards.add(play.card);
      }
    }
    for (final play in trick.plays) {
      playedCards.add(play.card);
    }

    if (trick.plays.isEmpty) {
      return _adviseLeading(legalPlays, trumpSuit, playedCards, round);
    }
    return _adviseFollowing(legalPlays, trumpSuit, trick, playedCards, round);
  }

  CoachAdvice _adviseLeading(
    List<SuitedCard> legalPlays,
    CardSuit trumpSuit,
    Set<SuitedCard> playedCards,
    EuchreRoundState round,
  ) {
    final reasons = <String>[];
    final isCaller = round.caller == PlayerPosition.south ||
        round.caller == PlayerPosition.north;

    // Check for highest remaining trump
    final myTrump = legalPlays
        .where((c) => CardRanking.isTrump(c, trumpSuit))
        .toList()
      ..sort((a, b) => CardRanking.cardStrength(b, trumpSuit)
          .compareTo(CardRanking.cardStrength(a, trumpSuit)));

    if (myTrump.isNotEmpty && isCaller) {
      final highest = myTrump.first;
      if (_isHighestRemaining(highest, trumpSuit, playedCards)) {
        reasons.add('${_cardName(highest)} is the highest remaining trump');
        reasons.add('Leading it pulls opponents\' trump, protecting your side tricks');
        return CoachAdvice(
          recommendation: 'Lead ${_cardName(highest)}',
          reasoning: reasons.join('. ') + '.',
          suggestedCard: highest,
        );
      }
    }

    // Check for guaranteed off-suit winners
    for (final card in legalPlays) {
      if (!CardRanking.isTrump(card, trumpSuit) &&
          _isHighestRemainingInSuit(card, trumpSuit, playedCards)) {
        reasons.add('${_cardName(card)} is the highest remaining card in its suit');
        reasons.add('Lead it now before opponents can trump it');
        return CoachAdvice(
          recommendation: 'Lead ${_cardName(card)}',
          reasoning: reasons.join('. ') + '.',
          suggestedCard: card,
        );
      }
    }

    // Lead lowest off-suit to probe
    final offSuit = legalPlays
        .where((c) => !CardRanking.isTrump(c, trumpSuit))
        .toList();
    if (offSuit.isNotEmpty) {
      offSuit.sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      final card = offSuit.first;
      reasons.add('No guaranteed winners available');
      reasons.add('Lead ${_cardName(card)} (lowest off-suit) to probe opponents and save stronger cards');
      return CoachAdvice(
        recommendation: 'Lead ${_cardName(card)}',
        reasoning: reasons.join('. ') + '.',
        suggestedCard: card,
      );
    }

    // Only trump left - lead lowest
    final sorted = List.of(legalPlays)
      ..sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    final card = sorted.first;
    reasons.add('Only trump remaining \u2013 lead ${_cardName(card)} (lowest) to conserve strong trump');
    return CoachAdvice(
      recommendation: 'Lead ${_cardName(card)}',
      reasoning: reasons.join('. ') + '.',
      suggestedCard: card,
    );
  }

  CoachAdvice _adviseFollowing(
    List<SuitedCard> legalPlays,
    CardSuit trumpSuit,
    Trick trick,
    Set<SuitedCard> playedCards,
    EuchreRoundState round,
  ) {
    final ledSuit = CardRanking.effectiveSuit(trick.plays.first.card, trumpSuit);
    final partnerWinning = _isPartnerWinning(trick, trumpSuit);
    final isLastToPlay = trick.plays.length == trick.expectedPlays - 1;
    final reasons = <String>[];

    if (partnerWinning) {
      // Partner winning - throw off lowest
      final sorted = List.of(legalPlays)
        ..sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
            .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      final card = sorted.first;
      reasons.add('Your partner is currently winning this trick');
      reasons.add('Throw off ${_cardName(card)} (weakest card) to save your stronger cards');
      return CoachAdvice(
        recommendation: 'Play ${_cardName(card)}',
        reasoning: reasons.join('. ') + '.',
        suggestedCard: card,
      );
    }

    // Try to win
    final currentBest = _currentBestRank(trick, trumpSuit, ledSuit);
    final winners = legalPlays.where((c) =>
        CardRanking.trickRank(c, trumpSuit, ledSuit) > currentBest).toList();

    if (winners.isNotEmpty) {
      winners.sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));

      final card = isLastToPlay ? winners.first : winners.last;
      if (isLastToPlay) {
        reasons.add('You\'re last to play \u2013 win with the cheapest card possible');
        reasons.add('${_cardName(card)} is enough to take this trick');
      } else {
        reasons.add('Opponents still play after you');
        reasons.add('Play ${_cardName(card)} (strongest winner) to make it harder for them to overtake');
      }
      return CoachAdvice(
        recommendation: 'Play ${_cardName(card)}',
        reasoning: reasons.join('. ') + '.',
        suggestedCard: card,
      );
    }

    // Can't win - discard lowest
    final sorted = List.of(legalPlays)
      ..sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    final card = sorted.first;
    reasons.add('You cannot win this trick with any legal play');
    reasons.add('Discard ${_cardName(card)} (weakest) to preserve stronger cards for later');
    return CoachAdvice(
      recommendation: 'Play ${_cardName(card)}',
      reasoning: reasons.join('. ') + '.',
      suggestedCard: card,
    );
  }

  // --- Helpers ---

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
        power += 1;
      }
    }
    return power;
  }

  bool _isPartnerWinning(Trick trick, CardSuit trumpSuit) {
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
    return bestPlayer?.team == Team.playerTeam && bestPlayer != PlayerPosition.south;
  }

  int _currentBestRank(Trick trick, CardSuit trumpSuit, CardSuit ledSuit) {
    int best = 0;
    for (final play in trick.plays) {
      final rank = CardRanking.trickRank(play.card, trumpSuit, ledSuit);
      if (rank > best) best = rank;
    }
    return best;
  }

  static final _euchreValues = <SuitedCardValue>[
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
    for (final value in _euchreValues) {
      for (final suit in CardSuit.values) {
        final other = SuitedCard(suit: suit, value: value);
        if (playedCards.contains(other) || other == card) continue;
        if (!CardRanking.isTrump(other, trumpSuit)) continue;
        if (CardRanking.cardStrength(other, trumpSuit) > strength) return false;
      }
    }
    return true;
  }

  bool _isHighestRemainingInSuit(
      SuitedCard card, CardSuit trumpSuit, Set<SuitedCard> playedCards) {
    final suit = CardRanking.effectiveSuit(card, trumpSuit);
    final strength = CardRanking.cardStrength(card, trumpSuit);
    for (final value in _euchreValues) {
      final other = SuitedCard(suit: suit, value: value);
      if (playedCards.contains(other) || other == card) continue;
      if (CardRanking.effectiveSuit(other, trumpSuit) != suit) continue;
      if (CardRanking.cardStrength(other, trumpSuit) > strength) return false;
    }
    return true;
  }

  String _cardName(SuitedCard card) {
    final valueName = switch (card.value) {
      NumberSuitedCardValue(:final value) => '$value',
      JackSuitedCardValue() => 'J',
      QueenSuitedCardValue() => 'Q',
      KingSuitedCardValue() => 'K',
      AceSuitedCardValue() => 'A',
      _ => '?',
    };
    final suitSymbol = switch (card.suit) {
      CardSuit.hearts => '\u2665',
      CardSuit.diamonds => '\u2666',
      CardSuit.clubs => '\u2663',
      CardSuit.spades => '\u2660',
    };
    return '$valueName$suitSymbol';
  }

  String _suitName(CardSuit suit) => switch (suit) {
        CardSuit.hearts => 'Hearts',
        CardSuit.diamonds => 'Diamonds',
        CardSuit.clubs => 'Clubs',
        CardSuit.spades => 'Spades',
      };
}
