import 'package:card_game/card_game.dart';
import 'package:euchre/ai/easy_bot.dart';
import 'package:euchre/ai/hard_bot.dart';
import 'package:euchre/ai/medium_bot.dart';
import 'package:euchre/model/bot_difficulty.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';

abstract class BotPlayer {
  /// Decide whether to order up the turned card (round 1 bidding).
  bool shouldOrderUp({
    required List<SuitedCard> hand,
    required SuitedCard turnedCard,
    required PlayerPosition dealer,
    required PlayerPosition self,
    required Map<Team, int> scores,
  });

  /// Pick a trump suit during round 2 bidding, or null to pass.
  /// If mustPick is true, must return a suit (stick the dealer).
  CardSuit? pickTrumpSuit({
    required List<SuitedCard> hand,
    required CardSuit turnedSuit,
    required bool mustPick,
  });

  /// Whether to go alone after calling/ordering up trump.
  bool shouldGoAlone({
    required List<SuitedCard> hand,
    required CardSuit trumpSuit,
  });

  /// Choose which card to play from the hand.
  SuitedCard chooseCard({
    required List<SuitedCard> hand,
    required List<SuitedCard> legalPlays,
    required CardSuit trumpSuit,
    required Trick currentTrick,
    required PlayerPosition self,
    required List<Trick> completedTricks,
    required Map<Team, int> scores,
  });

  /// Choose which card to discard when dealer picks up trump card.
  SuitedCard chooseDiscard({
    required List<SuitedCard> hand,
    required CardSuit trumpSuit,
  });

  factory BotPlayer(BotDifficulty difficulty) => switch (difficulty) {
        BotDifficulty.easy => EasyBot(),
        BotDifficulty.medium => MediumBot(),
        BotDifficulty.hard => HardBot(),
      };
}
