import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:euchre/model/bot_difficulty.dart';
import 'package:euchre/model/euchre_game_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:card_game/card_game.dart';
import 'package:euchre/ai/coach_advisor.dart';
import 'package:euchre/logic/card_ranking.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/providers/save_state_notifier.dart';
import 'package:euchre/services/audio_service.dart';
import 'package:euchre/services/game_engine.dart';
import 'package:euchre/widgets/bid_overlay.dart';
import 'package:euchre/widgets/euchre_table.dart';
import 'package:euchre/widgets/game_over_overlay.dart';
import 'package:euchre/widgets/practice_feedback_banner.dart';
import 'package:euchre/widgets/round_result_banner.dart';
import 'package:euchre/widgets/score_display.dart';
import 'package:euchre/widgets/trump_indicator.dart';

class GamePage extends HookConsumerWidget {
  final BotDifficulty difficulty;

  const GamePage({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
    final gameState = useState<EuchreGameState>(
        EuchreGameState(difficulty: difficulty));
    final confetti = useMemoized(() => ConfettiController(
        duration: Duration(seconds: 3)));
    final audioService = ref.read(audioServiceProvider);

    final engine = useMemoized(() => GameEngine(
          difficulty: difficulty,
          onStateChanged: (state) => gameState.value = state,
          onCardPlayed: () => audioService.playPlace(),
          onWin: () {
            audioService.playWin();
            confetti.play();
            ref
                .read(saveStateNotifierProvider.notifier)
                .recordGameResult(won: true);
          },
        ));

    useEffect(() {
      engine.startGame();
      return engine.dispose;
    }, []);

    final state = gameState.value;
    final round = state.currentRound;
    final background = saveState?.background;
    final cardBack = saveState?.cardBack;
    final isPractice = saveState?.practiceMode == true;

    // Practice mode feedback state
    final practiceFeedback =
        useState<({bool isGood, String message})?>(null);
    final practiceFeedbackKey = useState(0);

    void showPracticeFeedback(bool isGood, String message) {
      practiceFeedback.value = (isGood: isGood, message: message);
      practiceFeedbackKey.value++;
    }

    void handleCardTap(SuitedCard card) {
      if (round == null) return;
      if (isPractice && round.phase == GamePhase.playing) {
        final advice =
            const CoachAdvisor().advise(round, state.scores);
        if (advice?.suggestedCard != null) {
          final suggested = advice!.suggestedCard!;
          final isMatch = card.suit == suggested.suit &&
              card.value.toString() == suggested.value.toString();
          showPracticeFeedback(
            isMatch,
            isMatch
                ? 'Good play! ${advice.reasoning}'
                : 'Consider: ${advice.recommendation}. ${advice.reasoning}',
          );
        }
      }
      if (round.phase == GamePhase.dealerDiscard) {
        engine.humanDiscard(card);
      } else if (round.phase == GamePhase.playing) {
        engine.humanPlayCard(card);
      }
    }

    void handleBidRound1(bool orderUp, {bool goAlone = false}) {
      if (isPractice && round != null) {
        final advice =
            const CoachAdvisor().advise(round, state.scores);
        if (advice != null) {
          final isMatch = advice.recommendation.toLowerCase().contains(
                orderUp ? 'order up' : 'pass',
              );
          showPracticeFeedback(
            isMatch,
            isMatch
                ? 'Good call! ${advice.reasoning}'
                : 'Consider: ${advice.recommendation}. ${advice.reasoning}',
          );
        }
      }
      engine.humanBidRound1(orderUp, goAlone: goAlone);
    }

    void handleBidRound2(CardSuit? suit) {
      if (isPractice && round != null) {
        final advice =
            const CoachAdvisor().advise(round, state.scores);
        if (advice != null) {
          final isMatch = suit == null
              ? advice.recommendation.toLowerCase().contains('pass')
              : advice.suggestedSuit == suit;
          showPracticeFeedback(
            isMatch,
            isMatch
                ? 'Good call! ${advice.reasoning}'
                : 'Consider: ${advice.recommendation}. ${advice.reasoning}',
          );
        }
      }
      engine.humanBidRound2(suit);
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (background != null)
            background.build()
          else
            ColoredBox(color: Color(0xFF1B5E20)),
          SafeArea(
            child: Column(
              children: [
                _TopBar(state: state),
                Expanded(
                  child: round != null
                      ? EuchreTable(
                          round: round,
                          onCardTap: handleCardTap,
                          cardBack: cardBack,
                          showDiscardHint: round.phase ==
                                  GamePhase.dealerDiscard &&
                              round.dealer == PlayerPosition.south,
                        )
                      : Center(
                          child: CircularProgressIndicator(
                              color: Colors.white54)),
                ),
                if (saveState?.coachMode == true && round != null)
                  _CoachBanner(round: round, scores: state.scores),
                _BottomBar(
                  state: state,
                  onMenu: () => _showMenu(context, engine, ref),
                ),
              ],
            ),
          ),
          if (round != null && round.phase.isBidding)
            BidOverlay(
              round: round,
              onBidRound1: handleBidRound1,
              onBidRound2: handleBidRound2,
              coachAdvice: saveState?.coachMode == true
                  ? const CoachAdvisor().advise(round, state.scores)
                  : null,
            ),
          if (round != null && round.phase == GamePhase.roundComplete)
            RoundResultBanner(
              result: round.result!,
              onContinue: () => engine.continueToNextRound(),
            ),
          if (state.isGameOver)
            GameOverOverlay(
              state: state,
              onPlayAgain: () => engine.startGame(),
              onExit: () => Navigator.of(context).pop(),
            ),
          if (practiceFeedback.value != null)
            PracticeFeedbackBanner(
              key: ValueKey(practiceFeedbackKey.value),
              isGoodPlay: practiceFeedback.value!.isGood,
              message: practiceFeedback.value!.message,
              onDismissed: () => practiceFeedback.value = null,
            ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 5,
              emissionFrequency: 0.05,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, GameEngine engine, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF0A2340),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.refresh, color: Colors.white70),
              title: Text('New Game', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                engine.startGame();
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.white70),
              title:
                  Text('Exit to Menu', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final EuchreGameState state;
  const _TopBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final round = state.currentRound;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ScoreDisplay(scores: state.scores),
          Spacer(),
          if (round?.trumpSuit != null) TrumpIndicator(suit: round!.trumpSuit!),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final EuchreGameState state;
  final VoidCallback onMenu;
  const _BottomBar({required this.state, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final round = state.currentRound;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status row: led suit, last trick winner, bid passes
          if (round != null) _StatusRow(round: round),
          // Main bottom row
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.menu, color: Colors.white70),
                onPressed: onMenu,
                visualDensity: VisualDensity.compact,
              ),
              Spacer(),
              if (round != null) ...[
                Text('Round ${state.roundNumber}',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                SizedBox(width: 16),
                if (round.trumpSuit != null)
                  Text(
                    'Tricks: ${round.tricksWon[Team.playerTeam] ?? 0} - ${round.tricksWon[Team.opponentTeam] ?? 0}',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                SizedBox(width: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('D: ${round.dealer.displayName}',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final EuchreRoundState round;
  const _StatusRow({required this.round});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    // During bidding: show who has passed
    if (round.phase.isBidding && round.passedPlayers.isNotEmpty) {
      final passedNames = round.passedPlayers
          .map((p) => p.displayName)
          .join(', ');
      items.add(_StatusChip(
        label: 'Passed: $passedNames',
        color: Colors.white54,
      ));
    }

    // During play: show led suit
    if (round.phase == GamePhase.playing && round.trumpSuit != null) {
      final trick = round.currentTrick;
      if (trick != null && trick.plays.isNotEmpty) {
        final ledSuit = CardRanking.effectiveSuit(
            trick.plays.first.card, round.trumpSuit!);
        items.add(_StatusChip(
          label: 'Led: ${_suitSymbol(ledSuit)}',
          color: _suitColor(ledSuit),
        ));
      }
    }

    // Show last trick winner
    if (round.completedTricks.isNotEmpty && round.trumpSuit != null) {
      final lastTrick = round.completedTricks.last;
      final winner = lastTrick.winner(round.trumpSuit!);
      if (winner != null) {
        items.add(_StatusChip(
          label: 'Last trick: ${winner.displayName}',
          color: winner.team == Team.playerTeam
              ? Colors.green.shade300
              : Colors.red.shade300,
        ));
      }
    }

    if (items.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: 8),
            items[i],
          ],
        ],
      ),
    );
  }

  String _suitSymbol(CardSuit suit) => switch (suit) {
        CardSuit.hearts => '\u2665 Hearts',
        CardSuit.diamonds => '\u2666 Diamonds',
        CardSuit.clubs => '\u2663 Clubs',
        CardSuit.spades => '\u2660 Spades',
      };

  Color _suitColor(CardSuit suit) => switch (suit) {
        CardSuit.hearts || CardSuit.diamonds => Colors.red.shade300,
        CardSuit.clubs || CardSuit.spades => Colors.white70,
      };
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

class _CoachBanner extends StatefulWidget {
  final EuchreRoundState round;
  final Map<Team, int> scores;
  const _CoachBanner({required this.round, required this.scores});

  @override
  State<_CoachBanner> createState() => _CoachBannerState();
}

class _CoachBannerState extends State<_CoachBanner> {
  static const _advisor = CoachAdvisor();
  bool _expanded = false;

  @override
  void didUpdateWidget(_CoachBanner old) {
    super.didUpdateWidget(old);
    // Collapse when the phase or current player changes
    if (old.round.phase != widget.round.phase ||
        old.round.currentPlayer != widget.round.currentPlayer ||
        old.round.currentTrick?.plays.length !=
            widget.round.currentTrick?.plays.length) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final advice = _advisor.advise(widget.round, widget.scores);
    if (advice == null || advice.recommendation.isEmpty) {
      return SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.amber, size: 16),
                SizedBox(width: 6),
                Text(
                  'Coach: ',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    advice.recommendation,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.amber.withValues(alpha: 0.6),
                  size: 18,
                ),
              ],
            ),
            if (_expanded) ...[
              SizedBox(height: 6),
              Text(
                advice.reasoning,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              if (advice.gameContext.isNotEmpty) ...[
                SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Game Situation',
                          style: TextStyle(
                            color: Colors.amber.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
                      SizedBox(height: 3),
                      Text(
                        advice.gameContext,
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
