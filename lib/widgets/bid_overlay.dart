import 'package:card_game/card_game.dart';
import 'package:flutter/material.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/services/game_engine.dart';
import 'package:euchre/styles/playing_card_builder.dart';

class BidOverlay extends StatelessWidget {
  final EuchreRoundState round;
  final GameEngine engine;

  const BidOverlay({
    super.key,
    required this.round,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    // Only show UI when it's the human's turn to bid
    if (round.currentPlayer != PlayerPosition.south) {
      return Positioned.fill(
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '${round.currentPlayer.displayName} is thinking...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(32),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF0A2340),
              borderRadius: BorderRadius.circular(20),
            ),
            child: round.phase == GamePhase.bidRound1
                ? _Round1Bid(round: round, engine: engine)
                : _Round2Bid(round: round, engine: engine),
          ),
        ),
      ),
    );
  }
}

class _Round1Bid extends StatelessWidget {
  final EuchreRoundState round;
  final GameEngine engine;

  const _Round1Bid({required this.round, required this.engine});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Trump Selection - Round 1',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16),
        // Turned card
        SizedBox(
          width: 80,
          height: 108,
          child: PlayingCardBuilder(card: round.turnedCard),
        ),
        SizedBox(height: 8),
        Text(
          '${_suitName(round.turnedCard.suit)} turned up',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        SizedBox(height: 8),
        Text(
          'Dealer: ${round.dealer.displayName}',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => engine.humanBidRound1(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Order Up'),
            ),
            SizedBox(width: 16),
            OutlinedButton(
              onPressed: () => engine.humanBidRound1(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white38),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Pass'),
            ),
          ],
        ),
        SizedBox(height: 12),
        TextButton(
          onPressed: () => engine.humanBidRound1(true, goAlone: true),
          child: Text(
            'Order Up & Go Alone',
            style: TextStyle(color: Colors.amber, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _Round2Bid extends StatelessWidget {
  final EuchreRoundState round;
  final GameEngine engine;

  const _Round2Bid({required this.round, required this.engine});

  @override
  Widget build(BuildContext context) {
    final turnedSuit = round.turnedCard.suit;
    final isDealer = round.dealer == PlayerPosition.south;
    final availableSuits =
        CardSuit.values.where((s) => s != turnedSuit).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Trump Selection - Round 2',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${_suitName(turnedSuit)} was passed',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        if (isDealer) ...[
          SizedBox(height: 4),
          Text(
            'You must pick (stick the dealer)',
            style: TextStyle(color: Colors.amber, fontSize: 12),
          ),
        ],
        SizedBox(height: 24),
        Text(
          'Choose Trump Suit:',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final suit in availableSuits)
              _SuitButton(
                suit: suit,
                onTap: () => engine.humanBidRound2(suit),
              ),
          ],
        ),
        if (!isDealer) ...[
          SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => engine.humanBidRound2(null),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white38),
            ),
            child: Text('Pass'),
          ),
        ],
      ],
    );
  }
}

class _SuitButton extends StatelessWidget {
  final CardSuit suit;
  final VoidCallback onTap;

  const _SuitButton({required this.suit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRed = suit == CardSuit.hearts || suit == CardSuit.diamonds;
    final symbol = switch (suit) {
      CardSuit.hearts => '\u2665',
      CardSuit.diamonds => '\u2666',
      CardSuit.clubs => '\u2663',
      CardSuit.spades => '\u2660',
    };

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        foregroundColor: isRed ? Colors.red.shade300 : Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white24),
        ),
      ),
      child: Text(
        '$symbol ${_suitName(suit)}',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

String _suitName(CardSuit suit) => switch (suit) {
      CardSuit.hearts => 'Hearts',
      CardSuit.diamonds => 'Diamonds',
      CardSuit.clubs => 'Clubs',
      CardSuit.spades => 'Spades',
    };
