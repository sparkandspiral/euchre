import 'package:flutter/material.dart';
import 'package:euchre/model/euchre_game_state.dart';
import 'package:euchre/model/player.dart';

class GameOverOverlay extends StatelessWidget {
  final EuchreGameState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const GameOverOverlay({
    super.key,
    required this.state,
    required this.onPlayAgain,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final won = state.winner == Team.playerTeam;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(32),
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Color(0xFF0A2340),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: won
                    ? Colors.amber.withValues(alpha: 0.6)
                    : Colors.red.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                  color: won ? Colors.amber : Colors.red.shade300,
                  size: 56,
                ),
                SizedBox(height: 16),
                Text(
                  won ? 'Victory!' : 'Defeat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Final Score',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScoreColumn(
                      label: 'Us',
                      score: state.scoreFor(Team.playerTeam),
                      color: Colors.white,
                    ),
                    SizedBox(width: 32),
                    Text(' : ',
                        style: TextStyle(color: Colors.white38, fontSize: 24)),
                    SizedBox(width: 32),
                    _ScoreColumn(
                      label: 'Them',
                      score: state.scoreFor(Team.opponentTeam),
                      color: Colors.white,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '${state.roundNumber} rounds played',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: onPlayAgain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      child: Text('Play Again'),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: onExit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white38),
                        padding:
                            EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      child: Text('Exit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String label;
  final int score;
  final Color color;

  const _ScoreColumn({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}
