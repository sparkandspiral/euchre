import 'package:euchre/model/bid.dart';
import 'package:euchre/model/bot_difficulty.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/player.dart';

class EuchreGameState {
  final Map<Team, int> scores;
  final PlayerPosition currentDealer;
  final int roundNumber;
  final EuchreRoundState? currentRound;
  final Team? winner;
  final BotDifficulty difficulty;
  final List<RoundResult> roundHistory;

  const EuchreGameState({
    this.scores = const {Team.playerTeam: 0, Team.opponentTeam: 0},
    this.currentDealer = PlayerPosition.south,
    this.roundNumber = 1,
    this.currentRound,
    this.winner,
    this.difficulty = BotDifficulty.medium,
    this.roundHistory = const [],
  });

  bool get isGameOver => winner != null;

  int scoreFor(Team team) => scores[team] ?? 0;

  EuchreGameState copyWith({
    Map<Team, int>? scores,
    PlayerPosition? currentDealer,
    int? roundNumber,
    EuchreRoundState? currentRound,
    Team? winner,
    BotDifficulty? difficulty,
    List<RoundResult>? roundHistory,
  }) {
    return EuchreGameState(
      scores: scores ?? this.scores,
      currentDealer: currentDealer ?? this.currentDealer,
      roundNumber: roundNumber ?? this.roundNumber,
      currentRound: currentRound ?? this.currentRound,
      winner: winner ?? this.winner,
      difficulty: difficulty ?? this.difficulty,
      roundHistory: roundHistory ?? this.roundHistory,
    );
  }
}
