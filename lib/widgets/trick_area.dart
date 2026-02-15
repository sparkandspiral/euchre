import 'package:flutter/material.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/styles/playing_card_builder.dart';

class TrickArea extends StatelessWidget {
  final EuchreRoundState round;
  final double cardWidth;
  final double cardHeight;

  const TrickArea({
    super.key,
    required this.round,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final trick = round.currentTrick;
    final smallWidth = cardWidth * 0.85;
    final smallHeight = cardHeight * 0.85;
    final offset = smallWidth * 0.55;
    final areaWidth = smallWidth * 2 + offset;
    final areaHeight = smallHeight * 2 + offset * 0.6;

    if (trick == null || trick.plays.isEmpty) {
      // Show turned card during bidding
      if (round.phase.isBidding) {
        return SizedBox(
          width: areaWidth,
          height: areaHeight,
          child: Center(
            child: _TurnedCardDisplay(
              round: round,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
            ),
          ),
        );
      }
      return SizedBox(width: areaWidth, height: areaHeight);
    }

    return SizedBox(
      width: areaWidth,
      height: areaHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final play in trick.plays)
            _positionedCard(play.player, play.card, smallWidth, smallHeight, offset),
        ],
      ),
    );
  }

  Widget _positionedCard(
    PlayerPosition position,
    dynamic card,
    double w,
    double h,
    double offset,
  ) {
    final centerX = (w * 2 + offset - w) / 2;
    final centerY = (h * 2 + offset * 0.6 - h) / 2;

    final (dx, dy) = switch (position) {
      PlayerPosition.south => (centerX, centerY + offset * 0.4),
      PlayerPosition.north => (centerX, centerY - offset * 0.4),
      PlayerPosition.west => (centerX - offset * 0.5, centerY),
      PlayerPosition.east => (centerX + offset * 0.5, centerY),
    };

    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      left: dx,
      top: dy,
      child: SizedBox(
        width: w,
        height: h,
        child: PlayingCardBuilder(card: card),
      ),
    );
  }
}

class _TurnedCardDisplay extends StatelessWidget {
  final EuchreRoundState round;
  final double cardWidth;
  final double cardHeight;

  const _TurnedCardDisplay({
    required this.round,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: PlayingCardBuilder(card: round.turnedCard),
        ),
        SizedBox(height: 8),
        Text(
          'Turned up',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
