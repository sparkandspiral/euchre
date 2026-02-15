import 'package:card_game/card_game.dart';
import 'package:flutter/material.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';
import 'package:euchre/styles/playing_card_builder.dart';
import 'package:euchre/utils/card_description.dart';

class TrickHistorySheet extends StatelessWidget {
  final EuchreRoundState round;
  const TrickHistorySheet({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    final tricks = round.completedTricks;
    final trumpSuit = round.trumpSuit;

    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Trick History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              if (trumpSuit != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Trump: ${_suitSymbol(trumpSuit)}',
                    style: TextStyle(
                      color: _suitColor(trumpSuit),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          if (tricks.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No tricks played yet',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            )
          else
            ...tricks.asMap().entries.map((entry) {
              final i = entry.key;
              final trick = entry.value;
              return _TrickRow(
                trickNumber: i + 1,
                trick: trick,
                trumpSuit: trumpSuit!,
              );
            }),
          SizedBox(height: 8),
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

class _TrickRow extends StatelessWidget {
  final int trickNumber;
  final Trick trick;
  final CardSuit trumpSuit;

  const _TrickRow({
    required this.trickNumber,
    required this.trick,
    required this.trumpSuit,
  });

  @override
  Widget build(BuildContext context) {
    final winner = trick.winner(trumpSuit);
    final isOurWin = winner?.team == Team.playerTeam;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOurWin
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Trick $trickNumber',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              if (winner != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOurWin
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${winner.displayName} won',
                    style: TextStyle(
                      color: isOurWin
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final play in trick.plays)
                _PlayedCard(
                  play: play,
                  isWinner: play.player == winner,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayedCard extends StatelessWidget {
  final TrickPlay play;
  final bool isWinner;

  const _PlayedCard({required this.play, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: isWinner
                ? Border.all(color: Colors.amber, width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isWinner ? 4 : 6),
            child: PlayingCardBuilder(card: play.card),
          ),
        ),
        SizedBox(height: 4),
        Text(
          play.player.displayName,
          style: TextStyle(
            color: isWinner ? Colors.amber : Colors.white38,
            fontSize: 10,
            fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
