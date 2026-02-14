import 'package:card_game/card_game.dart';
import 'package:euchre/model/bid.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';

class EuchreRoundState {
  final Map<PlayerPosition, List<SuitedCard>> hands;
  final List<SuitedCard> kitty;
  final SuitedCard turnedCard;
  final PlayerPosition dealer;
  final GamePhase phase;
  final PlayerPosition currentPlayer;

  // Bidding state
  final CardSuit? trumpSuit;
  final PlayerPosition? caller;
  final bool goAlone;
  final PlayerPosition? sittingOut;

  // Trick play state
  final Trick? currentTrick;
  final List<Trick> completedTricks;
  final Map<Team, int> tricksWon;

  // Round result
  final RoundResult? result;

  const EuchreRoundState({
    required this.hands,
    required this.kitty,
    required this.turnedCard,
    required this.dealer,
    required this.phase,
    required this.currentPlayer,
    this.trumpSuit,
    this.caller,
    this.goAlone = false,
    this.sittingOut,
    this.currentTrick,
    this.completedTricks = const [],
    this.tricksWon = const {Team.playerTeam: 0, Team.opponentTeam: 0},
    this.result,
  });

  int get trickNumber => completedTricks.length + 1;

  PlayerPosition get leftOfDealer => dealer.next;

  bool get isRoundOver => completedTricks.length >= 5 || result != null;

  List<SuitedCard> handFor(PlayerPosition position) => hands[position] ?? [];

  EuchreRoundState copyWith({
    Map<PlayerPosition, List<SuitedCard>>? hands,
    List<SuitedCard>? kitty,
    SuitedCard? turnedCard,
    PlayerPosition? dealer,
    GamePhase? phase,
    PlayerPosition? currentPlayer,
    CardSuit? trumpSuit,
    PlayerPosition? caller,
    bool? goAlone,
    PlayerPosition? sittingOut,
    Trick? currentTrick,
    List<Trick>? completedTricks,
    Map<Team, int>? tricksWon,
    RoundResult? result,
  }) {
    return EuchreRoundState(
      hands: hands ?? this.hands,
      kitty: kitty ?? this.kitty,
      turnedCard: turnedCard ?? this.turnedCard,
      dealer: dealer ?? this.dealer,
      phase: phase ?? this.phase,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      trumpSuit: trumpSuit ?? this.trumpSuit,
      caller: caller ?? this.caller,
      goAlone: goAlone ?? this.goAlone,
      sittingOut: sittingOut ?? this.sittingOut,
      currentTrick: currentTrick ?? this.currentTrick,
      completedTricks: completedTricks ?? this.completedTricks,
      tricksWon: tricksWon ?? this.tricksWon,
      result: result ?? this.result,
    );
  }
}
