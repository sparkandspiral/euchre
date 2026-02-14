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
  final String gameContext;
  final SuitedCard? suggestedCard;
  final CardSuit? suggestedSuit;

  const CoachAdvice({
    required this.recommendation,
    required this.reasoning,
    this.gameContext = '',
    this.suggestedCard,
    this.suggestedSuit,
  });
}

class CoachAdvisor {
  const CoachAdvisor();

  CoachAdvice? advise(EuchreRoundState round, Map<Team, int> scores) {
    if (round.currentPlayer != PlayerPosition.south) return null;

    final context = _buildGameContext(round, scores);

    final advice = switch (round.phase) {
      GamePhase.bidRound1 => _adviseBidRound1(round, scores),
      GamePhase.bidRound2 => _adviseBidRound2(round, scores),
      GamePhase.dealerDiscard => _adviseDiscard(round, scores),
      GamePhase.playing => _advisePlay(round, scores),
      _ => null,
    };

    if (advice == null) return null;

    return CoachAdvice(
      recommendation: advice.recommendation,
      reasoning: advice.reasoning,
      gameContext: context,
      suggestedCard: advice.suggestedCard,
      suggestedSuit: advice.suggestedSuit,
    );
  }

  // ─── Game Context (Meta Strategy) ────────────────────────

  String _buildGameContext(EuchreRoundState round, Map<Team, int> scores) {
    final parts = <String>[];
    final us = scores[Team.playerTeam] ?? 0;
    final them = scores[Team.opponentTeam] ?? 0;

    // Score headline
    parts.add('Score: Us $us \u2013 Them $them');

    // Score-based meta strategy
    if (us >= 9 && them >= 9) {
      parts.add('Both at game point \u2013 next successful call wins it all');
    } else if (us >= 9) {
      parts.add('Game point! Any successful call wins. Bid aggressively');
    } else if (them >= 9) {
      parts.add(
          'Opponents at game point \u2013 must call or risk them winning cheaply');
    } else if (us >= 8) {
      parts.add('One away \u2013 even a 1-point call wins next round');
    } else if (them >= 8) {
      parts.add(
          'Opponents close to winning \u2013 look for loner opportunities to catch up');
    } else if (us > them + 4) {
      parts.add(
          'Comfortable lead \u2013 play solid, avoid risky calls that could give free euchres');
    } else if (them > us + 4) {
      parts.add(
          'Falling behind \u2013 take calculated risks, consider going alone with strong hands');
    } else if (us > them) {
      parts.add('Slight lead \u2013 maintain pressure with smart calls');
    } else if (them > us) {
      parts.add('Trailing \u2013 look for opportunities to close the gap');
    }

    // Risk/reward framing for active round
    if (round.caller != null) {
      if (round.caller!.team == Team.playerTeam) {
        final euchreResult = them + 2;
        parts.add('We called \u2013 need 3+ tricks or opponents score 2');
        if (euchreResult >= 10) {
          parts.add('\u26A0 Getting euchred loses the game!');
        }
      } else {
        parts.add('Defending \u2013 take 3 tricks to euchre for 2 points');
        if (us + 2 >= 10) {
          parts.add('A euchre wins us the game!');
        }
        if (them + 2 >= 10) {
          parts.add('Don\'t let them march \u2013 that ends it');
        }
      }
    }

    // Play-phase tracking
    if (round.phase == GamePhase.playing && round.trumpSuit != null) {
      _addPlayContext(parts, round);
    }

    return parts.join('\n');
  }

  void _addPlayContext(List<String> parts, EuchreRoundState round) {
    final trumpSuit = round.trumpSuit!;
    final allPlayed = _allPlayedCards(round);

    // Trump tracking
    final trumpPlayed = allPlayed
        .where((c) => CardRanking.isTrump(c, trumpSuit))
        .toList();
    final rightOut =
        !trumpPlayed.any((c) => CardRanking.isRightBower(c, trumpSuit));
    final leftOut =
        !trumpPlayed.any((c) => CardRanking.isLeftBower(c, trumpSuit));
    final aceOfTrumpOut = !trumpPlayed.any((c) =>
        c.value is AceSuitedCardValue &&
        CardRanking.effectiveSuit(c, trumpSuit) == trumpSuit &&
        !CardRanking.isLeftBower(c, trumpSuit));

    final trumpLine = StringBuffer('Trump: ${trumpPlayed.length}/6 played');
    final missing = <String>[];
    if (rightOut) missing.add('R');
    if (leftOut) missing.add('L');
    if (aceOfTrumpOut) missing.add('A');
    if (missing.isNotEmpty) {
      trumpLine.write(' \u2013 ${missing.join(',')} still out');
    }
    if (trumpPlayed.length >= 4) {
      trumpLine.write(' \u2013 trump nearly exhausted, off-suit aces are gold');
    }
    parts.add(trumpLine.toString());

    // Trick progress
    final ourTricks = round.tricksWon[Team.playerTeam] ?? 0;
    final theirTricks = round.tricksWon[Team.opponentTeam] ?? 0;
    final completed = round.completedTricks.length;
    final remaining = 5 - completed;

    parts.add(
        'Tricks: Us $ourTricks \u2013 Them $theirTricks ($remaining remaining)');

    if (round.caller?.team == Team.playerTeam) {
      if (ourTricks < 3) {
        final need = 3 - ourTricks;
        parts.add(
            'Need $need more trick${need > 1 ? "s" : ""} to score (all $remaining for march)');
      } else if (ourTricks == 3 || ourTricks == 4) {
        parts.add(
            'Point secured! Win all remaining for march (+2 pts instead of +1)');
      }
    } else if (round.caller != null) {
      if (ourTricks < 3) {
        final need = 3 - ourTricks;
        parts.add(
            'Need $need more trick${need > 1 ? "s" : ""} to euchre them (+2 pts)');
      } else {
        parts.add('Euchre locked in! +2 points incoming');
      }
    }

    // Void detection
    final voids = _detectVoids(round);
    for (final entry in voids.entries) {
      if (entry.value.isNotEmpty && entry.key != PlayerPosition.south) {
        final suitNames = entry.value.map(_suitSymbol).join(', ');
        parts.add('${entry.key.displayName} void in $suitNames');
      }
    }
  }

  // ─── Bid Round 1 ─────────────────────────────────────────

  CoachAdvice _adviseBidRound1(
      EuchreRoundState round, Map<Team, int> scores) {
    final hand = round.handFor(PlayerPosition.south);
    final trumpSuit = round.turnedCard.suit;
    final power = _trumpPower(hand, trumpSuit);
    final trumpCount =
        hand.where((c) => CardRanking.isTrump(c, trumpSuit)).length;
    final hasRight =
        hand.any((c) => CardRanking.isRightBower(c, trumpSuit));
    final hasLeft =
        hand.any((c) => CardRanking.isLeftBower(c, trumpSuit));
    final offAces = hand
        .where((c) =>
            c.value is AceSuitedCardValue &&
            !CardRanking.isTrump(c, trumpSuit))
        .length;

    final isDealer = round.dealer == PlayerPosition.south;
    final partnerIsDealer = round.dealer == PlayerPosition.north;

    // Suit distribution for void analysis
    final suitCounts = <CardSuit, int>{};
    for (final suit in CardSuit.values) {
      suitCounts[suit] =
          hand.where((c) => CardRanking.effectiveSuit(c, trumpSuit) == suit).length;
    }
    final voids = suitCounts.entries
        .where((e) => e.key != trumpSuit && e.value == 0)
        .map((e) => e.key)
        .toList();

    // Effective power with dealer pickup
    int effectivePower = power;
    if (isDealer) {
      final withTurned = [...hand, round.turnedCard];
      effectivePower = _trumpPower(withTurned, trumpSuit);
    } else if (partnerIsDealer) {
      effectivePower = power + 1;
    }

    final us = scores[Team.playerTeam] ?? 0;
    final them = scores[Team.opponentTeam] ?? 0;
    final scorePressure = (them - us).clamp(-3, 3);
    final threshold = 5 - scorePressure;

    final reasons = <String>[];

    // Hand analysis header
    reasons.add('${_suitName(trumpSuit)} trump analysis:');

    // Bower status
    if (hasRight && hasLeft) {
      reasons.add(
          'Both bowers (J${_suitChar(trumpSuit)} + J${_suitChar(_leftBowerSuit(trumpSuit))}) \u2013 dominant trump control, near-guaranteed 2 tricks');
    } else if (hasRight) {
      reasons.add(
          'Right bower J${_suitChar(trumpSuit)} (highest card in game) \u2013 guaranteed trick');
    } else if (hasLeft) {
      reasons.add(
          'Left bower J${_suitChar(_leftBowerSuit(trumpSuit))} (2nd strongest) \u2013 strong but beatable by right');
    } else {
      reasons.add('No bowers \u2013 vulnerable to opponents\' high trump');
    }

    // Trump depth
    if (trumpCount >= 4) {
      reasons.add(
          '$trumpCount trump cards \u2013 exceptional depth, can outlast any opposition');
    } else if (trumpCount == 3) {
      reasons.add(
          '3 trump \u2013 solid foundation, should control the trump suit');
    } else if (trumpCount == 2) {
      reasons.add(
          '2 trump \u2013 adequate but thin; need off-suit support');
    } else if (trumpCount == 1) {
      reasons.add(
          'Only 1 trump \u2013 very risky call, opponents likely hold more');
    } else {
      reasons.add('No trump in hand \u2013 cannot control the trump suit');
    }

    // Off-suit aces
    if (offAces >= 2) {
      reasons.add(
          '$offAces off-suit aces \u2013 likely side tricks when led');
    } else if (offAces == 1) {
      reasons.add('1 off-suit ace \u2013 one guaranteed side trick if led early');
    }

    // Void analysis
    if (voids.length >= 2) {
      final voidNames = voids.map(_suitName).join(' and ');
      reasons.add(
          'Void in $voidNames \u2013 excellent trumping opportunities in two suits');
    } else if (voids.length == 1) {
      reasons.add(
          'Void in ${_suitName(voids.first)} \u2013 can trump when that suit is led');
    }

    // Position analysis
    if (isDealer) {
      reasons.add(
          'As dealer, you\'ll pick up ${_cardName(round.turnedCard)} and discard your weakest \u2013 effectively ${trumpCount + 1} trump');
    } else if (partnerIsDealer) {
      reasons.add(
          'Partner (dealer) picks up ${_cardName(round.turnedCard)} \u2013 combined team trump strength increases');
    } else if (round.dealer.team == Team.opponentTeam) {
      reasons.add(
          'Ordering up gives ${round.dealer.displayName} (opponent) an extra trump \u2013 need a stronger hand to overcome this');
    }

    // What passed players tell us
    if (round.passedPlayers.isNotEmpty) {
      final passedNames =
          round.passedPlayers.map((p) => p.displayName).join(', ');
      reasons.add(
          '$passedNames passed \u2013 unlikely to hold strong ${_suitName(trumpSuit)} cards');
    }

    // Score-specific pressure
    if (us >= 9) {
      reasons.add(
          'At 9 points \u2013 any call that takes 3 tricks wins the game!');
    } else if (them >= 9) {
      reasons.add(
          'Opponents at 9 \u2013 call with anything reasonable or risk them winning');
    } else if (them > us + 2) {
      reasons.add(
          'Trailing by ${them - us} \u2013 bidding threshold lowered, lean toward calling');
    } else if (us > them + 2) {
      reasons.add(
          'Leading by ${us - them} \u2013 no need to force marginal calls');
    }

    // Risk/reward math
    if (them + 2 >= 10) {
      reasons.add(
          '\u26A0 Risk: getting euchred gives opponents the win (${them + 2} pts)');
    } else if (them + 2 >= 8) {
      reasons.add(
          'Risk: euchre puts opponents at ${them + 2} \u2013 dangerously close');
    }

    final shouldOrder =
        effectivePower >= (isDealer || partnerIsDealer ? threshold - 1 : threshold);

    if (shouldOrder) {
      // Go alone assessment
      final goAlone = hasRight && hasLeft && trumpCount >= 3 && offAces >= 1;
      if (goAlone && us < 9) {
        reasons.add(
            'Both bowers + deep trump + side ace = strong loner for 4 points');
        return CoachAdvice(
          recommendation: 'Order up & go alone',
          reasoning: reasons.join('. ') + '.',
        );
      }

      reasons.add(
          'Hand power $effectivePower (threshold $threshold) \u2013 favorable odds for 3+ tricks');
      return CoachAdvice(
        recommendation: 'Order up',
        reasoning: reasons.join('. ') + '.',
      );
    } else {
      reasons.add(
          'Hand power $effectivePower (threshold $threshold) \u2013 euchre risk outweighs reward');
      reasons.add(
          'Wait for a better opportunity in round 2 or on defense');
      return CoachAdvice(
        recommendation: 'Pass',
        reasoning: reasons.join('. ') + '.',
      );
    }
  }

  // ─── Bid Round 2 ─────────────────────────────────────────

  CoachAdvice _adviseBidRound2(
      EuchreRoundState round, Map<Team, int> scores) {
    final hand = round.handFor(PlayerPosition.south);
    final turnedSuit = round.turnedCard.suit;
    final isDealer = round.dealer == PlayerPosition.south;
    final us = scores[Team.playerTeam] ?? 0;
    final them = scores[Team.opponentTeam] ?? 0;

    CardSuit? bestSuit;
    int bestPower = 0;
    final suitAnalysis = <String>[];

    for (final suit in CardSuit.values) {
      if (suit == turnedSuit) continue;
      final power = _trumpPower(hand, suit);
      final count =
          hand.where((c) => CardRanking.isTrump(c, suit)).length;
      final hasRight =
          hand.any((c) => CardRanking.isRightBower(c, suit));
      final hasLeft =
          hand.any((c) => CardRanking.isLeftBower(c, suit));
      final bowerStr = hasRight && hasLeft
          ? ' (both bowers)'
          : hasRight
              ? ' (right bower)'
              : hasLeft
                  ? ' (left bower)'
                  : '';
      suitAnalysis
          .add('${_suitSymbol(suit)}: $count cards, power $power$bowerStr');
      if (power > bestPower) {
        bestPower = power;
        bestSuit = suit;
      }
    }

    final reasons = <String>[];
    reasons.add(
        '${_suitName(turnedSuit)} turned down \u2013 everyone passed, likely weak in that suit');
    reasons.add('Suit comparison:');
    reasons.addAll(suitAnalysis);

    // Void analysis for best suit
    if (bestSuit != null) {
      final voids = CardSuit.values
          .where((s) =>
              s != bestSuit &&
              !hand.any(
                  (c) => CardRanking.effectiveSuit(c, bestSuit!) == s))
          .toList();
      if (voids.isNotEmpty) {
        reasons.add(
            'With ${_suitName(bestSuit)} as trump, void in ${voids.map(_suitName).join(" and ")} for trumping');
      }
    }

    if (bestPower >= 4 || isDealer) {
      final suit =
          bestSuit ?? CardSuit.values.firstWhere((s) => s != turnedSuit);
      if (isDealer && bestPower < 4) {
        reasons.add(
            'Stick the dealer \u2013 must pick. ${_suitName(suit)} is your best option even though it\'s marginal');
        reasons.add(
            'Tip: opponents passed too, so ${_suitName(turnedSuit)} cards may be buried in the kitty');
      } else {
        final hasRight =
            hand.any((c) => CardRanking.isRightBower(c, suit));
        final hasLeft =
            hand.any((c) => CardRanking.isLeftBower(c, suit));
        if (hasRight || hasLeft) {
          reasons.add(
              '${_suitName(suit)} with bower support is strong enough to call');
        } else {
          reasons.add(
              '${_suitName(suit)} has enough depth (power $bestPower) to call');
        }
      }

      // Go alone check for round 2
      if (bestSuit != null) {
        final trumpCount = hand
            .where((c) => CardRanking.isTrump(c, bestSuit!))
            .length;
        final hasR =
            hand.any((c) => CardRanking.isRightBower(c, bestSuit!));
        final hasL =
            hand.any((c) => CardRanking.isLeftBower(c, bestSuit!));
        if (hasR && hasL && trumpCount >= 3 && us < 9) {
          reasons.add(
              'Both bowers + deep trump = loner candidate for 4 points');
          return CoachAdvice(
            recommendation: 'Pick ${_suitName(suit)} & go alone',
            reasoning: reasons.join('. ') + '.',
            suggestedSuit: suit,
          );
        }
      }

      // Score context
      if (us >= 9) {
        reasons.add('At game point \u2013 just need 3 tricks to win it all');
      }
      if (them >= 9) {
        reasons.add(
            'Must call \u2013 letting opponents bid cheaply risks losing the game');
      }

      return CoachAdvice(
        recommendation: 'Pick ${_suitName(suit)}',
        reasoning: reasons.join('. ') + '.',
        suggestedSuit: suit,
      );
    } else {
      reasons.add(
          'No suit strong enough to justify the euchre risk (best power: $bestPower)');
      if (them >= 8) {
        reasons.add(
            'But opponents are close to winning \u2013 consider calling anyway to stay in control');
      }
      return CoachAdvice(
        recommendation: 'Pass',
        reasoning: reasons.join('. ') + '.',
      );
    }
  }

  // ─── Discard ─────────────────────────────────────────────

  CoachAdvice _adviseDiscard(
      EuchreRoundState round, Map<Team, int> scores) {
    final hand = round.handFor(PlayerPosition.south);
    final trumpSuit = round.trumpSuit!;

    // Sort by strength, weakest first
    final sorted = List.of(hand)
      ..sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    final discard = sorted.first;

    final reasons = <String>[];

    // Analyze the full hand
    final trumpCards =
        hand.where((c) => CardRanking.isTrump(c, trumpSuit)).toList();
    final offSuit =
        hand.where((c) => !CardRanking.isTrump(c, trumpSuit)).toList();

    reasons.add(
        'Post-pickup hand: ${trumpCards.length} trump, ${offSuit.length} off-suit');

    if (CardRanking.isTrump(discard, trumpSuit)) {
      reasons.add(
          'Discard ${_cardName(discard)} (weakest trump) to keep your stronger trump cards');
    } else {
      reasons.add('Discard ${_cardName(discard)} (weakest off-suit card)');
      final discardSuit = CardRanking.effectiveSuit(discard, trumpSuit);
      final suitCount = hand
          .where(
              (c) => CardRanking.effectiveSuit(c, trumpSuit) == discardSuit)
          .length;

      if (suitCount == 1) {
        reasons.add(
            'Creates a void in ${_suitName(discardSuit)} \u2013 you can trump when ${_suitName(discardSuit)} is led');
      } else {
        // Check if there's a card that would create a void instead
        for (final suit in CardSuit.values) {
          if (suit == trumpSuit) continue;
          final inSuit = hand
              .where(
                  (c) => CardRanking.effectiveSuit(c, trumpSuit) == suit)
              .toList();
          if (inSuit.length == 1 && inSuit.first != discard) {
            final alt = inSuit.first;
            if (alt.value is! AceSuitedCardValue) {
              reasons.add(
                  'Alternative: discard ${_cardName(alt)} to create a ${_suitName(suit)} void (but it\'s slightly stronger)');
            }
          }
        }
      }
    }

    // Post-discard assessment
    final remaining = hand.where((c) => c != discard).toList();
    final postTrump = remaining
        .where((c) => CardRanking.isTrump(c, trumpSuit))
        .length;
    final postAces = remaining
        .where((c) =>
            c.value is AceSuitedCardValue &&
            !CardRanking.isTrump(c, trumpSuit))
        .length;
    reasons.add(
        'After discard: $postTrump trump + $postAces off-ace${postAces != 1 ? "s" : ""}');

    return CoachAdvice(
      recommendation: 'Discard ${_cardName(discard)}',
      reasoning: reasons.join('. ') + '.',
      suggestedCard: discard,
    );
  }

  // ─── Play Phase ──────────────────────────────────────────

  CoachAdvice _advisePlay(EuchreRoundState round, Map<Team, int> scores) {
    final hand = round.handFor(PlayerPosition.south);
    final trumpSuit = round.trumpSuit!;
    final trick = round.currentTrick;
    if (trick == null) {
      return CoachAdvice(recommendation: '', reasoning: '');
    }

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

    // Collect all played cards
    final playedCards = <SuitedCard>{};
    for (final t in round.completedTricks) {
      for (final play in t.plays) {
        playedCards.add(play.card);
      }
    }
    for (final play in trick.plays) {
      playedCards.add(play.card);
    }

    final voids = _detectVoids(round);

    if (trick.plays.isEmpty) {
      return _adviseLeading(
          legalPlays, trumpSuit, playedCards, round, voids, scores);
    }
    return _adviseFollowing(
        legalPlays, trumpSuit, trick, playedCards, round, voids, scores);
  }

  CoachAdvice _adviseLeading(
    List<SuitedCard> legalPlays,
    CardSuit trumpSuit,
    Set<SuitedCard> playedCards,
    EuchreRoundState round,
    Map<PlayerPosition, Set<CardSuit>> voids,
    Map<Team, int> scores,
  ) {
    final reasons = <String>[];
    final isCaller = round.caller == PlayerPosition.south ||
        round.caller == PlayerPosition.north;
    final trickNum = round.completedTricks.length + 1;
    final ourTricks = round.tricksWon[Team.playerTeam] ?? 0;
    final theirTricks = round.tricksWon[Team.opponentTeam] ?? 0;

    // Trump tracking
    final trumpPlayed = playedCards
        .where((c) => CardRanking.isTrump(c, trumpSuit))
        .length;
    final trumpRemaining = 6 - trumpPlayed;

    // My trump cards sorted strongest first
    final myTrump = legalPlays
        .where((c) => CardRanking.isTrump(c, trumpSuit))
        .toList()
      ..sort((a, b) => CardRanking.cardStrength(b, trumpSuit)
          .compareTo(CardRanking.cardStrength(a, trumpSuit)));

    // Endgame awareness
    if (trickNum == 5) {
      reasons.add('Final trick \u2013 play your strongest card to take it');
      final sorted = List.of(legalPlays)
        ..sort((a, b) => CardRanking.cardStrength(b, trumpSuit)
            .compareTo(CardRanking.cardStrength(a, trumpSuit)));
      return CoachAdvice(
        recommendation: 'Lead ${_cardName(sorted.first)}',
        reasoning: reasons.join('. ') + '.',
        suggestedCard: sorted.first,
      );
    }

    // Strategy: Lead boss trump to extract opponents' trump
    if (myTrump.isNotEmpty && isCaller) {
      final highest = myTrump.first;
      if (_isHighestRemaining(highest, trumpSuit, playedCards)) {
        reasons.add(
            '${_cardName(highest)} is the boss trump (highest remaining in game)');
        if (trumpRemaining > myTrump.length) {
          reasons.add(
              '${trumpRemaining - myTrump.length} opponent trump still out \u2013 flush them now');
        }
        reasons.add(
            'Pulling trump protects your off-suit winners for later tricks');
        return CoachAdvice(
          recommendation: 'Lead ${_cardName(highest)}',
          reasoning: reasons.join('. ') + '.',
          suggestedCard: highest,
        );
      }
    }

    // Strategy: Cash guaranteed off-suit winners (but check for opponent voids)
    for (final card in legalPlays) {
      if (CardRanking.isTrump(card, trumpSuit)) continue;
      if (!_isHighestRemainingInSuit(card, trumpSuit, playedCards)) continue;

      final suit = CardRanking.effectiveSuit(card, trumpSuit);

      // Check if any opponent is void in this suit
      final opponentVoid = voids.entries.any(
          (e) => e.key.team == Team.opponentTeam && e.value.contains(suit));

      if (opponentVoid && trumpRemaining > 0) {
        reasons.add(
            '${_cardName(card)} is boss in ${_suitName(suit)}, but an opponent is void and could trump it');
        continue; // Skip this, look for safer options
      }

      reasons.add(
          '${_cardName(card)} is the boss ${_suitName(suit)} (highest remaining)');
      reasons.add(
          'Cash it now \u2013 guaranteed trick before opponents develop voids');
      return CoachAdvice(
        recommendation: 'Lead ${_cardName(card)}',
        reasoning: reasons.join('. ') + '.',
        suggestedCard: card,
      );
    }

    // Strategy: Lead through opponents (when defending)
    if (!isCaller && round.caller != null) {
      reasons.add('Defending \u2013 lead through the caller to force tough choices');
    }

    // Strategy: Lead lowest off-suit to probe
    final offSuit = legalPlays
        .where((c) => !CardRanking.isTrump(c, trumpSuit))
        .toList();
    if (offSuit.isNotEmpty) {
      offSuit.sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));

      // Prefer leading from a suit where partner might be strong
      // or where opponents showed weakness
      final card = offSuit.first;
      final cardSuit = CardRanking.effectiveSuit(card, trumpSuit);
      reasons.add(
          'No guaranteed winners \u2013 lead ${_cardName(card)} (lowest ${_suitName(cardSuit)}) to probe');
      reasons.add('Save stronger cards for when you know more about opponents\' hands');

      // Extra context about what we know
      final knownVoids = voids.entries
          .where((e) => e.key.team == Team.opponentTeam && e.value.isNotEmpty)
          .toList();
      if (knownVoids.isNotEmpty) {
        for (final entry in knownVoids) {
          final avoidSuits = entry.value.map(_suitName).join(', ');
          reasons.add(
              'Avoid leading $avoidSuits \u2013 ${entry.key.displayName} will trump');
        }
      }

      return CoachAdvice(
        recommendation: 'Lead ${_cardName(card)}',
        reasoning: reasons.join('. ') + '.',
        suggestedCard: card,
      );
    }

    // Only trump left
    final sorted = List.of(legalPlays)
      ..sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    final card = sorted.first;
    reasons.add(
        'Only trump remaining \u2013 lead ${_cardName(card)} (lowest) to conserve high trump for later');
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
    Map<PlayerPosition, Set<CardSuit>> voids,
    Map<Team, int> scores,
  ) {
    final ledSuit =
        CardRanking.effectiveSuit(trick.plays.first.card, trumpSuit);
    final partnerWinning = _isPartnerWinning(trick, trumpSuit);
    final seatPosition = trick.plays.length; // 1=2nd, 2=3rd, 3=4th
    final isLastToPlay = seatPosition == trick.expectedPlays - 1;
    final trickNum = round.completedTricks.length + 1;
    final ourTricks = round.tricksWon[Team.playerTeam] ?? 0;
    final reasons = <String>[];

    // Seat position context
    final seatName = switch (seatPosition) {
      1 => '2nd seat',
      2 => '3rd seat',
      _ => '4th seat (last)',
    };
    reasons.add('Playing from $seatName on trick $trickNum');

    // Check if we can follow suit
    final canFollow =
        legalPlays.any((c) => CardRanking.effectiveSuit(c, trumpSuit) == ledSuit);
    final isTrumping = !canFollow && legalPlays.any((c) => CardRanking.isTrump(c, trumpSuit));

    if (partnerWinning) {
      // Partner winning - throw off strategically
      final sorted = List.of(legalPlays)
        ..sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
            .compareTo(CardRanking.cardStrength(b, trumpSuit)));
      final card = sorted.first;

      reasons.add('Partner is winning this trick \u2013 no need to play high');

      if (canFollow) {
        reasons.add(
            'Throw off ${_cardName(card)} (lowest in suit) to save your stronger cards');
      } else {
        // Discard from weakest off-suit
        reasons.add(
            'Can\'t follow suit \u2013 discard ${_cardName(card)} from your weakest holding');
        reasons.add(
            'Don\'t waste trump when partner has it won');
      }

      return CoachAdvice(
        recommendation: 'Play ${_cardName(card)}',
        reasoning: reasons.join('. ') + '.',
        suggestedCard: card,
      );
    }

    // Try to win
    final currentBest = _currentBestRank(trick, trumpSuit, ledSuit);
    final winners = legalPlays
        .where(
            (c) => CardRanking.trickRank(c, trumpSuit, ledSuit) > currentBest)
        .toList();

    if (winners.isNotEmpty) {
      winners.sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));

      final card = isLastToPlay ? winners.first : winners.last;

      if (isTrumping) {
        reasons.add(
            'Void in ${_suitName(ledSuit)} \u2013 can trump in');

        // Is this trick worth trumping?
        final weCalled = round.caller?.team == Team.playerTeam;
        if (weCalled && ourTricks < 3) {
          reasons.add(
              'We called and need tricks \u2013 trumping is worth it');
        } else if (!weCalled && ourTricks < 3) {
          reasons.add(
              'Defending \u2013 every trick toward euchre is valuable');
        }

        if (isLastToPlay) {
          reasons.add(
              'Last to play \u2013 trump with ${_cardName(card)} (cheapest winning trump)');
        } else {
          reasons.add(
              'Play ${_cardName(card)} (strong trump) \u2013 opponents still act after you');
        }
      } else if (isLastToPlay) {
        reasons.add(
            'Last to play \u2013 win cheaply with ${_cardName(card)}');
        reasons.add('No need to overplay from 4th seat');
      } else if (seatPosition == 1) {
        reasons.add(
            '2nd seat \u2013 play ${_cardName(card)} to force opponents to commit high cards or give up');
      } else {
        reasons.add(
            'Play ${_cardName(card)} \u2013 strongest option to hold the lead');
      }

      return CoachAdvice(
        recommendation: 'Play ${_cardName(card)}',
        reasoning: reasons.join('. ') + '.',
        suggestedCard: card,
      );
    }

    // Can't win - discard strategically
    final sorted = List.of(legalPlays)
      ..sort((a, b) => CardRanking.cardStrength(a, trumpSuit)
          .compareTo(CardRanking.cardStrength(b, trumpSuit)));
    final card = sorted.first;

    reasons.add('Cannot win this trick with any legal play');

    if (canFollow) {
      reasons.add(
          'Follow with ${_cardName(card)} (lowest in suit) \u2013 preserve your better cards');
    } else {
      reasons.add(
          'Discard ${_cardName(card)} \u2013 shed your weakest card');
      // Check if discarding creates a void
      final discardSuit = CardRanking.effectiveSuit(card, trumpSuit);
      final hand = round.handFor(PlayerPosition.south);
      final suitRemaining = hand
          .where(
              (c) => c != card && CardRanking.effectiveSuit(c, trumpSuit) == discardSuit)
          .length;
      if (suitRemaining == 0) {
        reasons.add(
            'This creates a void in ${_suitName(discardSuit)} for future trumping');
      }
    }

    return CoachAdvice(
      recommendation: 'Play ${_cardName(card)}',
      reasoning: reasons.join('. ') + '.',
      suggestedCard: card,
    );
  }

  // ─── Tracking Helpers ────────────────────────────────────

  Set<SuitedCard> _allPlayedCards(EuchreRoundState round) {
    final cards = <SuitedCard>{};
    for (final t in round.completedTricks) {
      for (final play in t.plays) {
        cards.add(play.card);
      }
    }
    if (round.currentTrick != null) {
      for (final play in round.currentTrick!.plays) {
        cards.add(play.card);
      }
    }
    return cards;
  }

  Map<PlayerPosition, Set<CardSuit>> _detectVoids(EuchreRoundState round) {
    final result = <PlayerPosition, Set<CardSuit>>{};
    final trumpSuit = round.trumpSuit;
    if (trumpSuit == null) return result;

    for (final trick in round.completedTricks) {
      if (trick.plays.isEmpty) continue;
      final trickLedSuit =
          CardRanking.effectiveSuit(trick.plays.first.card, trumpSuit);

      for (final play in trick.plays.skip(1)) {
        final playedSuit =
            CardRanking.effectiveSuit(play.card, trumpSuit);
        if (playedSuit != trickLedSuit) {
          result.putIfAbsent(play.player, () => {}).add(trickLedSuit);
        }
      }
    }

    // Also check current trick
    if (round.currentTrick != null &&
        round.currentTrick!.plays.length > 1) {
      final trickLedSuit = CardRanking.effectiveSuit(
          round.currentTrick!.plays.first.card, trumpSuit);
      for (final play in round.currentTrick!.plays.skip(1)) {
        final playedSuit =
            CardRanking.effectiveSuit(play.card, trumpSuit);
        if (playedSuit != trickLedSuit) {
          result.putIfAbsent(play.player, () => {}).add(trickLedSuit);
        }
      }
    }

    return result;
  }

  // ─── Card Analysis Helpers ───────────────────────────────

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
    final ledSuit =
        CardRanking.effectiveSuit(trick.plays.first.card, trumpSuit);
    int bestRank = 0;
    PlayerPosition? bestPlayer;
    for (final play in trick.plays) {
      final rank = CardRanking.trickRank(play.card, trumpSuit, ledSuit);
      if (rank > bestRank) {
        bestRank = rank;
        bestPlayer = play.player;
      }
    }
    return bestPlayer?.team == Team.playerTeam &&
        bestPlayer != PlayerPosition.south;
  }

  int _currentBestRank(
      Trick trick, CardSuit trumpSuit, CardSuit ledSuit) {
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
        if (CardRanking.cardStrength(other, trumpSuit) > strength) {
          return false;
        }
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
      if (CardRanking.cardStrength(other, trumpSuit) > strength) {
        return false;
      }
    }
    return true;
  }

  // ─── String Helpers ──────────────────────────────────────

  CardSuit _leftBowerSuit(CardSuit trumpSuit) => switch (trumpSuit) {
        CardSuit.hearts => CardSuit.diamonds,
        CardSuit.diamonds => CardSuit.hearts,
        CardSuit.clubs => CardSuit.spades,
        CardSuit.spades => CardSuit.clubs,
      };

  String _cardName(SuitedCard card) {
    final valueName = switch (card.value) {
      NumberSuitedCardValue(:final value) => '$value',
      JackSuitedCardValue() => 'J',
      QueenSuitedCardValue() => 'Q',
      KingSuitedCardValue() => 'K',
      AceSuitedCardValue() => 'A',
      _ => '?',
    };
    return '$valueName${_suitChar(card.suit)}';
  }

  String _suitChar(CardSuit suit) => switch (suit) {
        CardSuit.hearts => '\u2665',
        CardSuit.diamonds => '\u2666',
        CardSuit.clubs => '\u2663',
        CardSuit.spades => '\u2660',
      };

  String _suitSymbol(CardSuit suit) => switch (suit) {
        CardSuit.hearts => '\u2665 Hearts',
        CardSuit.diamonds => '\u2666 Diamonds',
        CardSuit.clubs => '\u2663 Clubs',
        CardSuit.spades => '\u2660 Spades',
      };

  String _suitName(CardSuit suit) => switch (suit) {
        CardSuit.hearts => 'Hearts',
        CardSuit.diamonds => 'Diamonds',
        CardSuit.clubs => 'Clubs',
        CardSuit.spades => 'Spades',
      };
}
