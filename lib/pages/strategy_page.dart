import 'package:flutter/material.dart';

class StrategyPage extends StatelessWidget {
  const StrategyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A2340),
      appBar: AppBar(
        backgroundColor: Color(0xFF0A2340),
        foregroundColor: Colors.white,
        title: Text('Strategy Guide'),
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Master these concepts to dominate your next tournament.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          _StrategySection(
            icon: Icons.assessment,
            title: 'Hand Evaluation',
            content: _handEvaluation,
          ),
          _StrategySection(
            icon: Icons.gavel,
            title: 'Bidding Strategy',
            content: _biddingStrategy,
          ),
          _StrategySection(
            icon: Icons.person,
            title: 'Going Alone',
            content: _goingAlone,
          ),
          _StrategySection(
            icon: Icons.play_arrow,
            title: 'Leading Strategy',
            content: _leadingStrategy,
          ),
          _StrategySection(
            icon: Icons.swap_horiz,
            title: 'Following & Trumping',
            content: _followingAndTrumping,
          ),
          _StrategySection(
            icon: Icons.shield,
            title: 'Defensive Play',
            content: _defensivePlay,
          ),
          _StrategySection(
            icon: Icons.handshake,
            title: 'Partner Communication',
            content: _partnerCommunication,
          ),
          _StrategySection(
            icon: Icons.psychology,
            title: 'Card Counting',
            content: _cardCounting,
          ),
          _StrategySection(
            icon: Icons.emoji_events,
            title: 'Tournament Tips',
            content: _tournamentTips,
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StrategySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_Tip> content;

  const _StrategySection({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.amber, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white38,
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final tip in content) _TipWidget(tip: tip),
        ],
      ),
    );
  }
}

class _Tip {
  final String heading;
  final String body;
  const _Tip(this.heading, this.body);
}

class _TipWidget extends StatelessWidget {
  final _Tip tip;
  const _TipWidget({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tip.heading,
            style: TextStyle(
              color: Colors.amber.shade200,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            tip.body,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Content ───────────────────────────────────────────────

const _handEvaluation = [
  _Tip(
    'Count Your Trump',
    'The foundation of hand evaluation is counting trump cards. '
    'Three or more trump cards (including bowers) is generally a strong hand. '
    'The right bower (jack of trump) and left bower (jack of same color) are the '
    'two highest cards in the game and anchor any hand.',
  ),
  _Tip(
    'Value Off-Suit Aces',
    'An ace in a non-trump suit is essentially a guaranteed trick when that suit is led. '
    'Hands with 2+ trump and 1-2 off-aces are excellent bidding hands. '
    'Kings are only valuable when accompanied by their ace or when you expect to trump in.',
  ),
  _Tip(
    'Suit Voids Are Powerful',
    'Being void (having no cards) in one or two off-suits is very valuable when you hold trump. '
    'A void lets you trump in when that suit is led, turning otherwise weak trump cards into winners. '
    'Two trump + a void is often stronger than three trump with no void.',
  ),
  _Tip(
    'Position Matters',
    'Your hand is stronger when you are to the left of the dealer (first to bid) because you '
    'get to lead first. The same hand is weaker in dealer position because opponents have already '
    'passed and you are last to play in the first trick.',
  ),
];

const _biddingStrategy = [
  _Tip(
    'Round 1: Ordering Up',
    'Order up the turned card when you have 2+ trump (including what the dealer picks up), '
    'especially if you also hold an off-suit ace. Remember: ordering up gives the dealer an '
    'extra trump card. If the dealer is your partner, be more aggressive. '
    'If the dealer is an opponent, you need a stronger hand.',
  ),
  _Tip(
    'Round 1: Passing',
    'Pass with fewer than 2 trump even if you have off-aces. '
    'Also pass when the turned card would strengthen an opponent\'s hand more than yours. '
    'When your partner is dealer, passing means they get to pick up that card - consider if it helps them.',
  ),
  _Tip(
    'Round 2: Picking Trump',
    'In round 2, pick a suit where you hold 3+ cards or 2 cards with the right bower. '
    'The suit you pick should be different from the turned-down suit. '
    'Favor suits where you also have the left bower (the other jack of the same color).',
  ),
  _Tip(
    'Stick the Dealer',
    'When you\'re the dealer and all players have passed through both rounds, you must pick. '
    'Choose your longest suit, even with weak cards. Having 3 cards of any suit gives you a '
    'decent chance. Look at what was turned down - players passed on that suit, so they likely '
    'don\'t have strong cards there.',
  ),
  _Tip(
    'Reading the Table',
    'Pay attention to who passes and who hesitates. If the player before you passes quickly, '
    'they likely have nothing in the turned suit. If an opponent orders up, they have a strong hand. '
    'Track patterns across rounds - some players only bid with very strong hands.',
  ),
];

const _goingAlone = [
  _Tip(
    'When to Go Alone',
    'Go alone when you have a near-certain 5-trick hand: both bowers + the ace of trump, '
    'or both bowers + 2 other trump. You need to be confident of taking all 5 tricks since '
    'you play without your partner. The reward is 4 points instead of 2 for a march.',
  ),
  _Tip(
    'Risk vs Reward',
    'Going alone for 4 points is only worth it if you are very confident. '
    'Getting euchred while going alone costs you 2 points to the opponents. '
    'Even taking only 3-4 tricks scores just 1 point (same as a normal call). '
    'The math: go alone only when you estimate 80%+ chance of all 5 tricks.',
  ),
  _Tip(
    'First Seat Advantage',
    'Going alone is strongest from first seat (left of dealer) because you lead first '
    'and can pull trump immediately. From later positions, opponents may have already played '
    'trump or set up their off-suit winners before you can act.',
  ),
  _Tip(
    'Score Awareness',
    'At 6-0 or similar large leads, avoid going alone - you\'re already winning and the '
    'risk isn\'t worth it. At 6-8 down, going alone is justified because you need the '
    'extra points to catch up. At 9 points (one away from winning), never go alone unless '
    'your hand is perfect - just calling and making 1 point wins the game.',
  ),
];

const _leadingStrategy = [
  _Tip(
    'Leading Trump',
    'If you called trump, lead it immediately. This pulls opponents\' trump out of their '
    'hands, protecting your off-suit aces for later. Lead with the right bower first if you '
    'have it - this guarantees the trick and strips a trump from each opponent.',
  ),
  _Tip(
    'Leading Off-Suit Aces',
    'If you didn\'t call trump but hold off-suit aces, lead them early before they get trumped. '
    'Aces are guaranteed winners only when led. If you wait, an opponent may become void in that '
    'suit and trump your ace.',
  ),
  _Tip(
    'Leading Through Strength',
    'When an opponent called trump, lead through them (from their right side). '
    'This forces the caller to play before your partner, giving your partner the advantage '
    'of seeing what was played. Lead a suit you think the caller is short in.',
  ),
  _Tip(
    'Avoid Leading Singletons',
    'Leading a lone king or queen in a non-trump suit is risky. If the ace is out, you lose '
    'the trick and gain nothing. Instead, save singletons for trumping opportunities when '
    'that suit is led later. Lead from suits where you hold 2+ cards.',
  ),
  _Tip(
    'The Short-Suit Lead',
    'If you hold trump and are void in a suit, consider leading your remaining off-suit cards '
    'to create additional voids. Being void in two suits while holding trump gives you maximum '
    'flexibility to trump in.',
  ),
];

const _followingAndTrumping = [
  _Tip(
    'Second Seat Play',
    'In second seat (playing right after the leader), play low if your partner hasn\'t played yet. '
    'Let your partner take the trick if possible. Only play high in second seat if you can win '
    'the trick outright with an ace or bower.',
  ),
  _Tip(
    'Third Seat Play',
    'In third seat (your partner led), play the minimum card needed to win. If your partner\'s '
    'card is already winning, throw off a low card from a non-trump suit. '
    'Don\'t waste trump if your partner is already taking the trick.',
  ),
  _Tip(
    'When to Trump In',
    'Trump in when: (1) your partner didn\'t call and their card is losing, (2) the opponents '
    'are winning the trick and the trick is important, or (3) you\'re trying to pull out '
    'opponents\' trump by forcing them to overtrump. Don\'t waste trump on tricks your partner can win.',
  ),
  _Tip(
    'Throwing Off (Discarding)',
    'When you can\'t follow suit and don\'t want to trump, discard your lowest card from your '
    'weakest off-suit. This preserves your stronger cards for later. '
    'Specifically, throw off suits where you have no winners (no aces or trump).',
  ),
  _Tip(
    'Fourth Seat Advantage',
    'Playing last in a trick is powerful. You see all three other cards before deciding. '
    'Play the minimum card needed to win, or if the trick is already won by your partner, '
    'throw off garbage. Never overplay from fourth seat.',
  ),
];

const _defensivePlay = [
  _Tip(
    'Defending Against the Caller',
    'When opponents call trump, your goal is to take 3 tricks and euchre them for 2 points. '
    'Lead through the caller (from their right) to force difficult decisions. '
    'Save your trump for when the caller leads their off-aces.',
  ),
  _Tip(
    'Don\'t Waste High Trump on Defense',
    'If an opponent leads trump, don\'t waste your highest trump early unless you must. '
    'Play your lowest trump to follow suit. Save high trump for when you can capture the '
    'caller\'s off-suit winners or for the last tricks when they\'re out of trump.',
  ),
  _Tip(
    'Short-Suiting for Defense',
    'If you\'re short in a non-trump suit, that\'s a defensive asset. When that suit is led, '
    'you can trump in and steal tricks the caller expected to win. '
    'Keep track of which suits you and your partner are short in.',
  ),
  _Tip(
    'Blocking the March',
    'Preventing all 5 tricks is critical. Even if you can\'t euchre, holding the caller to '
    '3-4 tricks (1 point) is much better than giving up a march (2 points). '
    'Fight hard for the 3rd trick - it\'s the difference between 1 and 2 points.',
  ),
];

const _partnerCommunication = [
  _Tip(
    'Lead Your Partner\'s Called Suit',
    'If your partner ordered up or picked a suit, lead trump to them. '
    'They called because they have a strong trump hand. Leading trump helps them '
    'pull opponents\' trump and establish dominance.',
  ),
  _Tip(
    'Signal with Off-Suit',
    'When discarding, throw your lowest card from your weakest suit. '
    'Experienced partners recognize this signal. If you throw low hearts, '
    'your partner knows not to lead hearts to you.',
  ),
  _Tip(
    'Support Your Partner\'s Lead',
    'When your partner leads a suit, they usually have a reason. Play high to help them '
    'win the trick, or if you can\'t win, throw off a card that signals your strength. '
    'Never trump your partner\'s ace.',
  ),
  _Tip(
    'Trust Your Partner',
    'If your partner called trump, trust their hand. Don\'t trump in on tricks they\'re winning. '
    'Don\'t lead suits that put them in difficult positions. Your job on defense is to feed them '
    'tricks; on offense, to support their plan.',
  ),
];

const _cardCounting = [
  _Tip(
    'Track the Bowers',
    'Always know where the right and left bowers are. If neither has been played, someone '
    'holds them. If one opponent played the right bower, the left bower is the current '
    'highest card. This dictates your entire strategy for the remaining tricks.',
  ),
  _Tip(
    'Count Trump Remaining',
    'Euchre uses only 24 cards, with 6 trump cards (right bower, left bower, A, K, Q, 10 of trump). '
    'Track how many trump have been played. After 4 trump are gone, '
    'off-suit aces become very strong since opponents likely can\'t trump them.',
  ),
  _Tip(
    'Remember the Kitty',
    'Four cards go to the kitty undealt. This means some aces and trump may not be in play. '
    'If you\'ve seen 5 of the 6 trump cards, the 6th might be in the kitty. '
    'Don\'t assume all aces are in someone\'s hand - one could be buried.',
  ),
  _Tip(
    'Watch What\'s Discarded',
    'Track what opponents throw off when they can\'t follow suit. If East discards a club, '
    'they\'re likely out of clubs for the rest of the hand. This tells you which suits are safe '
    'to lead and which might get trumped.',
  ),
  _Tip(
    'Simple Counting Method',
    'Focus on counting just trump and aces - don\'t try to memorize every card. '
    'After each trick, update your mental count: "3 trump played, ace of hearts still out." '
    'This 80/20 approach gives you most of the benefit without overwhelming your memory.',
  ),
];

const _tournamentTips = [
  _Tip(
    'Play Consistently',
    'Tournament euchre rewards consistent play over flashy moves. Make the percentage play '
    'every time. Over many hands, sound fundamentals beat risky gambles. '
    'Avoid tilt after bad luck - the next hand is independent.',
  ),
  _Tip(
    'Score Awareness',
    'Always know the score. At 9-9, play ultra-conservatively on defense (don\'t give up a march) '
    'and bid aggressively because 1 trick-win ends the game. '
    'At 8-9 down, you must call with any reasonable hand since passing lets them win cheaply.',
  ),
  _Tip(
    'Euchre Math',
    'A euchre (2 points) is worth twice a normal win (1 point). '
    'This means strong defensive play is extremely valuable. '
    'Don\'t feel pressured to call with marginal hands - a patient pass that leads to '
    'euchring the opponent is worth more than a risky 1-point call.',
  ),
  _Tip(
    'First to 10',
    'When you\'re at 8 or 9, any successful call wins. Be aggressive about ordering up or '
    'picking suit. Even a marginal 3-trick hand wins the game. '
    'Conversely, when opponents are at 8-9, be more cautious about calling since getting '
    'euchred could cost you the game.',
  ),
  _Tip(
    'Adapt to Opponents',
    'In a tournament you play many different teams. Notice tendencies: do they always pass with '
    'weak hands? Do they bid aggressively? Do they always lead trump as caller? '
    'Adjust your defense based on the patterns you observe.',
  ),
  _Tip(
    'Speed of Play',
    'In timed tournament rounds, play with purpose. Don\'t rush decisions, but don\'t agonize '
    'either. Having a systematic approach (evaluate hand, count trump, decide) lets you play '
    'quickly and correctly. Practice this rhythm in your app games.',
  ),
];
