import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:euchre/model/bot_difficulty.dart';
import 'package:euchre/model/euchre_game_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/providers/save_state_notifier.dart';
import 'package:euchre/services/audio_service.dart';
import 'package:euchre/services/game_engine.dart';
import 'package:euchre/widgets/bid_overlay.dart';
import 'package:euchre/widgets/euchre_table.dart';
import 'package:euchre/widgets/game_over_overlay.dart';
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
                          engine: engine,
                          cardBack: cardBack,
                        )
                      : Center(
                          child: CircularProgressIndicator(
                              color: Colors.white54)),
                ),
                _BottomBar(
                  state: state,
                  onMenu: () => _showMenu(context, engine, ref),
                ),
              ],
            ),
          ),
          if (round != null && round.phase.isBidding)
            BidOverlay(round: round, engine: engine),
          if (round != null &&
              round.phase == GamePhase.dealerDiscard &&
              round.dealer == PlayerPosition.south)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Tap a card to discard',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white70),
            onPressed: onMenu,
          ),
          Spacer(),
          if (round != null) ...[
            Text('Round ${state.roundNumber}',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            SizedBox(width: 16),
            if (round.trumpSuit != null)
              Text(
                'Tricks: ${round.tricksWon[Team.playerTeam] ?? 0}',
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
    );
  }
}
