import 'dart:async';
import 'package:card_game/card_game.dart';
import 'package:euchre/ai/bot_player.dart';
import 'package:euchre/logic/card_ranking.dart';
import 'package:euchre/logic/deck_builder.dart';
import 'package:euchre/logic/euchre_rules.dart';
import 'package:euchre/logic/euchre_scoring.dart';
import 'package:euchre/model/bot_difficulty.dart';
import 'package:euchre/model/euchre_game_state.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';
import 'package:euchre/utils/card_description.dart';

class GameEngine {
  final BotDifficulty difficulty;
  final void Function(EuchreGameState) onStateChanged;
  final void Function()? onCardPlayed;
  final void Function()? onWin;
  final void Function(String message)? onGameEvent;

  late final BotPlayer _bot;
  EuchreGameState _state;
  bool _disposed = false;
  Timer? _pendingTimer;
  double speedMultiplier = 1.0;

  GameEngine({
    required this.difficulty,
    required this.onStateChanged,
    this.onCardPlayed,
    this.onWin,
    this.onGameEvent,
  }) : _state = EuchreGameState(difficulty: difficulty) {
    _bot = BotPlayer(difficulty);
  }

  EuchreGameState get state => _state;

  void _updateState(EuchreGameState newState) {
    if (_disposed) return;
    _state = newState;
    onStateChanged(newState);
  }

  void dispose() {
    _disposed = true;
    _pendingTimer?.cancel();
  }

  /// Start a new game.
  void startGame() {
    _updateState(EuchreGameState(difficulty: difficulty));
    startNewRound();
  }

  /// Resume a saved game.
  void resumeGame(EuchreGameState savedState) {
    _updateState(savedState);
    _scheduleBotActionIfNeeded();
  }

  /// Deal cards and start bidding.
  void startNewRound() {
    final dealer = _state.currentDealer;
    final deal = DeckBuilder.deal(dealer);

    final round = EuchreRoundState(
      hands: deal.hands,
      kitty: deal.kitty,
      turnedCard: deal.turnedCard,
      dealer: dealer,
      phase: GamePhase.bidRound1,
      currentPlayer: dealer.next,
    );

    _updateState(_state.copyWith(currentRound: round));

    // If first bidder is a bot, start bot bidding
    _scheduleBotActionIfNeeded();
  }

  /// Human makes a bid action in round 1.
  void humanBidRound1(bool orderUp, {bool goAlone = false}) {
    final round = _state.currentRound;
    if (round == null || round.phase != GamePhase.bidRound1) return;
    if (round.currentPlayer != PlayerPosition.south) return;

    if (orderUp) {
      _handleOrderUp(PlayerPosition.south, goAlone: goAlone);
    } else {
      _handlePass();
    }
  }

  /// Human picks a trump suit in round 2.
  void humanBidRound2(CardSuit? suit, {bool goAlone = false}) {
    final round = _state.currentRound;
    if (round == null || round.phase != GamePhase.bidRound2) return;
    if (round.currentPlayer != PlayerPosition.south) return;

    if (suit != null) {
      _handlePickSuit(PlayerPosition.south, suit, goAlone: goAlone);
    } else {
      _handlePass();
    }
  }

  /// Human plays a card.
  void humanPlayCard(SuitedCard card) {
    final round = _state.currentRound;
    if (round == null || round.phase != GamePhase.playing) return;
    if (round.currentPlayer != PlayerPosition.south) return;
    if (round.trumpSuit == null) return;

    final hand = round.handFor(PlayerPosition.south);
    final ledSuit = round.currentTrick != null
        ? _effectiveLedSuit(round)
        : null;

    if (!EuchreRules.isLegalPlay(
      card: card,
      hand: hand,
      ledSuit: ledSuit,
      trumpSuit: round.trumpSuit!,
    )) {
      return;
    }

    _playCard(PlayerPosition.south, card);
  }

  /// Human discards a card (when dealer picks up trump).
  void humanDiscard(SuitedCard card) {
    final round = _state.currentRound;
    if (round == null || round.phase != GamePhase.dealerDiscard) return;
    if (round.dealer != PlayerPosition.south) return;

    _handleDiscard(PlayerPosition.south, card);
  }

  // --- Internal game flow ---

  void _handleOrderUp(PlayerPosition player, {bool goAlone = false}) {
    var round = _state.currentRound!;
    final dealer = round.dealer;
    final trumpSuit = round.turnedCard.suit;

    final suitName = describeSuitName(trumpSuit);
    final alone = goAlone ? ' and is going alone!' : '';
    onGameEvent?.call(
        '${player.displayName} ordered up $suitName$alone');

    // Dealer picks up the turned card
    final dealerHand = List<SuitedCard>.from(round.handFor(dealer));
    dealerHand.add(round.turnedCard);
    final newKitty = List<SuitedCard>.from(round.kitty)..removeAt(0);

    final newHands = Map<PlayerPosition, List<SuitedCard>>.from(round.hands);
    newHands[dealer] = dealerHand;

    PlayerPosition? sittingOut;
    if (goAlone) {
      sittingOut = player.partner;
    }

    round = round.copyWith(
      hands: newHands,
      kitty: newKitty,
      trumpSuit: trumpSuit,
      caller: player,
      goAlone: goAlone,
      sittingOut: sittingOut,
      phase: GamePhase.dealerDiscard,
      currentPlayer: dealer,
    );

    _updateState(_state.copyWith(currentRound: round));

    // If dealer is a bot, auto-discard
    if (!dealer.isHuman) {
      _scheduleAction(() => _botDiscard(dealer));
    }
  }

  void _handlePickSuit(PlayerPosition player, CardSuit suit,
      {bool goAlone = false}) {
    var round = _state.currentRound!;

    final suitName = describeSuitName(suit);
    final alone = goAlone ? ' and is going alone!' : '';
    onGameEvent?.call(
        '${player.displayName} called $suitName as trump$alone');

    PlayerPosition? sittingOut;
    if (goAlone) {
      sittingOut = player.partner;
    }

    round = round.copyWith(
      trumpSuit: suit,
      caller: player,
      goAlone: goAlone,
      sittingOut: sittingOut,
      phase: GamePhase.playing,
      currentPlayer: round.leftOfDealer,
    );

    // Start first trick
    final firstLeader = _nextActivePlayer(round.leftOfDealer, round);
    round = round.copyWith(
      currentPlayer: firstLeader,
      currentTrick: Trick(
        leader: firstLeader,
        expectedPlays: goAlone ? 3 : 4,
      ),
    );

    _updateState(_state.copyWith(currentRound: round));
    _scheduleBotActionIfNeeded();
  }

  void _handlePass() {
    var round = _state.currentRound!;
    final passer = round.currentPlayer;
    onGameEvent?.call('${passer.displayName} passed');
    final nextPlayer = _nextActivePlayer(round.currentPlayer.next, round);
    final newPassedPlayers = [...round.passedPlayers, passer];

    // Check if we've gone around the table
    if (round.phase == GamePhase.bidRound1) {
      if (nextPlayer == round.leftOfDealer) {
        // Everyone passed in round 1 - go to round 2
        round = round.copyWith(
          phase: GamePhase.bidRound2,
          currentPlayer: round.leftOfDealer,
          passedPlayers: newPassedPlayers,
        );
      } else {
        round = round.copyWith(
          currentPlayer: nextPlayer,
          passedPlayers: newPassedPlayers,
        );
      }
    } else if (round.phase == GamePhase.bidRound2) {
      // Check if dealer must pick (stick the dealer)
      if (nextPlayer == round.leftOfDealer) {
        // Dealer was the last to pass - shouldn't happen with stick the dealer
        // Force dealer to pick
        round = round.copyWith(
          currentPlayer: round.dealer,
          passedPlayers: newPassedPlayers,
        );
      } else {
        round = round.copyWith(
          currentPlayer: nextPlayer,
          passedPlayers: newPassedPlayers,
        );
      }
    }

    _updateState(_state.copyWith(currentRound: round));
    _scheduleBotActionIfNeeded();
  }

  void _handleDiscard(PlayerPosition player, SuitedCard card) {
    var round = _state.currentRound!;
    final hand = List<SuitedCard>.from(round.handFor(player));
    hand.remove(card);

    final newHands = Map<PlayerPosition, List<SuitedCard>>.from(round.hands);
    newHands[player] = hand;

    final firstLeader = _nextActivePlayer(round.leftOfDealer, round);

    round = round.copyWith(
      hands: newHands,
      phase: GamePhase.playing,
      currentPlayer: firstLeader,
      currentTrick: Trick(
        leader: firstLeader,
        expectedPlays: round.goAlone ? 3 : 4,
      ),
    );

    _updateState(_state.copyWith(currentRound: round));
    _scheduleBotActionIfNeeded();
  }

  void _playCard(PlayerPosition player, SuitedCard card) {
    var round = _state.currentRound!;
    final hand = List<SuitedCard>.from(round.handFor(player));
    hand.remove(card);

    final newHands = Map<PlayerPosition, List<SuitedCard>>.from(round.hands);
    newHands[player] = hand;

    var trick = round.currentTrick!.withPlay(TrickPlay(player: player, card: card));

    onCardPlayed?.call();

    if (trick.isComplete) {
      // Trick is complete - determine winner
      final winner = trick.winner(round.trumpSuit!)!;
      final tricksWon = Map<Team, int>.from(round.tricksWon);
      tricksWon[winner.team] = (tricksWon[winner.team] ?? 0) + 1;

      final completedTricks = [...round.completedTricks, trick];

      round = round.copyWith(
        hands: newHands,
        currentTrick: trick,
        completedTricks: completedTricks,
        tricksWon: tricksWon,
        phase: GamePhase.trickComplete,
        currentPlayer: winner,
      );

      _updateState(_state.copyWith(currentRound: round));

      // After a pause, check if round is over or start next trick
      _scheduleAction(() {
        if (completedTricks.length >= 5) {
          _handleRoundComplete();
        } else {
          _startNextTrick(winner);
        }
      }, delay: Duration(milliseconds: 1200));
    } else {
      // More plays needed in this trick
      final nextPlayer = _nextActivePlayer(player.next, round);
      round = round.copyWith(
        hands: newHands,
        currentTrick: trick,
        currentPlayer: nextPlayer,
      );
      _updateState(_state.copyWith(currentRound: round));
      _scheduleBotActionIfNeeded();
    }
  }

  void _startNextTrick(PlayerPosition leader) {
    var round = _state.currentRound!;
    final activeLeader = _nextActivePlayer(leader, round);

    round = round.copyWith(
      phase: GamePhase.playing,
      currentPlayer: activeLeader,
      currentTrick: Trick(
        leader: activeLeader,
        expectedPlays: round.goAlone ? 3 : 4,
      ),
    );

    _updateState(_state.copyWith(currentRound: round));
    _scheduleBotActionIfNeeded();
  }

  void _handleRoundComplete() {
    var round = _state.currentRound!;
    final callingTeam = round.caller!.team;

    final result = EuchreScoring.calculateRoundResult(
      callingTeam: callingTeam,
      tricksWon: round.tricksWon,
      goAlone: round.goAlone,
    );

    round = round.copyWith(
      phase: GamePhase.roundComplete,
      result: result,
    );

    // Update scores
    final scores = Map<Team, int>.from(_state.scores);
    scores[result.winningTeam] =
        (scores[result.winningTeam] ?? 0) + result.pointsAwarded;

    final roundHistory = [..._state.roundHistory, result];

    // Check for game over
    Team? winner;
    if (scores.values.any((s) => s >= EuchreScoring.winningScore)) {
      winner = scores[Team.playerTeam]! >= EuchreScoring.winningScore
          ? Team.playerTeam
          : Team.opponentTeam;
      round = round.copyWith(phase: GamePhase.gameOver);
      if (winner == Team.playerTeam) onWin?.call();
    }

    _updateState(_state.copyWith(
      currentRound: round,
      scores: scores,
      winner: winner,
      roundHistory: roundHistory,
    ));
  }

  /// Called by UI to advance to next round after viewing results.
  void continueToNextRound() {
    if (_state.isGameOver) return;

    _updateState(_state.copyWith(
      currentDealer: _state.currentDealer.next,
      roundNumber: _state.roundNumber + 1,
    ));

    startNewRound();
  }

  // --- Bot actions ---

  void _scheduleBotActionIfNeeded() {
    final round = _state.currentRound;
    if (round == null) return;
    if (round.currentPlayer.isHuman) return;
    if (round.phase == GamePhase.trickComplete ||
        round.phase == GamePhase.roundComplete ||
        round.phase == GamePhase.gameOver) {
      return;
    }

    _scheduleAction(() => _executeBotAction());
  }

  void _executeBotAction() {
    final round = _state.currentRound;
    if (round == null || _disposed) return;

    final player = round.currentPlayer;
    if (player.isHuman) return;

    switch (round.phase) {
      case GamePhase.bidRound1:
        _botBidRound1(player);
      case GamePhase.bidRound2:
        _botBidRound2(player);
      case GamePhase.dealerDiscard:
        _botDiscard(player);
      case GamePhase.playing:
        _botPlay(player);
      default:
        break;
    }
  }

  void _botBidRound1(PlayerPosition player) {
    final round = _state.currentRound!;
    final hand = round.handFor(player);

    final shouldOrder = _bot.shouldOrderUp(
      hand: hand,
      turnedCard: round.turnedCard,
      dealer: round.dealer,
      self: player,
      scores: _state.scores,
    );

    if (shouldOrder) {
      final goAlone = _bot.shouldGoAlone(
        hand: hand,
        trumpSuit: round.turnedCard.suit,
      );
      _handleOrderUp(player, goAlone: goAlone);
    } else {
      _handlePass();
    }
  }

  void _botBidRound2(PlayerPosition player) {
    final round = _state.currentRound!;
    final hand = round.handFor(player);
    final mustPick = player == round.dealer;

    final suit = _bot.pickTrumpSuit(
      hand: hand,
      turnedSuit: round.turnedCard.suit,
      mustPick: mustPick,
    );

    if (suit != null) {
      final goAlone = _bot.shouldGoAlone(hand: hand, trumpSuit: suit);
      _handlePickSuit(player, suit, goAlone: goAlone);
    } else {
      _handlePass();
    }
  }

  void _botDiscard(PlayerPosition player) {
    final round = _state.currentRound!;
    final hand = round.handFor(player);

    final discard = _bot.chooseDiscard(
      hand: hand,
      trumpSuit: round.trumpSuit!,
    );

    _handleDiscard(player, discard);
  }

  void _botPlay(PlayerPosition player) {
    final round = _state.currentRound!;
    final hand = round.handFor(player);
    final trumpSuit = round.trumpSuit!;

    final ledSuit = round.currentTrick != null && round.currentTrick!.plays.isNotEmpty
        ? CardRanking.effectiveSuit(round.currentTrick!.plays.first.card, trumpSuit)
        : null;

    final legal = EuchreRules.legalPlays(
      hand: hand,
      ledSuit: ledSuit,
      trumpSuit: trumpSuit,
    );

    final card = _bot.chooseCard(
      hand: hand,
      legalPlays: legal,
      trumpSuit: trumpSuit,
      currentTrick: round.currentTrick!,
      self: player,
      completedTricks: round.completedTricks,
      scores: _state.scores,
    );

    _playCard(player, card);
  }

  // --- Helpers ---

  PlayerPosition _nextActivePlayer(
      PlayerPosition from, EuchreRoundState round) {
    var pos = from;
    // Skip sitting-out player if going alone
    for (int i = 0; i < 4; i++) {
      if (pos != round.sittingOut) return pos;
      pos = pos.next;
    }
    return from;
  }

  CardSuit? _effectiveLedSuit(EuchreRoundState round) {
    final trick = round.currentTrick;
    if (trick == null || trick.plays.isEmpty) return null;
    return CardRanking.effectiveSuit(
        trick.plays.first.card, round.trumpSuit!);
  }

  void _scheduleAction(void Function() action, {Duration? delay}) {
    _pendingTimer?.cancel();
    final baseDelay = delay ?? difficulty.thinkDelay;
    final scaledMs = (baseDelay.inMilliseconds / speedMultiplier).round();
    final actualDelay = Duration(milliseconds: scaledMs.clamp(50, 10000));
    _pendingTimer = Timer(actualDelay, () {
      if (!_disposed) action();
    });
  }
}
