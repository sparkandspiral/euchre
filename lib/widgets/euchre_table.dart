import 'package:card_game/card_game.dart';
import 'package:flutter/material.dart';
import 'package:euchre/logic/card_ranking.dart';
import 'package:euchre/logic/euchre_rules.dart';
import 'package:euchre/model/card_back.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/services/game_engine.dart';
import 'package:euchre/styles/playing_card_builder.dart';
import 'package:euchre/widgets/trick_area.dart';

class EuchreTable extends StatelessWidget {
  final EuchreRoundState round;
  final GameEngine engine;
  final CardBack? cardBack;

  const EuchreTable({
    super.key,
    required this.round,
    required this.engine,
    this.cardBack,
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

            // South hand (human, face up)
            _LabeledHand(
              label: PlayerPosition.south.displayName,
              isCurrentPlayer: round.currentPlayer == PlayerPosition.south,
              child: _HumanHand(
                cards: round.handFor(PlayerPosition.south),
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isActive: isHumanTurn,
                trumpSuit: round.trumpSuit,
                ledSuit: _effectiveLedSuit(),
                onCardTap: (card) {
                  if (round.phase == GamePhase.dealerDiscard) {
                    engine.humanDiscard(card);
                  } else if (round.phase == GamePhase.playing) {
                    engine.humanPlayCard(card);
                  }
                },
              ),
            ),
            SizedBox(height: spacing * 2),
          ],
        ),
      );
    });
  }

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
    if (cards.isEmpty) return SizedBox(height: cardHeight * 0.5);

    final smallWidth = cardWidth * 0.85;
    final smallHeight = cardHeight * 0.85;
    final overlap = smallWidth * 0.4;
    final totalWidth = smallWidth + (cards.length - 1) * overlap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCurrentPlayer)
          Container(
            width: 6,
            height: 6,
            margin: EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
        SizedBox(
          height: smallHeight,
          width: totalWidth,
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
                          border: Border.all(color: Colors.black, width: 1.5),
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
    if (cards.isEmpty) return SizedBox(width: cardWidth * 0.5);

    final smallWidth = cardWidth * 0.75;
    final smallHeight = cardHeight * 0.75;
    final overlap = smallHeight * 0.35;
    final totalHeight = smallHeight + (cards.length - 1) * overlap;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCurrentPlayer)
          Container(
            width: 6,
            height: 6,
            margin: EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
        SizedBox(
          width: smallWidth,
          height: totalHeight,
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
                          border: Border.all(color: Colors.black, width: 1),
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
    );
  }
}

class _LabeledHand extends StatelessWidget {
  final String label;
  final bool isCurrentPlayer;
  final Widget child;

  const _LabeledHand({
    required this.label,
    required this.isCurrentPlayer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isCurrentPlayer ? Colors.amber : Colors.white54,
            fontSize: 11,
            fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _LabeledVerticalHand extends StatelessWidget {
  final String label;
  final bool isCurrentPlayer;
  final Widget child;

  const _LabeledVerticalHand({
    required this.label,
    required this.isCurrentPlayer,
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
      ],
    );
  }
}
