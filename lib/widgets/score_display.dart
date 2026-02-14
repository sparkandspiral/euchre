import 'package:flutter/material.dart';
import 'package:euchre/model/player.dart';

class ScoreDisplay extends StatelessWidget {
  final Map<Team, int> scores;

  const ScoreDisplay({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Us ',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            '${scores[Team.playerTeam] ?? 0}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '  :  ',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          Text(
            '${scores[Team.opponentTeam] ?? 0}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            ' Them',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
