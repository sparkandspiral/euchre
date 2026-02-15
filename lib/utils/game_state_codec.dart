import 'package:card_game/card_game.dart';
import 'package:euchre/model/bid.dart';
import 'package:euchre/model/bot_difficulty.dart';
import 'package:euchre/model/euchre_game_state.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';
import 'package:euchre/utils/suited_card_codec.dart';

Map<String, dynamic> encodeGameState(EuchreGameState state) => {
      'scores': {
        'playerTeam': state.scores[Team.playerTeam] ?? 0,
        'opponentTeam': state.scores[Team.opponentTeam] ?? 0,
      },
      'currentDealer': state.currentDealer.index,
      'roundNumber': state.roundNumber,
      'difficulty': state.difficulty.index,
      'roundHistory': state.roundHistory.map(_encodeRoundResult).toList(),
      if (state.currentRound != null)
        'currentRound': _encodeRoundState(state.currentRound!),
    };

EuchreGameState decodeGameState(Map<String, dynamic> json) {
  final scores = json['scores'] as Map<String, dynamic>;
  return EuchreGameState(
    scores: {
      Team.playerTeam: scores['playerTeam'] as int? ?? 0,
      Team.opponentTeam: scores['opponentTeam'] as int? ?? 0,
    },
    currentDealer: PlayerPosition.values[json['currentDealer'] as int],
    roundNumber: json['roundNumber'] as int,
    difficulty: BotDifficulty.values[json['difficulty'] as int],
    roundHistory: (json['roundHistory'] as List<dynamic>?)
            ?.map((e) => _decodeRoundResult(e as Map<String, dynamic>))
            .toList() ??
        [],
    currentRound: json['currentRound'] != null
        ? _decodeRoundState(json['currentRound'] as Map<String, dynamic>)
        : null,
  );
}

Map<String, dynamic> _encodeRoundState(EuchreRoundState round) => {
      'hands': round.hands.map(
        (pos, cards) =>
            MapEntry(pos.index.toString(), cards.map(encodeSuitedCard).toList()),
      ),
      'kitty': round.kitty.map(encodeSuitedCard).toList(),
      'turnedCard': encodeSuitedCard(round.turnedCard),
      'dealer': round.dealer.index,
      'phase': round.phase.index,
      'currentPlayer': round.currentPlayer.index,
      if (round.trumpSuit != null) 'trumpSuit': round.trumpSuit!.index,
      if (round.caller != null) 'caller': round.caller!.index,
      'goAlone': round.goAlone,
      if (round.sittingOut != null) 'sittingOut': round.sittingOut!.index,
      'passedPlayers': round.passedPlayers.map((p) => p.index).toList(),
      if (round.currentTrick != null)
        'currentTrick': _encodeTrick(round.currentTrick!),
      'completedTricks': round.completedTricks.map(_encodeTrick).toList(),
      'tricksWon': {
        'playerTeam': round.tricksWon[Team.playerTeam] ?? 0,
        'opponentTeam': round.tricksWon[Team.opponentTeam] ?? 0,
      },
      if (round.result != null) 'result': _encodeRoundResult(round.result!),
    };

EuchreRoundState _decodeRoundState(Map<String, dynamic> json) {
  final handsJson = json['hands'] as Map<String, dynamic>;
  final hands = <PlayerPosition, List<SuitedCard>>{};
  for (final entry in handsJson.entries) {
    final pos = PlayerPosition.values[int.parse(entry.key)];
    hands[pos] = (entry.value as List<dynamic>)
        .map((c) => decodeSuitedCard(c as Map<String, dynamic>))
        .toList();
  }

  final tricksWon = json['tricksWon'] as Map<String, dynamic>;

  return EuchreRoundState(
    hands: hands,
    kitty: (json['kitty'] as List<dynamic>)
        .map((c) => decodeSuitedCard(c as Map<String, dynamic>))
        .toList(),
    turnedCard:
        decodeSuitedCard(json['turnedCard'] as Map<String, dynamic>),
    dealer: PlayerPosition.values[json['dealer'] as int],
    phase: GamePhase.values[json['phase'] as int],
    currentPlayer: PlayerPosition.values[json['currentPlayer'] as int],
    trumpSuit: json['trumpSuit'] != null
        ? CardSuit.values[json['trumpSuit'] as int]
        : null,
    caller: json['caller'] != null
        ? PlayerPosition.values[json['caller'] as int]
        : null,
    goAlone: json['goAlone'] as bool? ?? false,
    sittingOut: json['sittingOut'] != null
        ? PlayerPosition.values[json['sittingOut'] as int]
        : null,
    passedPlayers: (json['passedPlayers'] as List<dynamic>?)
            ?.map((i) => PlayerPosition.values[i as int])
            .toList() ??
        [],
    currentTrick: json['currentTrick'] != null
        ? _decodeTrick(json['currentTrick'] as Map<String, dynamic>)
        : null,
    completedTricks: (json['completedTricks'] as List<dynamic>?)
            ?.map((t) => _decodeTrick(t as Map<String, dynamic>))
            .toList() ??
        [],
    tricksWon: {
      Team.playerTeam: tricksWon['playerTeam'] as int? ?? 0,
      Team.opponentTeam: tricksWon['opponentTeam'] as int? ?? 0,
    },
    result: json['result'] != null
        ? _decodeRoundResult(json['result'] as Map<String, dynamic>)
        : null,
  );
}

Map<String, dynamic> _encodeTrick(Trick trick) => {
      'leader': trick.leader.index,
      'expectedPlays': trick.expectedPlays,
      'plays': trick.plays
          .map((p) => {
                'player': p.player.index,
                'card': encodeSuitedCard(p.card),
              })
          .toList(),
    };

Trick _decodeTrick(Map<String, dynamic> json) => Trick(
      leader: PlayerPosition.values[json['leader'] as int],
      expectedPlays: json['expectedPlays'] as int? ?? 4,
      plays: (json['plays'] as List<dynamic>?)
              ?.map((p) {
                final play = p as Map<String, dynamic>;
                return TrickPlay(
                  player: PlayerPosition.values[play['player'] as int],
                  card:
                      decodeSuitedCard(play['card'] as Map<String, dynamic>),
                );
              })
              .toList() ??
          [],
    );

Map<String, dynamic> _encodeRoundResult(RoundResult result) => {
      'winningTeam': result.winningTeam.index,
      'callingTeam': result.callingTeam.index,
      'tricksWonByCaller': result.tricksWonByCaller,
      'tricksWonByDefender': result.tricksWonByDefender,
      'pointsAwarded': result.pointsAwarded,
      'wasEuchred': result.wasEuchred,
      'wasMarch': result.wasMarch,
    };

RoundResult _decodeRoundResult(Map<String, dynamic> json) => RoundResult(
      winningTeam: Team.values[json['winningTeam'] as int],
      callingTeam: Team.values[json['callingTeam'] as int],
      tricksWonByCaller: json['tricksWonByCaller'] as int,
      tricksWonByDefender: json['tricksWonByDefender'] as int,
      pointsAwarded: json['pointsAwarded'] as int,
      wasEuchred: json['wasEuchred'] as bool,
      wasMarch: json['wasMarch'] as bool,
    );
