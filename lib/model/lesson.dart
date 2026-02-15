import 'package:card_game/card_game.dart';
import 'package:euchre/model/euchre_round_state.dart';

enum LessonCategory {
  bidding,
  leading,
  following,
  defense;

  String get displayName => switch (this) {
        LessonCategory.bidding => 'Bidding',
        LessonCategory.leading => 'Leading',
        LessonCategory.following => 'Following',
        LessonCategory.defense => 'Defense',
      };

  String get icon => switch (this) {
        LessonCategory.bidding => '\u2660',
        LessonCategory.leading => '\u2665',
        LessonCategory.following => '\u2666',
        LessonCategory.defense => '\u2663',
      };
}

enum LessonDifficulty {
  beginner,
  intermediate,
  advanced;

  String get displayName => switch (this) {
        LessonDifficulty.beginner => 'Beginner',
        LessonDifficulty.intermediate => 'Intermediate',
        LessonDifficulty.advanced => 'Advanced',
      };
}

enum LessonObjective {
  playCorrectCard,
  makeBidDecision,
  discardCorrectCard,
}

class Lesson {
  final String id;
  final String title;
  final String description;
  final LessonCategory category;
  final LessonDifficulty difficulty;
  final EuchreRoundState scenario;
  final LessonObjective objective;
  final String explanation;
  final SuitedCard? correctCard;
  final bool? correctBidOrderUp;
  final CardSuit? correctBidSuit;

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.scenario,
    required this.objective,
    required this.explanation,
    this.correctCard,
    this.correctBidOrderUp,
    this.correctBidSuit,
  });
}
