import 'package:flutter/material.dart';
import 'package:euchre/model/bid.dart';
import 'package:euchre/model/player.dart';

class RoundResultBanner extends StatelessWidget {
  final RoundResult result;
  final VoidCallback onContinue;

  const RoundResultBanner({
    super.key,
    required this.result,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayerWin = result.winningTeam == Team.playerTeam;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(32),
            padding: EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Color(0xFF0A2340),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPlayerWin
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.red.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlayerWin ? Icons.thumb_up : Icons.thumb_down,
                  color: isPlayerWin ? Colors.green : Colors.red.shade300,
                  size: 36,
                ),
                SizedBox(height: 16),
                Text(
                  _title(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _subtitle(),
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Tricks: ${result.tricksWonByCaller} - ${result.tricksWonByDefender}',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '+${result.pointsAwarded} point${result.pointsAwarded != 1 ? 's' : ''} for ${result.winningTeam.displayName}',
                  style: TextStyle(
                    color: isPlayerWin ? Colors.green : Colors.red.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding:
                        EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title() {
    if (result.wasEuchred) return 'Euchred!';
    if (result.wasMarch) return 'March!';
    return result.winningTeam == Team.playerTeam ? 'We Win!' : 'They Win';
  }

  String _subtitle() {
    final callerName = result.callingTeam == Team.playerTeam ? 'We' : 'They';
    if (result.wasEuchred) {
      return '$callerName called trump but failed to take 3 tricks';
    }
    if (result.wasMarch) {
      return '$callerName swept all 5 tricks!';
    }
    return '$callerName called trump and took ${result.tricksWonByCaller} tricks';
  }
}
