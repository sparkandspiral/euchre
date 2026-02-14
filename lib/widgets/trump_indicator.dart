import 'package:card_game/card_game.dart';
import 'package:flutter/material.dart';

class TrumpIndicator extends StatelessWidget {
  final CardSuit suit;

  const TrumpIndicator({super.key, required this.suit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Trump ',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            _suitSymbol(suit),
            style: TextStyle(
              color: _suitColor(suit),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _suitSymbol(CardSuit suit) => switch (suit) {
        CardSuit.hearts => '\u2665',
        CardSuit.diamonds => '\u2666',
        CardSuit.clubs => '\u2663',
        CardSuit.spades => '\u2660',
      };

  Color _suitColor(CardSuit suit) => switch (suit) {
        CardSuit.hearts || CardSuit.diamonds => Colors.red.shade300,
        CardSuit.clubs || CardSuit.spades => Colors.white,
      };
}
