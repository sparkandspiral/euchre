import 'package:card_game/card_game.dart';
import 'package:flutter/material.dart';
import 'package:euchre/logic/card_ranking.dart';
import 'package:euchre/logic/euchre_rules.dart';
import 'package:euchre/model/card_back.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/styles/playing_card_builder.dart';
import 'package:euchre/widgets/trick_area.dart';

class EuchreTable extends StatelessWidget {
  final EuchreRoundState round;
  final void Function(SuitedCard)? onCardTap;
  final CardBack? cardBack;
  final bool showDiscardHint;

  const EuchreTable({
    super.key,
    required this.round,
    this.onCardTap,
    this.cardBack,
    this.showDiscardHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > constraints.maxHeight;
      final minDim = isWide ? constraints.maxHeight : constraints.maxWidth;
      final sizeMultiplier = (minDim / 320).clamp(0.5, 1.2);
      final cardWidth = 69 * sizeMultiplier;
      final cardHeight = 93 * sizeMultiplier;
      final spacing = 4.0 * sizeMultiplier;

      final isHumanTurn = round.currentPlayer == PlayerPosition.south &&
          (round.phase == GamePhase.playing ||
           round.phase == GamePhase.dealerDiscard);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            // North hand (partner, face down)
            SizedBox(height: spacing),
            _LabeledHand(
              label: PlayerPosition.north.displayName,
              isCurrentPlayer: round.currentPlayer == PlayerPosition.north,
              hasPassed: _showPassed(PlayerPosition.north),
              child: _BotHand(
                cards: round.handFor(PlayerPosition.north),
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                cardBack: cardBack ?? CardBack.redStripes,
                label: 'Partner',
                isCurrentPlayer: round.currentPlayer == PlayerPosition.north,
              ),
            ),
            SizedBox(height: spacing),

            // Middle row: West + Trick Area + East
            Expanded(
              child: Row(
                children: [
                  // West hand (vertical, face down)
                  _LabeledVerticalHand(
                    label: PlayerPosition.west.displayName,
                    isCurrentPlayer: round.currentPlayer == PlayerPosition.west,
                    hasPassed: _showPassed(PlayerPosition.west),
                    child: _VerticalBotHand(
                      cards: round.handFor(PlayerPosition.west),
                      cardWidth: cardWidth,
                      cardHeight: cardHeight,
                      cardBack: cardBack ?? CardBack.redStripes,
                      label: 'West',
                      isCurrentPlayer: round.currentPlayer == PlayerPosition.west,
                    ),
                  ),

                  // Center trick area
                  Expanded(
                    child: Center(
                      child: TrickArea(
                        round: round,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                      ),
                    ),
                  ),

                  // East hand (vertical, face down)
                  _LabeledVerticalHand(
                    label: PlayerPosition.east.displayName,
                    isCurrentPlayer: round.currentPlayer == PlayerPosition.east,
                    hasPassed: _showPassed(PlayerPosition.east),
                    child: _VerticalBotHand(
                      cards: round.handFor(PlayerPosition.east),
                      cardWidth: cardWidth,
                      cardHeight: cardHeight,
                      cardBack: cardBack ?? CardBack.redStripes,
                      label: 'East',
                      isCurrentPlayer: round.currentPlayer == PlayerPosition.east,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: spacing),

            // Discard hint
            if (showDiscardHint)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Tap a card to discard',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),

            // South hand (human, face up)
            _LabeledHand(
              label: PlayerPosition.south.displayName,
              isCurrentPlayer: round.currentPlayer == PlayerPosition.south,
              hasPassed: _showPassed(PlayerPosition.south),
              child: _HumanHand(
                cards: round.handFor(PlayerPosition.south),
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isActive: isHumanTurn,
                trumpSuit: round.trumpSuit,
                ledSuit: _effectiveLedSuit(),
                onCardTap: onCardTap != null ? (card) => onCardTap!(card) : (_) {},
              ),
            ),
            SizedBox(height: spacing * 2),
          ],
        ),
      );
    });
  }

  bool _showPassed(PlayerPosition pos) =>
      round.phase.isBidding && round.passedPlayers.contains(pos);

  CardSuit? _effectiveLedSuit() {
    final trick = round.currentTrick;
    if (trick == null || trick.plays.isEmpty || round.trumpSuit == null) {
      return null;
    }
    return CardRanking.effectiveSuit(trick.plays.first.card, round.trumpSuit!);
  }
}

class _HumanHand extends StatelessWidget {
  final List<SuitedCard> cards;
  final double cardWidth;
  final double cardHeight;
  final bool isActive;
  final CardSuit? trumpSuit;
  final CardSuit? ledSuit;
  final void Function(SuitedCard) onCardTap;

  const _HumanHand({
    required this.cards,
    required this.cardWidth,
    required this.cardHeight,
    required this.isActive,
    required this.trumpSuit,
    required this.ledSuit,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return SizedBox(height: cardHeight);

    final legalCards = isActive && trumpSuit != null
        ? EuchreRules.legalPlays(
            hand: cards,
            ledSuit: ledSuit,
            trumpSuit: trumpSuit!,
          )
        : <SuitedCard>[];

    final overlap = (cardWidth * 0.45).clamp(20.0, 55.0);
    final totalWidth = cardWidth + (cards.length - 1) * overlap;

    return SizedBox(
      height: cardHeight + 12,
      child: Center(
        child: SizedBox(
          width: totalWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < cards.length; i++)
                Positioned(
                  left: i * overlap,
                  child: _TappableCard(
                    card: cards[i],
                    width: cardWidth,
                    height: cardHeight,
                    isLegal: legalCards.contains(cards[i]),
                    isActive: isActive,
                    onTap: () => onCardTap(cards[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TappableCard extends StatelessWidget {
  final SuitedCard card;
  final double width;
  final double height;
  final bool isLegal;
  final bool isActive;
  final VoidCallback onTap;

  const _TappableCard({
    required this.card,
    required this.width,
    required this.height,
    required this.isLegal,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        transform: Matrix4.translationValues(
          0,
          isActive && isLegal ? -8 : 0,
          0,
        ),
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PlayingCardBuilder(card: card),
            if (isActive && !isLegal)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BotHand extends StatelessWidget {
  final List<SuitedCard> cards;
  final double cardWidth;
  final double cardHeight;
  final CardBack cardBack;
  final String label;
  final bool isCurrentPlayer;

  const _BotHand({
    required this.cards,
    required this.cardWidth,
    required this.cardHeight,
    required this.cardBack,
    required this.label,
    required this.isCurrentPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final smallWidth = cardWidth * 0.85;
    final smallHeight = cardHeight * 0.85;
    final overlap = smallWidth * 0.4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 10,
          child: isCurrentPlayer
              ? Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
        SizedBox(
          height: smallHeight,
          child: cards.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: smallWidth + (cards.length - 1) * overlap,
                      child: Stack(
                        children: [
                          for (int i = 0; i < cards.length; i++)
                            Positioned(
                              left: i * overlap,
                              child: SizedBox(
                                width: smallWidth,
                                height: smallHeight,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    foregroundDecoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.black, width: 1.5),
                                    ),
                                    child: cardBack.build(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}

class _VerticalBotHand extends StatelessWidget {
  final List<SuitedCard> cards;
  final double cardWidth;
  final double cardHeight;
  final CardBack cardBack;
  final String label;
  final bool isCurrentPlayer;

  const _VerticalBotHand({
    required this.cards,
    required this.cardWidth,
    required this.cardHeight,
    required this.cardBack,
    required this.label,
    required this.isCurrentPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final smallWidth = cardWidth * 0.75;
    final smallHeight = cardHeight * 0.75;
    final overlap = smallHeight * 0.35;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 10,
          child: isCurrentPlayer
              ? Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
        SizedBox(
          width: smallWidth,
          child: cards.isNotEmpty
              ? SizedBox(
                  height: smallHeight + (cards.length - 1) * overlap,
                  child: Stack(
                    children: [
                      for (int i = 0; i < cards.length; i++)
                        Positioned(
                          top: i * overlap,
                          child: SizedBox(
                            width: smallWidth,
                            height: smallHeight,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                foregroundDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.black, width: 1),
                                ),
                                child: cardBack.build(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _LabeledHand extends StatelessWidget {
  final String label;
  final bool isCurrentPlayer;
  final bool hasPassed;
  final Widget child;

  const _LabeledHand({
    required this.label,
    required this.isCurrentPlayer,
    this.hasPassed = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isCurrentPlayer ? Colors.amber : Colors.white54,
                fontSize: 11,
                fontWeight:
                    isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (hasPassed) ...[
              SizedBox(width: 6),
              _PassedChip(),
            ],
          ],
        ),
      ],
    );
  }
}

class _LabeledVerticalHand extends StatelessWidget {
  final String label;
  final bool isCurrentPlayer;
  final bool hasPassed;
  final Widget child;

  const _LabeledVerticalHand({
    required this.label,
    required this.isCurrentPlayer,
    this.hasPassed = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        child,
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCurrentPlayer ? Colors.amber : Colors.white54,
            fontSize: 11,
            fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (hasPassed) ...[
          SizedBox(height: 3),
          _PassedChip(),
        ],
      ],
    );
  }
}

class _PassedChip extends StatelessWidget {
  const _PassedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        'Passed',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
