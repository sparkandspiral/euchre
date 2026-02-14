import 'package:card_game/card_game.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/logic/card_ranking.dart';

class TrickPlay {
  final PlayerPosition player;
  final SuitedCard card;

  const TrickPlay({required this.player, required this.card});
}

class Trick {
  final PlayerPosition leader;
  final List<TrickPlay> plays;
  final int expectedPlays;

  const Trick({
    required this.leader,
    this.plays = const [],
    this.expectedPlays = 4,
  });

  bool get isComplete => plays.length >= expectedPlays;

  CardSuit? get ledSuit =>
      plays.isNotEmpty ? plays.first.card.suit : null;

  Trick withPlay(TrickPlay play) => Trick(
        leader: leader,
        plays: [...plays, play],
        expectedPlays: expectedPlays,
      );

  PlayerPosition? winner(CardSuit trumpSuit) {
    if (plays.isEmpty) return null;
    return CardRanking.trickWinner(plays, trumpSuit);
  }
}
