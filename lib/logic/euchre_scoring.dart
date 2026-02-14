import 'package:euchre/model/bid.dart';
import 'package:euchre/model/player.dart';

class EuchreScoring {
  EuchreScoring._();

  static const int winningScore = 10;

  /// Calculate the result of a round.
  static RoundResult calculateRoundResult({
    required Team callingTeam,
    required Map<Team, int> tricksWon,
    required bool goAlone,
  }) {
    final callerTricks = tricksWon[callingTeam] ?? 0;
    final defenderTricks = tricksWon[callingTeam.opponent] ?? 0;

    if (callerTricks >= 5) {
      // March - all 5 tricks
      final points = goAlone ? 4 : 2;
      return RoundResult(
        winningTeam: callingTeam,
        callingTeam: callingTeam,
        tricksWonByCaller: callerTricks,
        tricksWonByDefender: defenderTricks,
        pointsAwarded: points,
        wasEuchred: false,
        wasMarch: true,
      );
    } else if (callerTricks >= 3) {
      // Normal win
      return RoundResult(
        winningTeam: callingTeam,
        callingTeam: callingTeam,
        tricksWonByCaller: callerTricks,
        tricksWonByDefender: defenderTricks,
        pointsAwarded: 1,
        wasEuchred: false,
        wasMarch: false,
      );
    } else {
      // Euchred - defenders win
      return RoundResult(
        winningTeam: callingTeam.opponent,
        callingTeam: callingTeam,
        tricksWonByCaller: callerTricks,
        tricksWonByDefender: defenderTricks,
        pointsAwarded: 2,
        wasEuchred: true,
        wasMarch: false,
      );
    }
  }
}
