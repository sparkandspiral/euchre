import 'package:card_game/card_game.dart';
import 'package:euchre/model/euchre_round_state.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/lesson.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/model/trick.dart';

// Shorthand helpers for building cards
SuitedCard _c(CardSuit suit, SuitedCardValue value) =>
    SuitedCard(suit: suit, value: value);

final _j = JackSuitedCardValue();
final _q = QueenSuitedCardValue();
final _k = KingSuitedCardValue();
final _a = AceSuitedCardValue();
SuitedCardValue _n(int v) => NumberSuitedCardValue(value: v);

final List<Lesson> allLessons = [
  // ── BIDDING ──────────────────────────────────────────────

  Lesson(
    id: 'bid_strong_hand',
    title: 'Strong Hand - Order Up',
    description:
        'You hold the right bower and 2 other trump. Should you order up?',
    category: LessonCategory.bidding,
    difficulty: LessonDifficulty.beginner,
    objective: LessonObjective.makeBidDecision,
    correctBidOrderUp: true,
    explanation:
        'With the right bower (Jack of trump) plus two additional trump cards, '
        'you have a very strong hand. You should order up because you are '
        'likely to win at least 3 tricks. The right bower alone is the highest '
        'card in the game, and having two more trump gives you control.',
    scenario: EuchreRoundState(
      hands: {
        // South holds: J♠ (right bower), A♠, 10♠, A♥, K♦
        PlayerPosition.south: [
          _c(CardSuit.spades, _j),
          _c(CardSuit.spades, _a),
          _c(CardSuit.spades, _n(10)),
          _c(CardSuit.hearts, _a),
          _c(CardSuit.diamonds, _k),
        ],
        PlayerPosition.west: [
          _c(CardSuit.hearts, _k),
          _c(CardSuit.hearts, _q),
          _c(CardSuit.diamonds, _n(9)),
          _c(CardSuit.clubs, _n(10)),
          _c(CardSuit.clubs, _n(9)),
        ],
        PlayerPosition.north: [
          _c(CardSuit.spades, _q),
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.diamonds, _n(10)),
          _c(CardSuit.clubs, _a),
          _c(CardSuit.hearts, _n(9)),
        ],
        PlayerPosition.east: [
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.clubs, _k),
          _c(CardSuit.clubs, _q),
          _c(CardSuit.spades, _n(9)),
        ],
      },
      kitty: [_c(CardSuit.clubs, _j), _c(CardSuit.hearts, _j),
              _c(CardSuit.diamonds, _j)],
      turnedCard: _c(CardSuit.spades, _k),
      dealer: PlayerPosition.north,
      phase: GamePhase.bidRound1,
      currentPlayer: PlayerPosition.south,
    ),
  ),

  Lesson(
    id: 'bid_marginal_pass',
    title: 'Marginal Hand - Pass',
    description:
        'You have only one low trump and no off-aces. Should you order up?',
    category: LessonCategory.bidding,
    difficulty: LessonDifficulty.beginner,
    objective: LessonObjective.makeBidDecision,
    correctBidOrderUp: false,
    explanation:
        'With only the 9 of trump and no aces in other suits, this hand is too '
        'weak to call. You would need your partner to carry most of the tricks. '
        'Ordering up with a weak hand risks getting euchred, which gives your '
        'opponents 2 points. Pass and hope your partner or the second round '
        'gives you a better opportunity.',
    scenario: EuchreRoundState(
      hands: {
        // South holds: 9♥, Q♦, 10♦, K♣, 9♣
        PlayerPosition.south: [
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.diamonds, _n(10)),
          _c(CardSuit.clubs, _k),
          _c(CardSuit.clubs, _n(9)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.hearts, _a),
          _c(CardSuit.hearts, _k),
          _c(CardSuit.spades, _a),
          _c(CardSuit.spades, _q),
          _c(CardSuit.diamonds, _n(9)),
        ],
        PlayerPosition.north: [
          _c(CardSuit.hearts, _q),
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.clubs, _a),
          _c(CardSuit.clubs, _q),
        ],
        PlayerPosition.east: [
          _c(CardSuit.hearts, _j),
          _c(CardSuit.spades, _k),
          _c(CardSuit.spades, _n(10)),
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.clubs, _n(10)),
        ],
      },
      kitty: [_c(CardSuit.spades, _j), _c(CardSuit.spades, _n(9)),
              _c(CardSuit.diamonds, _j)],
      turnedCard: _c(CardSuit.hearts, _k),
      dealer: PlayerPosition.west,
      phase: GamePhase.bidRound1,
      currentPlayer: PlayerPosition.south,
      passedPlayers: [PlayerPosition.north],
    ),
  ),

  Lesson(
    id: 'bid_dealer_pickup',
    title: 'Dealer Advantage',
    description:
        'You\'re the dealer with a borderline hand. The turned card helps. Pick it up?',
    category: LessonCategory.bidding,
    difficulty: LessonDifficulty.intermediate,
    objective: LessonObjective.makeBidDecision,
    correctBidOrderUp: true,
    explanation:
        'As dealer, you get to pick up the turned card and discard your worst. '
        'The turned Ace of hearts gives you a guaranteed trick. Combined with '
        'the left bower (Jack of diamonds) you already hold, you have 2 strong '
        'trump. With the dealer advantage of swapping a weak card, this hand '
        'becomes strong enough to call.',
    scenario: EuchreRoundState(
      hands: {
        // South (dealer): J♦ (left bower if hearts), K♥, 10♥, A♣, 9♠
        PlayerPosition.south: [
          _c(CardSuit.diamonds, _j),
          _c(CardSuit.hearts, _k),
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.clubs, _a),
          _c(CardSuit.spades, _n(9)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.spades, _a),
          _c(CardSuit.spades, _k),
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.clubs, _q),
          _c(CardSuit.clubs, _n(9)),
        ],
        PlayerPosition.north: [
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.diamonds, _n(10)),
          _c(CardSuit.clubs, _k),
          _c(CardSuit.clubs, _n(10)),
        ],
        PlayerPosition.east: [
          _c(CardSuit.hearts, _q),
          _c(CardSuit.spades, _q),
          _c(CardSuit.spades, _n(10)),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.diamonds, _n(9)),
        ],
      },
      kitty: [_c(CardSuit.hearts, _j), _c(CardSuit.spades, _j),
              _c(CardSuit.clubs, _j)],
      turnedCard: _c(CardSuit.hearts, _a),
      dealer: PlayerPosition.south,
      phase: GamePhase.bidRound1,
      currentPlayer: PlayerPosition.south,
      passedPlayers: [
        PlayerPosition.west,
        PlayerPosition.north,
        PlayerPosition.east,
      ],
    ),
  ),

  Lesson(
    id: 'bid_go_alone',
    title: 'Going Alone',
    description:
        'You have a monster hand. Is it strong enough to go alone for 4 points?',
    category: LessonCategory.bidding,
    difficulty: LessonDifficulty.advanced,
    objective: LessonObjective.makeBidDecision,
    correctBidOrderUp: true, // order up AND go alone
    explanation:
        'With right bower, left bower, ace of trump, and an off-ace, you have '
        '4 nearly guaranteed tricks. Going alone means you only need 5 tricks '
        'from a 3-player game (opponents only get 2 hands against you). This '
        'hand is a textbook loner: 3 top trump cards plus an ace that likely '
        'wins trick 4 or 5. Going alone scores 4 points instead of 2!',
    scenario: EuchreRoundState(
      hands: {
        // South: J♠ (right), J♣ (left), A♠, K♠, A♥
        PlayerPosition.south: [
          _c(CardSuit.spades, _j),
          _c(CardSuit.clubs, _j),
          _c(CardSuit.spades, _a),
          _c(CardSuit.spades, _k),
          _c(CardSuit.hearts, _a),
        ],
        PlayerPosition.west: [
          _c(CardSuit.hearts, _k),
          _c(CardSuit.hearts, _q),
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.diamonds, _n(10)),
          _c(CardSuit.clubs, _n(9)),
        ],
        PlayerPosition.north: [
          _c(CardSuit.spades, _q),
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.clubs, _a),
          _c(CardSuit.clubs, _q),
        ],
        PlayerPosition.east: [
          _c(CardSuit.spades, _n(9)),
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.diamonds, _n(9)),
          _c(CardSuit.clubs, _k),
        ],
      },
      kitty: [_c(CardSuit.clubs, _n(10)), _c(CardSuit.spades, _n(10)),
              _c(CardSuit.hearts, _j)],
      turnedCard: _c(CardSuit.spades, _n(10)),
      dealer: PlayerPosition.north,
      phase: GamePhase.bidRound1,
      currentPlayer: PlayerPosition.south,
    ),
  ),

  // ── LEADING ──────────────────────────────────────────────

  Lesson(
    id: 'lead_trump',
    title: 'Lead Trump After Calling',
    description:
        'You called trump and won the first trick. What should you lead?',
    category: LessonCategory.leading,
    difficulty: LessonDifficulty.beginner,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.hearts, _j),
    explanation:
        'After calling trump, lead your highest trump to draw out opponents\' '
        'trump cards. Leading the right bower forces opponents to either play '
        'lower trump (which you win) or waste off-suit cards. Once you clear '
        'trump, your partner\'s and your remaining cards become much stronger.',
    scenario: EuchreRoundState(
      hands: {
        // South: J♥ (right), 10♥, A♣, K♦
        PlayerPosition.south: [
          _c(CardSuit.hearts, _j),
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.clubs, _a),
          _c(CardSuit.diamonds, _k),
        ],
        PlayerPosition.west: [
          _c(CardSuit.hearts, _k),
          _c(CardSuit.spades, _a),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.clubs, _n(9)),
        ],
        PlayerPosition.north: [
          _c(CardSuit.diamonds, _j),
          _c(CardSuit.spades, _k),
          _c(CardSuit.clubs, _k),
          _c(CardSuit.diamonds, _n(10)),
        ],
        PlayerPosition.east: [
          _c(CardSuit.hearts, _q),
          _c(CardSuit.spades, _q),
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.clubs, _q),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.hearts, _a),
      dealer: PlayerPosition.north,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.hearts,
      caller: PlayerPosition.south,
      currentTrick: Trick(leader: PlayerPosition.south),
      completedTricks: [
        Trick(leader: PlayerPosition.west, plays: [
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _n(10))),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.spades, _n(9))),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.spades, _n(9))),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.hearts, _a)),
        ]),
      ],
      tricksWon: {Team.playerTeam: 1, Team.opponentTeam: 0},
    ),
  ),

  Lesson(
    id: 'lead_off_ace',
    title: 'Lead an Off-Ace',
    description:
        'Trump has been drawn. You have an off-suit ace. Time to cash it!',
    category: LessonCategory.leading,
    difficulty: LessonDifficulty.beginner,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.clubs, _a),
    explanation:
        'After trump has been drawn out in earlier tricks, off-suit aces are '
        'likely winners. Lead the Ace of clubs - since opponents have already '
        'used their trump, they probably can\'t trump in. Aces in off-suits '
        'are guaranteed tricks when opponents are out of trump.',
    scenario: EuchreRoundState(
      hands: {
        // South: A♣, K♦, 9♦
        PlayerPosition.south: [
          _c(CardSuit.clubs, _a),
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.diamonds, _n(9)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.clubs, _q),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.spades, _n(9)),
        ],
        PlayerPosition.north: [
          _c(CardSuit.clubs, _k),
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.diamonds, _n(10)),
        ],
        PlayerPosition.east: [
          _c(CardSuit.clubs, _n(10)),
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.spades, _q),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.hearts, _a),
      dealer: PlayerPosition.west,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.hearts,
      caller: PlayerPosition.west,
      currentTrick: Trick(leader: PlayerPosition.south),
      completedTricks: [
        Trick(leader: PlayerPosition.west, plays: [
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.hearts, _j)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.hearts, _q)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.hearts, _k)),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.hearts, _n(10))),
        ]),
        Trick(leader: PlayerPosition.west, plays: [
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _a)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.spades, _k)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.spades, _k)),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.clubs, _n(9))),
        ]),
      ],
      tricksWon: {Team.playerTeam: 0, Team.opponentTeam: 2},
    ),
  ),

  Lesson(
    id: 'lead_partner_strength',
    title: 'Lead Partner\'s Strength',
    description:
        'Your partner called trump. Lead a suit that helps them win tricks.',
    category: LessonCategory.leading,
    difficulty: LessonDifficulty.intermediate,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.hearts, _n(9)),
    explanation:
        'When your partner called trump (hearts), lead a low trump to help '
        'them draw out opponents\' trump. Your partner likely has strong trump '
        'since they called it. Leading trump lets them use their high cards '
        'while extracting opponents\' trump. Don\'t lead your off-suit aces '
        'yet - save those for after trump is cleared.',
    scenario: EuchreRoundState(
      hands: {
        // South: 9♥, A♠, A♦, K♣, 10♣
        PlayerPosition.south: [
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.spades, _a),
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.clubs, _k),
          _c(CardSuit.clubs, _n(10)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.hearts, _q),
          _c(CardSuit.spades, _k),
          _c(CardSuit.spades, _q),
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.clubs, _n(9)),
        ],
        PlayerPosition.north: [
          _c(CardSuit.hearts, _j),
          _c(CardSuit.hearts, _a),
          _c(CardSuit.hearts, _k),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.clubs, _q),
        ],
        PlayerPosition.east: [
          _c(CardSuit.diamonds, _j),
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.spades, _n(10)),
          _c(CardSuit.diamonds, _n(10)),
          _c(CardSuit.clubs, _a),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.hearts, _n(10)),
      dealer: PlayerPosition.east,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.hearts,
      caller: PlayerPosition.north,
      currentTrick: Trick(leader: PlayerPosition.south),
      completedTricks: [],
      tricksWon: {Team.playerTeam: 0, Team.opponentTeam: 0},
    ),
  ),

  Lesson(
    id: 'lead_endgame',
    title: 'Endgame Lead',
    description:
        'It\'s trick 5, you have the last trump. Lead it to clinch the hand.',
    category: LessonCategory.leading,
    difficulty: LessonDifficulty.advanced,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.spades, _k),
    explanation:
        'In the last trick, your King of spades (trump) is guaranteed to win '
        'since all higher trump have been played. Leading your last trump '
        'secures the 3rd trick for your team, making the hand. Always count '
        'trump - knowing you hold the highest remaining one is the key to '
        'endgame decisions.',
    scenario: EuchreRoundState(
      hands: {
        // South: K♠ (last trump)
        PlayerPosition.south: [_c(CardSuit.spades, _k)],
        PlayerPosition.west: [_c(CardSuit.diamonds, _n(9))],
        PlayerPosition.north: [_c(CardSuit.clubs, _n(10))],
        PlayerPosition.east: [_c(CardSuit.hearts, _q)],
      },
      kitty: [],
      turnedCard: _c(CardSuit.spades, _a),
      dealer: PlayerPosition.west,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.spades,
      caller: PlayerPosition.south,
      currentTrick: Trick(leader: PlayerPosition.south),
      completedTricks: [
        Trick(leader: PlayerPosition.south, plays: [
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.spades, _j)),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _q)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.diamonds, _k)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.clubs, _j)),
        ]),
        Trick(leader: PlayerPosition.south, plays: [
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.hearts, _a)),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.hearts, _k)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.hearts, _n(9))),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.hearts, _n(10))),
        ]),
        Trick(leader: PlayerPosition.west, plays: [
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.diamonds, _a)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.diamonds, _q)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.diamonds, _n(10))),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.clubs, _a)),
        ]),
        Trick(leader: PlayerPosition.west, plays: [
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.clubs, _k)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.clubs, _q)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.spades, _n(9))),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.diamonds, _n(10))),
        ]),
      ],
      tricksWon: {Team.playerTeam: 2, Team.opponentTeam: 2},
    ),
  ),

  // ── FOLLOWING ────────────────────────────────────────────

  Lesson(
    id: 'follow_trump_in',
    title: 'When to Trump In',
    description:
        'An opponent is winning the trick and partner hasn\'t played. Trump in!',
    category: LessonCategory.following,
    difficulty: LessonDifficulty.beginner,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.hearts, _n(9)),
    explanation:
        'West led the Ace of clubs and is winning. Your partner (North) hasn\'t '
        'played yet, but you can\'t rely on them having clubs or trump. Since '
        'you\'re void in clubs, you should trump in with your lowest trump (9 '
        'of hearts) to win the trick. Use your lowest trump to conserve higher '
        'trump for later tricks.',
    scenario: EuchreRoundState(
      hands: {
        // South: 9♥, K♠, Q♦, 10♦
        PlayerPosition.south: [
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.spades, _k),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.diamonds, _n(10)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.clubs, _k),
          _c(CardSuit.spades, _a),
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.spades, _q),
        ],
        PlayerPosition.north: [
          _c(CardSuit.hearts, _k),
          _c(CardSuit.clubs, _q),
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.spades, _n(10)),
        ],
        PlayerPosition.east: [
          _c(CardSuit.hearts, _q),
          _c(CardSuit.clubs, _n(10)),
          _c(CardSuit.clubs, _n(9)),
          _c(CardSuit.diamonds, _n(9)),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.hearts, _a),
      dealer: PlayerPosition.north,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.hearts,
      caller: PlayerPosition.east,
      currentTrick: Trick(leader: PlayerPosition.west, plays: [
        TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.clubs, _a)),
      ]),
      completedTricks: [
        Trick(leader: PlayerPosition.east, plays: [
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.hearts, _j)),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.hearts, _n(10))),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.hearts, _n(9))),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.hearts, _a)),
        ]),
      ],
      tricksWon: {Team.playerTeam: 1, Team.opponentTeam: 0},
    ),
  ),

  Lesson(
    id: 'follow_save_trump',
    title: 'Save Your Trump',
    description:
        'Partner is winning this trick. Don\'t waste your trump!',
    category: LessonCategory.following,
    difficulty: LessonDifficulty.beginner,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.diamonds, _n(9)),
    explanation:
        'Your partner (North) played the King of clubs and is winning this '
        'trick. Since you\'re void in clubs, you could trump in, but that would '
        'waste a valuable trump card on a trick your team is already winning. '
        'Instead, throw off your lowest card (9 of diamonds) to save your '
        'trump for when you actually need it.',
    scenario: EuchreRoundState(
      hands: {
        // South: Q♠ (trump), K♥, 9♦
        PlayerPosition.south: [
          _c(CardSuit.spades, _q),
          _c(CardSuit.hearts, _k),
          _c(CardSuit.diamonds, _n(9)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.clubs, _n(9)),
          _c(CardSuit.hearts, _q),
          _c(CardSuit.diamonds, _k),
        ],
        PlayerPosition.north: [
          _c(CardSuit.spades, _n(9)),
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.diamonds, _q),
        ],
        PlayerPosition.east: [
          _c(CardSuit.clubs, _q),
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.diamonds, _n(10)),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.spades, _a),
      dealer: PlayerPosition.south,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.spades,
      caller: PlayerPosition.south,
      currentTrick: Trick(leader: PlayerPosition.north, plays: [
        TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.clubs, _k)),
        TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.clubs, _n(10))),
      ]),
      completedTricks: [
        Trick(leader: PlayerPosition.south, plays: [
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.spades, _j)),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _n(10))),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.clubs, _a)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.spades, _k)),
        ]),
        Trick(leader: PlayerPosition.south, plays: [
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.hearts, _a)),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.hearts, _k)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.hearts, _j)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.diamonds, _a)),
        ]),
      ],
      tricksWon: {Team.playerTeam: 2, Team.opponentTeam: 0},
    ),
  ),

  Lesson(
    id: 'follow_third_seat',
    title: 'Third Seat Play',
    description:
        'You\'re third to play. Partner led but opponent played higher. Overtake?',
    category: LessonCategory.following,
    difficulty: LessonDifficulty.intermediate,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.diamonds, _a),
    explanation:
        'Your partner led the 10 of diamonds, and West played the King. As '
        'third seat, you should play your Ace to overtake and win the trick. '
        'East (4th seat) may have a higher card, but your Ace is the highest '
        'possible card in this suit. Taking this trick secures the point and '
        'gives your team the lead for the next trick.',
    scenario: EuchreRoundState(
      hands: {
        // South: A♦, Q♣, 9♣, K♥
        PlayerPosition.south: [
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.clubs, _q),
          _c(CardSuit.clubs, _n(9)),
          _c(CardSuit.hearts, _k),
        ],
        PlayerPosition.west: [
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.spades, _k),
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.clubs, _k),
        ],
        PlayerPosition.north: [
          _c(CardSuit.diamonds, _n(9)),
          _c(CardSuit.spades, _q),
          _c(CardSuit.hearts, _q),
          _c(CardSuit.clubs, _a),
        ],
        PlayerPosition.east: [
          _c(CardSuit.spades, _a),
          _c(CardSuit.spades, _n(10)),
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.clubs, _n(10)),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.spades, _n(9)),
      dealer: PlayerPosition.east,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.spades,
      caller: PlayerPosition.west,
      currentTrick: Trick(leader: PlayerPosition.north, plays: [
        TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.diamonds, _n(10))),
        TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.diamonds, _j)),
        TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.diamonds, _k)),
      ]),
      completedTricks: [
        Trick(leader: PlayerPosition.west, plays: [
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _j)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.spades, _n(9))),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.hearts, _a)),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.diamonds, _n(10))),
        ]),
      ],
      tricksWon: {Team.playerTeam: 0, Team.opponentTeam: 1},
    ),
  ),

  Lesson(
    id: 'follow_discard_strategy',
    title: 'Smart Discard',
    description:
        'You can\'t win this trick. Which card should you throw off?',
    category: LessonCategory.following,
    difficulty: LessonDifficulty.intermediate,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.clubs, _n(9)),
    explanation:
        'When you can\'t win a trick, discard strategically. Throw off the 9 '
        'of clubs to create a void in clubs. Being void in a suit means you '
        'can trump in when that suit is led later. Keep your diamond cards '
        'because you hold the Ace - you want to be able to follow suit and '
        'win when diamonds are led.',
    scenario: EuchreRoundState(
      hands: {
        // South: A♦, Q♦, 9♣, 10♥
        PlayerPosition.south: [
          _c(CardSuit.diamonds, _a),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.clubs, _n(9)),
          _c(CardSuit.hearts, _n(10)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.spades, _q),
          _c(CardSuit.hearts, _k),
          _c(CardSuit.clubs, _k),
          _c(CardSuit.diamonds, _k),
        ],
        PlayerPosition.north: [
          _c(CardSuit.spades, _k),
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.clubs, _a),
          _c(CardSuit.diamonds, _n(10)),
        ],
        PlayerPosition.east: [
          _c(CardSuit.hearts, _q),
          _c(CardSuit.clubs, _q),
          _c(CardSuit.clubs, _n(10)),
          _c(CardSuit.diamonds, _n(9)),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.spades, _a),
      dealer: PlayerPosition.north,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.spades,
      caller: PlayerPosition.north,
      currentTrick: Trick(leader: PlayerPosition.east, plays: [
        TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.spades, _a)),
        TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _n(10))),
      ]),
      completedTricks: [
        Trick(leader: PlayerPosition.north, plays: [
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.spades, _j)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.spades, _n(9))),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.hearts, _a)),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _k)),
        ]),
      ],
      tricksWon: {Team.playerTeam: 1, Team.opponentTeam: 0},
    ),
  ),

  // ── DEFENSE ──────────────────────────────────────────────

  Lesson(
    id: 'defense_lead_through',
    title: 'Lead Through the Caller',
    description:
        'The opponent to your right called trump. Lead through them!',
    category: LessonCategory.defense,
    difficulty: LessonDifficulty.intermediate,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.clubs, _n(10)),
    explanation:
        'When defending, "lead through" the caller (East called trump). By '
        'leading clubs, you force East to play before your partner. If East '
        'has to follow suit, your partner in North gets to play last with '
        'full information. Leading through strength (the caller\'s position) '
        'is a fundamental defensive technique that maximizes your team\'s '
        'information advantage.',
    scenario: EuchreRoundState(
      hands: {
        // South: 10♣, K♦, Q♦, 9♥
        PlayerPosition.south: [
          _c(CardSuit.clubs, _n(10)),
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.diamonds, _q),
          _c(CardSuit.hearts, _n(9)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.clubs, _k),
          _c(CardSuit.clubs, _n(9)),
          _c(CardSuit.hearts, _a),
          _c(CardSuit.diamonds, _n(10)),
        ],
        PlayerPosition.north: [
          _c(CardSuit.clubs, _a),
          _c(CardSuit.clubs, _q),
          _c(CardSuit.hearts, _k),
          _c(CardSuit.diamonds, _n(9)),
        ],
        PlayerPosition.east: [
          _c(CardSuit.spades, _j),
          _c(CardSuit.spades, _q),
          _c(CardSuit.hearts, _q),
          _c(CardSuit.diamonds, _a),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.spades, _a),
      dealer: PlayerPosition.west,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.spades,
      caller: PlayerPosition.east,
      currentTrick: Trick(leader: PlayerPosition.south),
      completedTricks: [
        Trick(leader: PlayerPosition.east, plays: [
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.clubs, _j)),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.spades, _n(9))),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _k)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.spades, _n(10))),
        ]),
      ],
      tricksWon: {Team.playerTeam: 0, Team.opponentTeam: 1},
    ),
  ),

  Lesson(
    id: 'defense_short_suit',
    title: 'Short-Suiting for Defense',
    description:
        'Create a void so you can trump the caller\'s tricks later.',
    category: LessonCategory.defense,
    difficulty: LessonDifficulty.advanced,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.diamonds, _n(9)),
    explanation:
        'You need to follow suit with diamonds, so play your 9 of diamonds. '
        'This gets rid of your last diamond, creating a void. Next time '
        'diamonds are led, you\'ll be able to trump in. Short-suiting is a '
        'key defensive technique - deliberately emptying a suit to create '
        'future trumping opportunities against the caller.',
    scenario: EuchreRoundState(
      hands: {
        // South: Q♣ (trump), K♥, A♥, 9♦
        PlayerPosition.south: [
          _c(CardSuit.clubs, _q),
          _c(CardSuit.hearts, _k),
          _c(CardSuit.hearts, _a),
          _c(CardSuit.diamonds, _n(9)),
        ],
        PlayerPosition.west: [
          _c(CardSuit.clubs, _n(10)),
          _c(CardSuit.hearts, _q),
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.diamonds, _q),
        ],
        PlayerPosition.north: [
          _c(CardSuit.clubs, _n(9)),
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.spades, _a),
          _c(CardSuit.spades, _k),
        ],
        PlayerPosition.east: [
          _c(CardSuit.clubs, _k),
          _c(CardSuit.clubs, _a),
          _c(CardSuit.hearts, _n(9)),
          _c(CardSuit.diamonds, _n(10)),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.clubs, _j),
      dealer: PlayerPosition.east,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.clubs,
      caller: PlayerPosition.east,
      currentTrick: Trick(leader: PlayerPosition.west, plays: [
        TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.diamonds, _a)),
      ]),
      completedTricks: [
        Trick(leader: PlayerPosition.east, plays: [
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.clubs, _j)),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.spades, _q)),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _n(10))),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.spades, _n(9))),
        ]),
      ],
      tricksWon: {Team.playerTeam: 0, Team.opponentTeam: 1},
    ),
  ),

  Lesson(
    id: 'defense_euchre_opportunity',
    title: 'Euchre Opportunity',
    description:
        'The caller is struggling. Push for the euchre!',
    category: LessonCategory.defense,
    difficulty: LessonDifficulty.advanced,
    objective: LessonObjective.playCorrectCard,
    correctCard: _c(CardSuit.hearts, _a),
    explanation:
        'West called trump but your team has won 2 of 3 tricks so far. You '
        'need just 1 more to euchre them (worth 2 points!). Lead your Ace of '
        'hearts - it\'s the highest card in hearts and should win this trick '
        'outright unless someone trumps in. Securing the euchre is worth the '
        'risk since it scores 2 points for your team instead of the 1 point '
        'the caller would have gotten.',
    scenario: EuchreRoundState(
      hands: {
        // South: A♥, Q♦
        PlayerPosition.south: [
          _c(CardSuit.hearts, _a),
          _c(CardSuit.diamonds, _q),
        ],
        PlayerPosition.west: [
          _c(CardSuit.hearts, _n(10)),
          _c(CardSuit.diamonds, _a),
        ],
        PlayerPosition.north: [
          _c(CardSuit.hearts, _k),
          _c(CardSuit.clubs, _n(10)),
        ],
        PlayerPosition.east: [
          _c(CardSuit.diamonds, _k),
          _c(CardSuit.clubs, _n(9)),
        ],
      },
      kitty: [],
      turnedCard: _c(CardSuit.spades, _a),
      dealer: PlayerPosition.north,
      phase: GamePhase.playing,
      currentPlayer: PlayerPosition.south,
      trumpSuit: CardSuit.spades,
      caller: PlayerPosition.west,
      currentTrick: Trick(leader: PlayerPosition.south),
      completedTricks: [
        Trick(leader: PlayerPosition.west, plays: [
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.spades, _j)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.spades, _n(9))),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.spades, _n(10))),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.clubs, _a)),
        ]),
        Trick(leader: PlayerPosition.west, plays: [
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.clubs, _k)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.clubs, _q)),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.clubs, _j)),
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.spades, _k)),
        ]),
        Trick(leader: PlayerPosition.south, plays: [
          TrickPlay(player: PlayerPosition.south, card: _c(CardSuit.spades, _q)),
          TrickPlay(player: PlayerPosition.west, card: _c(CardSuit.hearts, _q)),
          TrickPlay(player: PlayerPosition.north, card: _c(CardSuit.diamonds, _n(10))),
          TrickPlay(player: PlayerPosition.east, card: _c(CardSuit.diamonds, _n(9))),
        ]),
      ],
      tricksWon: {Team.playerTeam: 2, Team.opponentTeam: 1},
    ),
  ),
];
