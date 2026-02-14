import 'package:card_game/card_game.dart';
import 'package:euchre/model/player.dart';

enum BidActionType {
  pass,
  orderUp,
  pickSuit,
}

class BidAction {
  final BidActionType type;
  final CardSuit? suit;
  final bool goAlone;

  const BidAction.pass()
      : type = BidActionType.pass,
        suit = null,
        goAlone = false;

  const BidAction.orderUp({this.goAlone = false})
      : type = BidActionType.orderUp,
        suit = null;

  const BidAction.pickSuit(CardSuit this.suit, {this.goAlone = false})
      : type = BidActionType.pickSuit;
}

class BidResult {
  final PlayerPosition caller;
  final CardSuit trumpSuit;
  final bool goAlone;

  const BidResult({
    required this.caller,
    required this.trumpSuit,
    this.goAlone = false,
  });
}

class RoundResult {
  final Team winningTeam;
  final Team callingTeam;
  final int tricksWonByCaller;
  final int tricksWonByDefender;
  final int pointsAwarded;
  final bool wasEuchred;
  final bool wasMarch;

  const RoundResult({
    required this.winningTeam,
    required this.callingTeam,
    required this.tricksWonByCaller,
    required this.tricksWonByDefender,
    required this.pointsAwarded,
    required this.wasEuchred,
    required this.wasMarch,
  });
}
